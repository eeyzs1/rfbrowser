// Memory system end-to-end — a *single* test that walks through a
// realistic user session from start to finish, in the same order
// the user would experience the features. Each step is annotated
// with what the user is doing and what we expect to see.
//
// This is the companion to memory_user_journey_test.dart (which
// has small per-phase tests). This file puts everything together
// in one flow so a single failure surfaces the whole journey.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rfbrowser/core/memory/summary_rollup.dart';
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/active_memory_buffer.dart';
import 'package:rfbrowser/services/hebbian_service.dart';
import 'package:rfbrowser/services/memory_service.dart';
import 'package:rfbrowser/services/search_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import '../helpers/sqflite_test_setup.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupSqfliteForTests();

  test(
    'full user session: chat → memory → recall → dreaming → backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('rfb_session_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });
      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'session',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      final memory = container.read(memoryServiceProvider);
      final hebbian = container.read(hebbianServiceProvider);
      final active = container.read(activeMemoryBufferProvider);
      final search = container.read(searchServiceProvider.notifier);
      final rollup = SummaryRollup(memory);

      // ── Step 1: User opens the app, the vault is initialized.
      expect(await memory.database, isNotNull);

      // ── Step 2: User chats with the AI in session "alpha". The AI
      //            eventually produces 3 memory fragments.
      const sessionA = 'alpha';
      final fragmentsA = [
        MemoryFragment(
          id: 'a1',
          sessionId: sessionA,
          content: 'User is a senior Rust engineer working on async runtimes.',
          importanceScore: 0.85,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MemoryFragment(
          id: 'a2',
          sessionId: sessionA,
          content: 'User cares about memory safety and zero-cost abstractions.',
          importanceScore: 0.80,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MemoryFragment(
          id: 'a3',
          sessionId: sessionA,
          content: 'User dislikes unnecessary GC pauses.',
          importanceScore: 0.70,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      for (final f in fragmentsA) {
        await memory.upsertFragment(f);
      }

      // ── Step 3: User pins fragment a1 as "active working memory".
      await active.add(sessionA, 'a1');
      expect(active.activeIds(sessionA), ['a1']);

      // ── Step 4: User asks a follow-up question. The AI recall
      //            pipeline kicks in: FTS + Hebbian + active.
      final recalled = await memory.searchFragments('rust async', limit: 5);
      expect(recalled.map((f) => f.id), contains('a1'));
      // Hebbian co-access strengthens edges between a1/a2/a3.
      await hebbian.recordCoAccess(['a1', 'a2', 'a3']);
      final neighbors = await hebbian.expandByHebbianLinks(['a1'], limit: 5);
      expect(
        neighbors.map((n) => n.fragment.id).toSet(),
        containsAll(['a2', 'a3']),
      );
      // on-retrieval reinforcement.
      await hebbian.recordSearchAccess(['a1']);
      expect(hebbian.searchAccessEdges, greaterThan(0));

      // ── Step 5: User opens session "beta" in a new tab. The new
      //            session does not see the old fragments in the
      //            buffer, but the database-level cross-session
      //            association should still find them.
      const sessionB = 'beta';
      expect(active.activeIds(sessionB), isEmpty);
      await memory.upsertFragment(
        MemoryFragment(
          id: 'b1',
          sessionId: sessionB,
          content:
              'User is learning async runtime internals for their next Rust '
              'project. They care about safety.',
          importanceScore: 0.75,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final xref = await memory.findCrossSessionAssociates('b1');
      final xrefIds = xref.map((r) => r.fragment.id).toSet();
      expect(
        xrefIds,
        contains('a1'),
        reason: 'cross-session association should find the rust note',
      );

      // ── Step 6: User pins b1 in session B.
      await active.add(sessionB, 'b1');
      expect(active.activeIds(sessionB), ['b1']);

      // ── Step 7: User types "rust" into the vault search bar. The
      //            search must return memory fragments as "kind=memory"
      //            entries.
      final searchResults = await search.hybridSearch('rust');
      final memoryHits = searchResults
          .where((r) => r['kind'] == 'memory')
          .toList();
      expect(
        memoryHits,
        isNotEmpty,
        reason: 'hybrid search should recall the rust memory fragments',
      );
      final fragmentIds = memoryHits
          .map((r) => r['memoryId'])
          .whereType<String>()
          .toSet();
      expect(fragmentIds.intersection({'a1', 'a2', 'a3', 'b1'}), isNotEmpty);

      // ── Step 8: User clicks the "why 0.87" chip on a memory
      //            result to see the score breakdown.
      final matches = await memory.searchFragmentsWithScores(
        'rust async',
        limit: 5,
      );
      expect(matches, isNotEmpty);
      final top = matches.first;
      expect(top.fragment.id, 'a1');
      expect(top.compositeScore, greaterThan(0));
      expect(top.matchedTokens, greaterThan(0));
      expect(top.importanceScore, closeTo(0.85, 0.01));

      // ── Step 9: User explicitly "remembers" a fragment via the
      //            Remember button (upsert with source='manual').
      final manual = MemoryFragment(
        id: 'manual1',
        sessionId: sessionA,
        content: 'User has a soft ban on channels in production code.',
        importanceScore: 0.95,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        source: 'manual',
      );
      await memory.upsertFragment(manual);
      final found = await memory.getFragment('manual1');
      expect(found, isNotNull);
      expect(found!.source, 'manual');

      // ── Step 10: User changes a setting — the memory context
      //             budget drops from 800 to 400 tokens.
      final notifier = container.read(settingsProvider.notifier);
      await notifier.setMemoryContextBudget(400);
      expect(container.read(settingsProvider).memory.contextBudget, 400);

      // ── Step 11: User runs dreaming manually (simulated by directly
      //             invoking the L2 rollup on pre-seeded L1 summaries).
      final db = await memory.database;
      final longAgo = DateTime.now()
          .subtract(const Duration(days: 10))
          .toIso8601String();
      for (var i = 0; i < 3; i++) {
        await db.insert('memory_summaries', {
          'summary_id': 'manual_l1_$i',
          'user_id': '',
          'summary_tier': 'l1',
          'source_tier': 'short',
          'start_timestamp': longAgo,
          'end_timestamp': longAgo,
          'message_count': 1,
          'source_record_ids': '',
          'key_points': '',
          'keywords': 'rust|async|tokio',
          'summary_text': 's$i',
          'quality_score': 0.7,
          'created_at': longAgo,
          'updated_at': longAgo,
          'parent_summary_id': null,
        });
      }
      final r = await rollup.runDaily();
      expect(r.l2Created, greaterThanOrEqualTo(1));

      // ── Step 12: User backs up to JSON.
      final exported = await memory.exportToJson();
      expect(exported['schema_version'], 4);
      final counts = exported['counts'] as Map;
      expect(counts['fragments'], greaterThan(3));

      // ── Step 13: User restores the same JSON in a new vault.
      //             We simulate this by importing the round-trip
      //             into the same DB.
      final result = await memory.importFromJson(exported);
      expect(result.fragments, greaterThanOrEqualTo(counts['fragments']));

      // ── Step 14: User clears the active memory buffer.
      await active.clear(sessionA);
      expect(active.activeIds(sessionA), isEmpty);

      // ── Step 15: Verify all user actions left the DB in a sane
      //             state: every previously created fragment is
      //             still active and findable.
      final allActive = await memory.getAllActiveFragments();
      final activeIds = allActive.map((f) => f.id).toSet();
      for (final id in ['a1', 'a2', 'a3', 'b1', 'manual1']) {
        expect(
          activeIds,
          contains(id),
          reason: 'fragment $id should still be active after backup',
        );
      }

      await memory.close();
    },
  );
}

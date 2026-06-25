import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/core/memory/summary_rollup.dart';
import 'package:rfbrowser/services/active_memory_buffer.dart';
import 'package:rfbrowser/services/memory_service.dart';
import '../helpers/sqflite_test_setup.dart';

MemoryFragment _frag({
  required String id,
  required String sessionId,
  String content = 'sample fact',
  MemoryTier tier = MemoryTier.short,
  double importance = 0.5,
  String? createdAt,
}) {
  final now = createdAt != null ? DateTime.parse(createdAt) : DateTime.now();
  return MemoryFragment(
    id: id,
    sessionId: sessionId,
    content: content,
    tier: tier,
    importanceScore: importance,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(setupSqfliteForTests);

  group('MemoryService tokenizeForCrossSession', () {
    test('returns lowercase, stopword-filtered, length-sorted tokens', () {
      final tokens = MemoryService.tokenizeForCrossSession(
        'Rust is a fast language that has good tooling',
        limit: 4,
      );
      // 'rust' / 'language' / 'tooling' / 'fast' / 'good' all 4+ chars
      // and not in stopword list. Sorted longest first, top 4 returned.
      expect(tokens.length, 4);
      expect(tokens.first.length, greaterThanOrEqualTo(tokens.last.length));
      expect(tokens.every((t) => t.toLowerCase() == t), isTrue);
    });
    test('drops stopwords and short tokens', () {
      final tokens = MemoryService.tokenizeForCrossSession(
        'a I an is the rust be',
      );
      expect(tokens, contains('rust'));
      expect(tokens, isNot(contains('a')));
      expect(tokens, isNot(contains('is')));
      expect(tokens, isNot(contains('the')));
    });
  });

  group('MemoryService findCrossSessionAssociates', () {
    late MemoryService memory;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_cross_').path,
          'memory.db',
        ),
      );
    });
    tearDown(() async => memory.close());

    test('finds fragments from other sessions with shared keywords', () async {
      await memory.upsertFragment(
        _frag(
          id: 'a1',
          sessionId: 's1',
          content: 'rust borrow checker semantics',
        ),
      );
      await memory.upsertFragment(
        _frag(
          id: 'a2',
          sessionId: 's2',
          content: 'rust borrow checker explained',
        ),
      );
      await memory.upsertFragment(
        _frag(id: 'a3', sessionId: 's2', content: 'python list comprehensions'),
      );
      final out = await memory.findCrossSessionAssociates('a1', limit: 5);
      expect(out.map((r) => r.fragment.id), contains('a2'));
      expect(out.map((r) => r.fragment.id), isNot(contains('a3')));
    });
    test('excludes same-session fragments', () async {
      await memory.upsertFragment(
        _frag(id: 'b1', sessionId: 's1', content: 'rust borrow checker'),
      );
      await memory.upsertFragment(
        _frag(id: 'b2', sessionId: 's1', content: 'rust borrow checker'),
      );
      final out = await memory.findCrossSessionAssociates('b1', limit: 5);
      expect(out.map((r) => r.fragment.id), isNot(contains('b2')));
    });
  });

  group('SummaryRollup', () {
    late MemoryService memory;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_rollup_').path,
          'memory.db',
        ),
      );
    });
    tearDown(() async => memory.close());

    test('returns zero on an empty DB', () async {
      final rollup = SummaryRollup(memory);
      final r = await rollup.runDaily();
      expect(r.l2Created, 0);
      expect(r.l3Created, 0);
    });
    test('produces no rollup when child L1 summaries are too recent', () async {
      final rollup = SummaryRollup(memory);
      final db = await memory.database;
      // Insert two L1 summaries that ended today (not past 7d).
      await db.insert('memory_summaries', {
        'summary_id': 's_l1_a',
        'user_id': '',
        'summary_tier': 'l1',
        'source_tier': 'short',
        'start_timestamp': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'end_timestamp': DateTime.now().toIso8601String(),
        'message_count': 1,
        'source_record_ids': '',
        'key_points': '',
        'keywords': 'rust|borrow|checker',
        'summary_text': 'x',
        'quality_score': 0.7,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'parent_summary_id': null,
      });
      await db.insert('memory_summaries', {
        'summary_id': 's_l1_b',
        'user_id': '',
        'summary_tier': 'l1',
        'source_tier': 'short',
        'start_timestamp': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'end_timestamp': DateTime.now().toIso8601String(),
        'message_count': 1,
        'source_record_ids': '',
        'key_points': '',
        'keywords': 'rust|borrow|checker',
        'summary_text': 'y',
        'quality_score': 0.7,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'parent_summary_id': null,
      });
      final r = await rollup.runDaily();
      expect(r.l2Created, 0);
    });
    test('clusters L1 summaries past the window and creates L2', () async {
      final rollup = SummaryRollup(memory);
      final db = await memory.database;
      // Two L1 summaries that ended >7d ago and share >=2 keywords.
      final longAgo = DateTime.now()
          .subtract(const Duration(days: 10))
          .toIso8601String();
      for (var i = 0; i < 2; i++) {
        await db.insert('memory_summaries', {
          'summary_id': 's_old_$i',
          'user_id': '',
          'summary_tier': 'l1',
          'source_tier': 'short',
          'start_timestamp': longAgo,
          'end_timestamp': longAgo,
          'message_count': 1,
          'source_record_ids': '',
          'key_points': '',
          'keywords': 'rust|borrow|checker',
          'summary_text': 'old $i',
          'quality_score': 0.7,
          'created_at': longAgo,
          'updated_at': longAgo,
          'parent_summary_id': null,
        });
      }
      final r = await rollup.runDaily();
      expect(r.l2Created, greaterThanOrEqualTo(1));
      // Children should have a parent_summary_id now.
      final children = await db.query(
        'memory_summaries',
        where: 'summary_tier = ? AND summary_id LIKE ?',
        whereArgs: ['l1', 's_old_%'],
      );
      for (final row in children) {
        expect(
          row['parent_summary_id'],
          isNotNull,
          reason: 'children of an L2 rollup should have parent set',
        );
      }
    });
  });

  group('ActiveMemoryBuffer', () {
    late MemoryService memory;
    late ActiveMemoryBuffer buffer;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_amb_').path,
          'memory.db',
        ),
      );
      buffer = ActiveMemoryBuffer(memory);
    });
    tearDown(() async => memory.close());

    test('add returns resolved fragments, promotes to MRU', () async {
      await memory.upsertFragment(
        _frag(id: 'x1', sessionId: 's', content: 'first'),
      );
      await memory.upsertFragment(
        _frag(id: 'x2', sessionId: 's', content: 'second'),
      );
      await buffer.add('s', 'x1');
      final r2 = await buffer.add('s', 'x2');
      expect(buffer.activeIds('s'), ['x2', 'x1']);
      expect(r2.map((f) => f.id), ['x2', 'x1']);
    });
    test('evicts LRU when capacity is exceeded', () async {
      for (var i = 0; i < 10; i++) {
        await memory.upsertFragment(
          _frag(id: 'ev$i', sessionId: 's', content: 'ev $i'),
        );
      }
      for (var i = 0; i < 10; i++) {
        await buffer.add('s', 'ev$i', capacity: 5);
      }
      expect(buffer.activeIds('s').length, 5);
      // Most recent should be ev9
      expect(buffer.activeIds('s').first, 'ev9');
    });
    test('clear() drops the buffer', () async {
      await memory.upsertFragment(
        _frag(id: 'c1', sessionId: 's', content: 'c'),
      );
      await buffer.add('s', 'c1');
      expect(buffer.activeIds('s'), ['c1']);
      await buffer.clear('s');
      expect(buffer.activeIds('s'), isEmpty);
    });
  });

  group('MemoryService exportToJson / importFromJson', () {
    late MemoryService memory;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_json_').path,
          'memory.db',
        ),
      );
    });
    tearDown(() async => memory.close());

    test('round-trips fragments', () async {
      await memory.upsertFragment(
        _frag(id: 'j1', sessionId: 's', content: 'json test 1'),
      );
      await memory.upsertFragment(
        _frag(id: 'j2', sessionId: 's', content: 'json test 2'),
      );
      final exported = await memory.exportToJson();
      expect(exported['schema_version'], 4);
      final counts = exported['counts'] as Map;
      expect(counts['fragments'], 2);
      // Round-trip
      final result = await memory.importFromJson(exported);
      expect(result.fragments, greaterThanOrEqualTo(2));
    });
    test('refuses schema_version < 2', () async {
      expect(
        () => memory.importFromJson({'schema_version': 1, 'fragments': []}),
        throwsA(isA<FormatException>()),
      );
    });
    test('replaceExisting wipes + reinserts', () async {
      await memory.upsertFragment(
        _frag(id: 'r1', sessionId: 's', content: 'before'),
      );
      final exported = await memory.exportToJson();
      // Insert another row, then replace from exported (which doesn't
      // contain the new row).
      await memory.upsertFragment(
        _frag(id: 'r2', sessionId: 's', content: 'after'),
      );
      final result = await memory.importFromJson(
        exported,
        replaceExisting: true,
      );
      // Only the r1 row was in the export, so only r1 should be re-inserted.
      expect(result.fragments, 1);
      final all = await memory.getAllActiveFragments();
      expect(all.any((f) => f.id == 'r1'), isTrue);
      expect(all.any((f) => f.id == 'r2'), isFalse);
    });
  });

  group('MemoryService.searchFragmentsWithScores', () {
    late MemoryService memory;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_score_').path,
          'memory.db',
        ),
      );
    });
    tearDown(() async => memory.close());

    test('returns per-hit score breakdown', () async {
      await memory.upsertFragment(
        _frag(
          id: 'a',
          sessionId: 's',
          content: 'rust borrow checker rules',
          importance: 0.9,
        ),
      );
      await memory.upsertFragment(
        _frag(
          id: 'b',
          sessionId: 's',
          content: 'python decorators',
          importance: 0.2,
        ),
      );
      final out = await memory.searchFragmentsWithScores('rust borrow');
      expect(out, isNotEmpty);
      // The first hit should be the rust fragment.
      expect(out.first.fragment.id, 'a');
      expect(out.first.matchedTokens, greaterThan(0));
      expect(out.first.compositeScore, greaterThan(0));
    });
    test('empty query returns no matches', () async {
      final out = await memory.searchFragmentsWithScores('');
      expect(out, isEmpty);
    });
  });
}

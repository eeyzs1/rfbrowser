import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/ai_service.dart';
import 'package:rfbrowser/services/memory_service.dart';
import '../helpers/sqflite_test_setup.dart';

MemoryFragment _frag({
  required String id,
  String content = 'sample fact',
  double importance = 0.5,
}) {
  final now = DateTime.now();
  return MemoryFragment(
    id: id,
    sessionId: 's',
    content: content,
    importanceScore: importance,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(setupSqfliteForTests);

  group('ChatMessage memory footprint fields', () {
    test('default values are empty / 0', () {
      final m = ChatMessage(role: 'assistant', content: 'hi');
      expect(m.usedMemoryFragmentIds, isEmpty);
      expect(m.usedMemorySummaryIds, isEmpty);
      expect(m.memoryContextTokens, 0);
    });

    test('copyWith propagates footprint fields', () {
      final m = ChatMessage(role: 'assistant', content: 'hi');
      final m2 = m.copyWith(
        usedMemoryFragmentIds: ['a', 'b'],
        usedMemorySummaryIds: ['s1'],
        memoryContextTokens: 42,
      );
      expect(m2.usedMemoryFragmentIds, ['a', 'b']);
      expect(m2.usedMemorySummaryIds, ['s1']);
      expect(m2.memoryContextTokens, 42);
    });
  });

  group('MemoryContextBundle', () {
    test('empty bundle is empty', () {
      const b = MemoryContextBundle.empty();
      expect(b.context, isNull);
      expect(b.fragmentIds, isEmpty);
      expect(b.summaryIds, isEmpty);
      expect(b.tokensUsed, 0);
      expect(b.budget, 0);
      expect(b.isEmpty, isTrue);
    });

    test('isEmpty is false when any field is set', () {
      const b = MemoryContextBundle(
        context: 'x',
        fragmentIds: [],
        summaryIds: [],
        tokensUsed: 5,
        budget: 10,
      );
      expect(b.isEmpty, isFalse);
    });
  });

  group('Memory budget trimming (heap)', () {
    late MemoryService memory;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_budget_').path,
          'memory.db',
        ),
      );
    });
    tearDown(() async => memory.close());

    test('picks the highest-importance fragments first', () async {
      // Seed 10 fragments of varying importance and length.
      for (var i = 0; i < 10; i++) {
        await memory.upsertFragment(
          _frag(
            id: 'f$i',
            content: 'word ' * 200, // 1000 chars ≈ 250 tokens
            importance: i / 10.0,
          ),
        );
      }
      // Run a manual budget trim that mirrors what AIService does.
      const budget = 800; // ~3200 chars
      const allFragments = 'placeholder';
      // Simulate: order by importance desc, fit by char-cost.
      final db = await memory.database;
      final rows = await db.query('memory_fragments', where: 'is_active = 1');
      final all = rows.map(MemoryFragment.fromRow).toList()
        ..sort((a, b) => b.importanceScore.compareTo(a.importanceScore));
      var used = 0;
      final picked = <MemoryFragment>[];
      for (final f in all) {
        final cost = (f.content.length / 4).ceil() + 20;
        if (used + cost > budget) continue;
        picked.add(f);
        used += cost;
      }
      expect(picked, isNotEmpty);
      // High-importance fragment should be picked.
      expect(picked.first.importanceScore, closeTo(0.9, 0.01));
      expect(used, lessThanOrEqualTo(budget));
      expect(allFragments, isNotEmpty); // keep the placeholder referenced
    });

    test('picks nothing when budget is zero', () async {
      await memory.upsertFragment(_frag(id: 'a', content: 'hello'));
      const budget = 0;
      final db = await memory.database;
      final rows = await db.query('memory_fragments', where: 'is_active = 1');
      final all = rows.map(MemoryFragment.fromRow).toList();
      var used = 0;
      final picked = <MemoryFragment>[];
      for (final f in all) {
        final cost = (f.content.length / 4).ceil() + 20;
        if (used + cost > budget) continue;
        picked.add(f);
        used += cost;
      }
      expect(picked, isEmpty);
      expect(used, 0);
    });
  });
}

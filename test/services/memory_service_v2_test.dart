import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/memory_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

MemoryFragment _frag({
  required String id,
  String content = 'hello',
  MemoryTier tier = MemoryTier.short,
  double importance = 0.0,
  bool isPinned = false,
  List<String> mediaRefs = const [],
  DateTime? createdAt,
}) {
  final ts = createdAt ?? DateTime.now();
  return MemoryFragment(
    id: id,
    sessionId: 's',
    content: content,
    tier: tier,
    importanceScore: importance,
    isPinned: isPinned,
    mediaRefs: mediaRefs,
    createdAt: ts,
    updatedAt: ts,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MemoryService v2', () {
    late MemoryService memory;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_mem_v2_');
      memory = MemoryService(p.join(tempDir.path, 'memory.db'));
    });

    tearDown(() async {
      await memory.close();
      tempDir.deleteSync(recursive: true);
    });

    test('schema v2 is created on a fresh database', () async {
      await memory.database;
      // Save a message to make sure schema is initialized.
      await memory.saveMessage(role: 'user', content: 'hi');
      final db = await memory.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((r) => r['name'] as String).toList();
      expect(names, contains('memory_fragments'));
      expect(names, contains('memory_summaries'));
      expect(names, contains('memory_hebbian_links'));
    });

    test('tier transitions persist to the row', () async {
      final frag = _frag(id: 'a', content: 'x');
      await memory.upsertFragment(frag);
      await memory.transitionFragmentTier(
        'a',
        newTier: MemoryTier.mid,
        transitionedAt: DateTime.now(),
        summaryId: 's1',
      );
      final fetched = await memory.getFragment('a');
      expect(fetched, isNotNull);
      expect(fetched!.tier, MemoryTier.mid);
      expect(fetched.parentSummaryId, 's1');
    });

    test('archive writes archived_at and preserves tier', () async {
      final frag = _frag(id: 'a');
      await memory.upsertFragment(frag);
      await memory.transitionFragmentTier(
        'a',
        newTier: MemoryTier.long,
        transitionedAt: DateTime.now(),
        archive: true,
      );
      final fetched = await memory.getFragment('a');
      expect(fetched!.tier, MemoryTier.long);
      expect(fetched.archivedAt, isNotNull);
    });

    test('searchFragments returns active hits only', () async {
      await memory.upsertFragment(_frag(id: '1', content: 'apple pie recipe'));
      await memory.upsertFragment(_frag(id: '2', content: 'banana bread'));
      await memory.deactivateFragment('2');

      final results = await memory.searchFragments('apple', limit: 5);
      expect(results.map((f) => f.id), contains('1'));
      expect(results.map((f) => f.id), isNot(contains('2')));
    });

    test('searchFragments respects tier filter', () async {
      await memory.upsertFragment(
        _frag(id: '1', content: 'apple', tier: MemoryTier.short),
      );
      await memory.upsertFragment(
        _frag(id: '2', content: 'apple again', tier: MemoryTier.mid),
      );
      final shortOnly = await memory.searchFragments(
        'apple',
        limit: 10,
        tiers: [MemoryTier.short],
      );
      expect(shortOnly.map((f) => f.id), contains('1'));
      expect(shortOnly.map((f) => f.id), isNot(contains('2')));
    });

    test('markAccessedBatch increments access_count', () async {
      await memory.upsertFragment(_frag(id: '1'));
      await memory.upsertFragment(_frag(id: '2'));
      await memory.markAccessedBatch(['1', '2', '1']);
      final f1 = await memory.getFragment('1');
      final f2 = await memory.getFragment('2');
      expect(f1!.accessCount, 2);
      expect(f2!.accessCount, 1);
    });

    test('setPinned toggles is_pinned', () async {
      await memory.upsertFragment(_frag(id: '1'));
      await memory.setPinned('1', true);
      expect((await memory.getFragment('1'))!.isPinned, isTrue);
      await memory.setPinned('1', false);
      expect((await memory.getFragment('1'))!.isPinned, isFalse);
    });

    test('getFragmentsInTier filters and orders by created_at', () async {
      await memory.upsertFragment(
        _frag(
          id: '1',
          tier: MemoryTier.short,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await memory.upsertFragment(
        _frag(
          id: '2',
          tier: MemoryTier.short,
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      );
      await memory.upsertFragment(
        _frag(
          id: '3',
          tier: MemoryTier.mid,
          createdAt: DateTime.utc(2026, 1, 3),
        ),
      );
      final shorts = await memory.getFragmentsInTier(MemoryTier.short);
      expect(shorts.map((f) => f.id).toList(), ['1', '2']);
    });

    test('summary CRUD round-trips', () async {
      final s = MemorySummary(
        summaryId: 's1',
        userId: 'u',
        summaryTier: MemorySummaryTier.l1,
        sourceTier: MemoryTier.short,
        startTimestamp: DateTime.utc(2026, 1, 1),
        endTimestamp: DateTime.utc(2026, 1, 2),
        messageCount: 3,
        sourceRecordIds: const ['a', 'b', 'c'],
        keyPoints: const ['k1', 'k2'],
        keywords: const ['kw1'],
        summaryText: 'short -> mid',
        qualityScore: 0.7,
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await memory.saveSummary(s);
      final results = await memory.searchSummaries('mid', limit: 5);
      expect(results, hasLength(1));
      expect(results.first.summaryId, 's1');
      expect(results.first.keyPoints, ['k1', 'k2']);
    });

    test('Hebbian edges: create, strengthen, query, decay', () async {
      await memory.upsertHebbianEdge(
        'a',
        'b',
        strengthDelta: 0.1,
        stability: 1.0,
        now: DateTime.now(),
      );
      await memory.upsertHebbianEdge(
        'a',
        'b',
        strengthDelta: 0.05,
        stability: 1.0,
        now: DateTime.now(),
      );
      final edges = await memory.getHebbianEdgesFor('a');
      expect(edges, hasLength(1));
      expect(edges.first.coAccessCount, 2);
      expect(edges.first.strength, greaterThan(0.1));
      expect(edges.first.otherEnd('a'), 'b');
    });

    test('consolidation lock is single-flight', () async {
      final a = await memory.tryAcquireConsolidationLock();
      final b = await memory.tryAcquireConsolidationLock();
      expect(a, isNotNull);
      expect(b, isNull, reason: 'second acquisition should be denied');
      memory.releaseConsolidationLock(a!);
      final c = await memory.tryAcquireConsolidationLock();
      expect(c, isNotNull);
      memory.releaseConsolidationLock(c!);
    });

    test('MemoryFragment round-trips through the database', () async {
      final original = MemoryFragment(
        id: 'frag-1',
        sessionId: 's',
        content: 'important fact',
        category: 'fact',
        isActive: true,
        tier: MemoryTier.mid,
        importanceScore: 0.8,
        accessCount: 7,
        isPinned: true,
        mediaRefs: const ['img1', 'img2'],
        summaryTier: MemorySummaryTier.l1,
        parentSummaryId: 's1',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await memory.upsertFragment(original);
      final loaded = await memory.getFragment('frag-1');
      expect(loaded, isNotNull);
      expect(loaded!.tier, MemoryTier.mid);
      expect(loaded.importanceScore, closeTo(0.8, 1e-9));
      expect(loaded.accessCount, 7);
      expect(loaded.isPinned, isTrue);
      expect(loaded.mediaRefs, ['img1', 'img2']);
      expect(loaded.summaryTier, MemorySummaryTier.l1);
      expect(loaded.parentSummaryId, 's1');
    });
  });
}

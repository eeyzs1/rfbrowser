import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/memory_service.dart';
import 'package:rfbrowser/services/memory_stats_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

MemoryFragment _fragment({
  String id = 'f1',
  MemoryTier tier = MemoryTier.short,
  bool isPinned = false,
  bool isActive = true,
  double importance = 0.0,
  int accessCount = 0,
  DateTime? lastAccessAt,
  DateTime? archivedAt,
  String content = 'sample',
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime.now();
  return MemoryFragment(
    id: id,
    sessionId: 's',
    content: content,
    tier: tier,
    importanceScore: importance,
    accessCount: accessCount,
    isPinned: isPinned,
    lastAccessAt: lastAccessAt,
    archivedAt: archivedAt,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MemoryStatsService', () {
    late MemoryService memory;
    late MemoryStatsService statsService;

    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_stats_').path,
          'memory.db',
        ),
      );
      statsService = MemoryStatsService(memory);
    });

    tearDown(() async {
      await memory.close();
    });

    test('empty database returns zeroed stats', () async {
      final stats = await statsService.compute();
      expect(stats.totalFragments, 0);
      expect(stats.activeFragments, 0);
      expect(stats.pinnedFragments, 0);
      expect(stats.totalSummaries, 0);
      expect(stats.totalHebbianEdges, 0);
      expect(stats.totalChatMessages, 0);
      expect(stats.isEmpty, isTrue);
      expect(stats.memoryHealthLabel, isNull);
    });

    test('computes fragment counts by tier', () async {
      await memory.upsertFragment(_fragment(id: '1', tier: MemoryTier.short));
      await memory.upsertFragment(_fragment(id: '2', tier: MemoryTier.short));
      await memory.upsertFragment(_fragment(id: '3', tier: MemoryTier.mid));
      await memory.upsertFragment(_fragment(id: '4', tier: MemoryTier.long));
      final stats = await statsService.compute();
      expect(stats.totalFragments, 4);
      expect(stats.activeFragments, 4);
      expect(stats.fragmentsByTier[MemoryTier.short], 2);
      expect(stats.fragmentsByTier[MemoryTier.mid], 1);
      expect(stats.fragmentsByTier[MemoryTier.long], 1);
    });

    test('counts pinned fragments and archived fragments', () async {
      await memory.upsertFragment(_fragment(id: '1', isPinned: true));
      await memory.upsertFragment(_fragment(id: '2', isPinned: true));
      await memory.upsertFragment(
        _fragment(id: '3', archivedAt: DateTime.now()),
      );
      final stats = await statsService.compute();
      expect(stats.pinnedFragments, 2);
      expect(stats.archivedFragments, 1);
    });

    test('memoryHealthLabel reflects distribution', () async {
      await memory.upsertFragment(_fragment(id: '1', tier: MemoryTier.short));
      await memory.upsertFragment(_fragment(id: '2', tier: MemoryTier.long));
      final stats = await statsService.compute();
      // Two tiers, short is the heavier one
      expect(stats.memoryHealthLabel, 'fresh');
    });

    test('counts chat messages', () async {
      await memory.saveMessage(role: 'user', content: 'hi');
      await memory.saveMessage(role: 'assistant', content: 'hello');
      final stats = await statsService.compute();
      expect(stats.totalChatMessages, 2);
      expect(stats.lastChatMessage, isNotNull);
    });

    test('counts Hebbian edges', () async {
      await memory.upsertHebbianEdge(
        'a',
        'b',
        strengthDelta: 0.1,
        stability: 1.0,
        now: DateTime.now(),
      );
      await memory.upsertHebbianEdge(
        'a',
        'c',
        strengthDelta: 0.1,
        stability: 1.0,
        now: DateTime.now(),
      );
      final stats = await statsService.compute();
      expect(stats.totalHebbianEdges, 2);
    });
  });

  group('Hebbian edge cleanup', () {
    late MemoryService memory;

    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_cleanup_').path,
          'memory.db',
        ),
      );
    });

    tearDown(() async {
      await memory.close();
    });

    test('removes single-access edges older than the threshold', () async {
      final ancient = DateTime.now().subtract(const Duration(days: 200));
      await memory.upsertHebbianEdge(
        'a',
        'b',
        strengthDelta: 0.1,
        stability: 1.0,
        // Use a recent lastStrengthenedAt but pass a custom now to make
        // the cutoff trigger — actually the test uses the row's
        // last_strengthened_at which is set inside the upsert; we have
        // to seed the row directly.
        now: DateTime.now(),
      );
      // The above is recent. Re-write the column to be ancient.
      final db = await memory.database;
      await db.rawUpdate(
        'UPDATE memory_hebbian_links SET last_strengthened_at = ?',
        [ancient.toIso8601String()],
      );
      // Add a second edge between the same endpoints with reinforced count.
      await db.rawInsert(
        'INSERT INTO memory_hebbian_links (id, fragment_a, fragment_b, '
        'strength, stability, co_access_count, last_strengthened_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['edge2', 'x', 'y', 0.5, 1.0, 5, ancient.toIso8601String()],
      );
      final deleted = await memory.deleteStaleHebbianEdges(
        olderThan: const Duration(days: 90),
      );
      expect(
        deleted,
        1,
        reason: 'only the co_access_count=1 row should be removed',
      );
      final remaining = await memory.getHebbianEdgesFor('x');
      expect(remaining.length, 1);
      expect(remaining.first.id, 'edge2');
    });

    test('keeps recently strengthened edges', () async {
      await memory.upsertHebbianEdge(
        'a',
        'b',
        strengthDelta: 0.1,
        stability: 1.0,
        now: DateTime.now(),
      );
      final deleted = await memory.deleteStaleHebbianEdges(
        olderThan: const Duration(days: 90),
      );
      expect(deleted, 0);
    });
  });

  group('deleteFragment', () {
    late MemoryService memory;

    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_delete_').path,
          'memory.db',
        ),
      );
    });

    tearDown(() async {
      await memory.close();
    });

    test('removes the fragment and all its Hebbian edges', () async {
      await memory.upsertFragment(_fragment(id: 'a', content: 'apple'));
      await memory.upsertFragment(_fragment(id: 'b', content: 'banana'));
      await memory.upsertHebbianEdge(
        'a',
        'b',
        strengthDelta: 0.1,
        stability: 1.0,
        now: DateTime.now(),
      );
      // Sanity
      expect(await memory.getFragment('a'), isNotNull);
      expect((await memory.getHebbianEdgesFor('a')).length, 1);

      final deleted = await memory.deleteFragment('a');
      expect(deleted, 1);
      expect(await memory.getFragment('a'), isNull);
      expect((await memory.getHebbianEdgesFor('a')).length, 0);
      // The other fragment is untouched.
      expect(await memory.getFragment('b'), isNotNull);
    });

    test('removes the FTS index entry too', () async {
      await memory.upsertFragment(_fragment(id: 'x', content: 'apple pie'));
      // Before delete, FTS finds it.
      final before = await memory.searchFragments('apple');
      expect(before.map((f) => f.id), contains('x'));
      await memory.deleteFragment('x');
      final after = await memory.searchFragments('apple');
      expect(after.map((f) => f.id), isNot(contains('x')));
    });
  });
}

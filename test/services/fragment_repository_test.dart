// Coverage map (acceptance criteria):
// AC-FR-01: upsertFragment inserts a new fragment retrievable by getFragment.
// AC-FR-02: upsertFragment replaces an existing fragment on id conflict.
// AC-FR-03: deleteFragment removes the fragment, its FTS row, and any
//           Hebbian edges incident on it.
// AC-FR-04: deactivateFragment marks a fragment inactive with superseded_by.
// AC-FR-05: forgetFragment soft-deletes (is_active=0, source='forgotten').
// AC-FR-06: getFragmentsInTier filters by tier (the "type" analog) and
//           orders oldest-first; inactive rows are excluded.
// AC-FR-07: searchFragments respects the tier filter and excludes inactive.
// AC-FR-08: getAllActiveFragments returns only active rows.
// AC-FR-09: markAccessedBatch increments access_count for many ids in one
//           transaction; markAccessed updates a single fragment.
// AC-FR-10: addFragmentFromMessage is idempotent on duplicate message id and
//           produces a searchable, manual-source fragment.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/memory/fragment_repository.dart';
import 'package:rfbrowser/services/memory/memory_database.dart';
import '../helpers/sqflite_test_setup.dart';

MemoryFragment _frag({
  required String id,
  String content = 'sample',
  MemoryTier tier = MemoryTier.short,
  String category = 'fact',
  double importance = 0.0,
  int accessCount = 0,
  bool isPinned = false,
  String source = 'auto',
  String? sourceMessageId,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime.now();
  return MemoryFragment(
    id: id,
    sessionId: 's',
    content: content,
    category: category,
    tier: tier,
    importanceScore: importance,
    accessCount: accessCount,
    isPinned: isPinned,
    source: source,
    sourceMessageId: sourceMessageId,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(setupSqfliteForTests);

  group('FragmentRepository — CRUD (AC-FR-01..05)', () {
    late Directory tempDir;
    late MemoryDatabase memDb;
    late FragmentRepository repo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_frag_crud_');
      memDb = MemoryDatabase(p.join(tempDir.path, 'memory.db'));
      repo = FragmentRepository(memDb);
    });

    tearDown(() async {
      await memDb.close();
      tempDir.deleteSync(recursive: true);
    });

    test('upsertFragment then getFragment round-trips', () async {
      final frag = _frag(
        id: 'f1',
        content: 'a memorable fact',
        importance: 0.5,
        isPinned: true,
      );
      await repo.upsertFragment(frag);
      final loaded = await repo.getFragment('f1');
      expect(loaded, isNotNull);
      expect(loaded!.content, 'a memorable fact');
      expect(loaded.importanceScore, 0.5);
      expect(loaded.isPinned, isTrue);
      expect(loaded.tier, MemoryTier.short);
    });

    test('upsertFragment replaces an existing fragment on id conflict',
        () async {
      await repo.upsertFragment(_frag(id: 'f1', content: 'old content'));
      await repo.upsertFragment(_frag(id: 'f1', content: 'new content'));
      final loaded = await repo.getFragment('f1');
      expect(loaded!.content, 'new content');
    });

    test('getFragment returns null for an unknown id', () async {
      expect(await repo.getFragment('does-not-exist'), isNull);
    });

    test('deleteFragment removes the fragment and reports 1', () async {
      await repo.upsertFragment(_frag(id: 'f1', content: 'gone soon'));
      final deleted = await repo.deleteFragment('f1');
      expect(deleted, 1);
      expect(await repo.getFragment('f1'), isNull);
    });

    test('deleteFragment returns 0 for an unknown id', () async {
      final deleted = await repo.deleteFragment('nope');
      expect(deleted, 0);
    });

    test('deleteFragment also removes the FTS row so search no longer hits',
        () async {
      await repo.upsertFragment(_frag(id: 'f1', content: 'searchable text'));
      // Sanity: searchable before deletion.
      expect(
        (await repo.searchFragments('searchable')).map((h) => h.id),
        contains('f1'),
      );
      await repo.deleteFragment('f1');
      final hits = await repo.searchFragments('searchable');
      expect(hits.map((h) => h.id), isNot(contains('f1')));
    });

    test('deleteFragment removes Hebbian edges incident on the fragment',
        () async {
      await repo.upsertFragment(_frag(id: 'a', content: 'alpha'));
      await repo.upsertFragment(_frag(id: 'b', content: 'beta'));
      final db = await memDb.database;
      await db.insert('memory_hebbian_links', {
        'id': 'e1',
        'fragment_a': 'a',
        'fragment_b': 'b',
        'strength': 0.1,
        'stability': 1.0,
        'co_access_count': 1,
        'last_strengthened_at': DateTime.now().toIso8601String(),
      });
      await repo.deleteFragment('a');
      final edges = await db.query('memory_hebbian_links');
      expect(
        edges,
        isEmpty,
        reason: 'edges incident on the deleted fragment must be removed',
      );
    });

    test('deactivateFragment marks inactive and records superseded_by',
        () async {
      await repo.upsertFragment(_frag(id: 'f1', content: 'old'));
      await repo.deactivateFragment('f1', supersededBy: 'f2');
      final loaded = await repo.getFragment('f1');
      expect(loaded!.isActive, isFalse);
      expect(loaded.supersededBy, 'f2');
    });

    test('forgetFragment soft-deletes with source = forgotten', () async {
      await repo.upsertFragment(_frag(id: 'f1', content: 'forget me'));
      await repo.forgetFragment('f1');
      final loaded = await repo.getFragment('f1');
      expect(loaded, isNotNull);
      expect(loaded!.isActive, isFalse);
      expect(loaded.source, 'forgotten');
    });
  });

  group('FragmentRepository — tier & active filtering (AC-FR-06..08)', () {
    late Directory tempDir;
    late MemoryDatabase memDb;
    late FragmentRepository repo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_frag_filter_');
      memDb = MemoryDatabase(p.join(tempDir.path, 'memory.db'));
      repo = FragmentRepository(memDb);
    });

    tearDown(() async {
      await memDb.close();
      tempDir.deleteSync(recursive: true);
    });

    test(
      'getFragmentsInTier returns only the requested tier, oldest first',
      () async {
        await repo.upsertFragment(_frag(
          id: 's1',
          tier: MemoryTier.short,
          createdAt: DateTime.utc(2026, 1, 1),
        ));
        await repo.upsertFragment(_frag(
          id: 's2',
          tier: MemoryTier.short,
          createdAt: DateTime.utc(2026, 1, 2),
        ));
        await repo.upsertFragment(_frag(
          id: 'm1',
          tier: MemoryTier.mid,
          createdAt: DateTime.utc(2026, 1, 3),
        ));
        final shorts = await repo.getFragmentsInTier(MemoryTier.short);
        expect(shorts.map((f) => f.id).toList(), ['s1', 's2']);
        final mids = await repo.getFragmentsInTier(MemoryTier.mid);
        expect(mids.map((f) => f.id).toList(), ['m1']);
      },
    );

    test('getFragmentsInTier excludes inactive fragments', () async {
      await repo.upsertFragment(_frag(id: 's1', tier: MemoryTier.short));
      await repo.upsertFragment(_frag(id: 's2', tier: MemoryTier.short));
      await repo.deactivateFragment('s2');
      final shorts = await repo.getFragmentsInTier(MemoryTier.short);
      expect(shorts.map((f) => f.id).toList(), ['s1']);
    });

    test('getAllActiveFragments returns only active rows', () async {
      await repo.upsertFragment(_frag(id: 'a1', content: 'active'));
      await repo.upsertFragment(_frag(id: 'a2', content: 'also active'));
      await repo.upsertFragment(_frag(id: 'd1', content: 'deactivated'));
      await repo.deactivateFragment('d1');
      final active = await repo.getAllActiveFragments();
      final ids = active.map((f) => f.id).toSet();
      expect(ids, {'a1', 'a2'});
    });

    test('searchFragments respects the tier filter', () async {
      await repo.upsertFragment(
        _frag(id: 's1', content: 'apple short', tier: MemoryTier.short),
      );
      await repo.upsertFragment(
        _frag(id: 'm1', content: 'apple mid', tier: MemoryTier.mid),
      );
      final shortOnly = await repo.searchFragments(
        'apple',
        tiers: [MemoryTier.short],
      );
      expect(shortOnly.map((f) => f.id), contains('s1'));
      expect(shortOnly.map((f) => f.id), isNot(contains('m1')));
    });

    test('searchFragments excludes inactive fragments', () async {
      await repo.upsertFragment(_frag(id: 'a1', content: 'unique apple pie'));
      await repo.upsertFragment(_frag(id: 'a2', content: 'unique apple cake'));
      await repo.deactivateFragment('a2');
      final hits = await repo.searchFragments('apple');
      expect(hits.map((f) => f.id), contains('a1'));
      expect(hits.map((f) => f.id), isNot(contains('a2')));
    });

    test('searchFragments returns empty for an empty query', () async {
      await repo.upsertFragment(_frag(id: 'a1', content: 'something'));
      expect(await repo.searchFragments(''), isEmpty);
    });
  });

  group('FragmentRepository — batch operations (AC-FR-09, AC-FR-10)', () {
    late Directory tempDir;
    late MemoryDatabase memDb;
    late FragmentRepository repo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_frag_batch_');
      memDb = MemoryDatabase(p.join(tempDir.path, 'memory.db'));
      repo = FragmentRepository(memDb);
    });

    tearDown(() async {
      await memDb.close();
      tempDir.deleteSync(recursive: true);
    });

    test('markAccessedBatch increments access_count for multiple ids',
        () async {
      await repo.upsertFragment(_frag(id: 'a'));
      await repo.upsertFragment(_frag(id: 'b'));
      await repo.upsertFragment(_frag(id: 'c'));
      await repo.markAccessedBatch(['a', 'b', 'a']);
      expect((await repo.getFragment('a'))!.accessCount, 2);
      expect((await repo.getFragment('b'))!.accessCount, 1);
      expect((await repo.getFragment('c'))!.accessCount, 0);
    });

    test('markAccessedBatch is a no-op for an empty input', () async {
      await repo.upsertFragment(_frag(id: 'a'));
      await repo.markAccessedBatch(const []);
      expect((await repo.getFragment('a'))!.accessCount, 0);
    });

    test('markAccessed updates access_count and last_access_at on one fragment',
        () async {
      await repo.upsertFragment(_frag(id: 'a'));
      await repo.markAccessed('a');
      final loaded = await repo.getFragment('a');
      expect(loaded!.accessCount, 1);
      expect(loaded.lastAccessAt, isNotNull);
    });

    test('addFragmentFromMessage is idempotent on duplicate message id',
        () async {
      final id1 = await repo.addFragmentFromMessage(
        sessionId: 's',
        messageId: 'm1',
        content: 'first',
      );
      final id2 = await repo.addFragmentFromMessage(
        sessionId: 's',
        messageId: 'm1',
        content: 'second',
      );
      expect(id1, id2);
      final frag = await repo.getFragment(id1);
      expect(
        frag!.content,
        'first',
        reason: 'second call must not overwrite content',
      );
    });

    test(
      'addFragmentFromMessage inserts a searchable, manual-source fragment',
      () async {
        final id = await repo.addFragmentFromMessage(
          sessionId: 's',
          messageId: 'm2',
          content: 'pickled herring recipe',
          importance: 0.9,
        );
        final frag = await repo.getFragment(id);
        expect(frag, isNotNull);
        expect(frag!.source, 'manual');
        expect(frag.sourceMessageId, 'm2');
        expect(frag.importanceScore, 0.9);
        final hits = await repo.searchFragments('herring');
        expect(hits.map((h) => h.id), contains(id));
      },
    );

    test('getFragmentByMessageId returns null for unknown or null id',
        () async {
      expect(await repo.getFragmentByMessageId(null), isNull);
      expect(await repo.getFragmentByMessageId('nope'), isNull);
    });
  });
}

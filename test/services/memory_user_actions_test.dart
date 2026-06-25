import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/memory_service.dart';
import 'package:rfbrowser/services/memory_stats_service.dart';
import '../helpers/sqflite_test_setup.dart';

MemoryFragment _frag({
  required String id,
  String content = 'sample',
  MemoryTier tier = MemoryTier.short,
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

  group('MemoryService addFragmentFromMessage', () {
    late MemoryService memory;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_add_').path,
          'memory.db',
        ),
      );
    });
    tearDown(() async => memory.close());

    test('inserts a new fragment and links to message id', () async {
      final id = await memory.addFragmentFromMessage(
        sessionId: 's1',
        messageId: 'm1',
        content: 'remember me',
        importance: 0.7,
      );
      expect(id, isNotEmpty);
      final frag = await memory.getFragment(id);
      expect(frag, isNotNull);
      expect(frag!.content, 'remember me');
      expect(frag.sourceMessageId, 'm1');
      expect(frag.source, 'manual');
      expect(frag.importanceScore, 0.7);
    });

    test('is idempotent on duplicate message id', () async {
      final id1 = await memory.addFragmentFromMessage(
        sessionId: 's1',
        messageId: 'm2',
        content: 'first',
      );
      final id2 = await memory.addFragmentFromMessage(
        sessionId: 's1',
        messageId: 'm2',
        content: 'second',
      );
      expect(id1, id2, reason: 'second call should return the original id');
      // The content is NOT updated on the second call.
      final frag = await memory.getFragment(id1);
      expect(frag!.content, 'first');
    });

    test('newly inserted fragment is searchable via FTS', () async {
      await memory.addFragmentFromMessage(
        sessionId: 's1',
        messageId: 'm3',
        content: 'pickled herring is excellent',
      );
      final results = await memory.searchFragments('herring');
      expect(
        results.map((r) => r.content),
        contains('pickled herring is excellent'),
      );
    });
  });

  group('MemoryService forgetFragment', () {
    late MemoryService memory;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_forget_').path,
          'memory.db',
        ),
      );
    });
    tearDown(() async => memory.close());

    test('marks the fragment inactive and updates source', () async {
      final id = await memory.addFragmentFromMessage(
        sessionId: 's',
        messageId: 'mf',
        content: 'a thing',
      );
      await memory.forgetFragment(id);
      final frag = await memory.getFragment(id);
      expect(frag, isNotNull);
      expect(frag!.isActive, isFalse);
      expect(frag.source, 'forgotten');
    });

    test('forgotten fragments are excluded from search', () async {
      final id = await memory.addFragmentFromMessage(
        sessionId: 's',
        messageId: 'mf2',
        content: 'kombucha kvass',
      );
      var hits = await memory.searchFragments('kombucha');
      expect(hits.map((r) => r.id), contains(id));
      await memory.forgetFragment(id);
      hits = await memory.searchFragments('kombucha');
      expect(hits.map((r) => r.id), isNot(contains(id)));
    });
  });

  group('MemoryService getFragmentByMessageId', () {
    late MemoryService memory;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_msgid_').path,
          'memory.db',
        ),
      );
    });
    tearDown(() async => memory.close());

    test('returns null for unknown message id', () async {
      expect(await memory.getFragmentByMessageId(null), isNull);
      expect(await memory.getFragmentByMessageId('nope'), isNull);
    });

    test('returns the fragment when one exists', () async {
      await memory.addFragmentFromMessage(
        sessionId: 's',
        messageId: 'm10',
        content: 'hello',
      );
      final frag = await memory.getFragmentByMessageId('m10');
      expect(frag, isNotNull);
      expect(frag!.content, 'hello');
    });
  });

  group('MemoryService getTopHebbianEdges / getNetworkedFragments', () {
    late MemoryService memory;
    setUp(() async {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_graph_').path,
          'memory.db',
        ),
      );
      // Build a small network.
      await memory.upsertFragment(
        _frag(id: 'n1', content: 'rust is fast', importance: 0.6),
      );
      await memory.upsertFragment(
        _frag(id: 'n2', content: 'rust is safe', importance: 0.5),
      );
      await memory.upsertFragment(
        _frag(id: 'n3', content: 'go is also fast', importance: 0.4),
      );
      await memory.upsertFragment(
        _frag(id: 'n4', content: 'unconnected fact', importance: 0.1),
      );
      await memory.upsertHebbianEdge(
        'n1',
        'n2',
        strengthDelta: 0.1,
        stability: 1.0,
        now: DateTime.now(),
      );
      await memory.upsertHebbianEdge(
        'n1',
        'n3',
        strengthDelta: 0.05,
        stability: 1.0,
        now: DateTime.now(),
      );
      await memory.upsertHebbianEdge(
        'n2',
        'n3',
        strengthDelta: 0.2,
        stability: 1.0,
        now: DateTime.now(),
      );
    });
    tearDown(() async => memory.close());

    test('getTopHebbianEdges returns edges ordered by strength', () async {
      final edges = await memory.getTopHebbianEdges();
      expect(edges.length, 3);
      // Highest strength first.
      expect(edges[0].fragmentA == 'n2' || edges[0].fragmentB == 'n2', isTrue);
      expect(edges[0].strength, greaterThanOrEqualTo(edges[1].strength));
      expect(edges[1].strength, greaterThanOrEqualTo(edges[2].strength));
    });

    test('getNetworkedFragments excludes fragments without edges', () async {
      final fragments = await memory.getNetworkedFragments();
      final ids = fragments.map((f) => f.id).toSet();
      expect(ids, containsAll({'n1', 'n2', 'n3'}));
      expect(ids, isNot(contains('n4')));
    });
  });

  group('MemoryInsightsService', () {
    late MemoryService memory;
    late MemoryInsightsService insights;
    setUp(() {
      memory = MemoryService(
        p.join(
          Directory.systemTemp.createTempSync('rfbrowser_insights_').path,
          'memory.db',
        ),
      );
      insights = MemoryInsightsService(memory);
    });
    tearDown(() async => memory.close());

    test('returns empty insights on empty db', () async {
      final r = await insights.compute();
      expect(r.isEmpty, isTrue);
      expect(r.trending, isEmpty);
      expect(r.topFragments, isEmpty);
    });

    test('extracts trending keywords from fragments', () async {
      await memory.upsertFragment(
        _frag(
          id: 't1',
          content: 'rust programming language rust',
          createdAt: DateTime.now(),
        ),
      );
      await memory.upsertFragment(
        _frag(
          id: 't2',
          content: 'rust borrow checker rocks',
          createdAt: DateTime.now(),
        ),
      );
      final r = await insights.compute(windowDays: 7);
      expect(r.trending, isNotEmpty);
      final topWord = r.trending.first.word;
      expect([
        'rust',
        'programming',
        'language',
        'borrow',
        'checker',
        'rocks',
      ], contains(topWord));
    });

    test('topFragments are ranked by importance × accessCount', () async {
      await memory.upsertFragment(
        _frag(id: 'p1', content: 'low imp', importance: 0.1, accessCount: 0),
      );
      await memory.upsertFragment(
        _frag(id: 'p2', content: 'high imp', importance: 0.9, accessCount: 1),
      );
      final r = await insights.compute();
      expect(r.topFragments.first.id, 'p2');
    });

    test(
      'forgottenCount counts source = forgotten and inactive rows',
      () async {
        await memory.upsertFragment(
          _frag(id: 'a1', content: 'normal', source: 'auto'),
        );
        final id = await memory.addFragmentFromMessage(
          sessionId: 's',
          messageId: 'mm',
          content: 'will be forgotten',
        );
        await memory.forgetFragment(id);
        final r = await insights.compute();
        expect(r.forgottenCount, greaterThanOrEqualTo(1));
      },
    );
  });
}

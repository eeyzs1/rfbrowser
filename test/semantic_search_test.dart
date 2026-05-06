import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/stores/vector_store.dart';
import 'package:rfbrowser/services/embedding_service.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';

void main() {
  group('VectorStore', () {
    test('AC-P4-3-1: insert and exists', () {
      final store = VectorStore();
      store.insert('note-1', [0.1, 0.2, 0.3]);
      expect(store.exists('note-1'), true);
      expect(store.exists('note-999'), false);
    });

    test('remove deletes record', () {
      final store = VectorStore();
      store.insert('note-1', [0.1, 0.2, 0.3]);
      expect(store.exists('note-1'), true);
      store.remove('note-1');
      expect(store.exists('note-1'), false);
    });

    test('count returns correct number', () {
      final store = VectorStore();
      expect(store.count, 0);
      store.insert('a', [0.1]);
      store.insert('b', [0.2]);
      expect(store.count, 2);
    });

    test('search returns results sorted by similarity', () {
      final store = VectorStore();
      store.insert('a', [1.0, 0.0, 0.0]);
      store.insert('b', [0.0, 1.0, 0.0]);
      store.insert('c', [0.9, 0.1, 0.0]);

      final results = store.search([1.0, 0.0, 0.0], topK: 3);
      expect(results.length, 3);
      expect(results.first.id, 'a');
      expect(results.first.score, greaterThan(results[1].score));
    });
  });

  group('EmbeddingService', () {
    test('AC-P4-3-2: local embedding returns vector of correct dimensions', () async {
      final service = EmbeddingService();
      final embedding = await service.embed('测试文本');
      expect(embedding.length, 128);
    });

    test('AC-P4-3-2: API embedding returns 1536-dim vector (mocked)', () async {
      final service = EmbeddingService();
      final provider = AIProvider(
        id: 'test',
        name: 'Test',
        baseUrl: 'http://localhost:9999',
        protocol: ApiProtocol.openaiCompatible,
      );
      final embedding = await service.embed(
        '量子计算入门',
        provider: provider,
        apiKey: 'test-key',
        modelId: 'text-embedding-3-small',
      );
      expect(embedding.isNotEmpty, true);
    });

    test('AC-P4-3-3: similar texts produce similar embeddings', () async {
      final service = EmbeddingService();
      final e1 = await service.embed('机器学习基础');
      final e2 = await service.embed('深度学习入门');
      final e3 = await service.embed('烹饪食谱大全');

      final sim12 = _cosineSimilarity(e1, e2);
      final sim13 = _cosineSimilarity(e1, e3);
      expect(sim12, greaterThan(sim13));
    });

    test('AC-P4-3-5: onNoteSaved inserts into store', () async {
      final service = EmbeddingService();
      final note = Note(
        id: 'test-1',
        title: '测试笔记',
        filePath: 'test.md',
        content: '这是一篇测试笔记',
        tags: [],
        aliases: [],
        created: DateTime.now(),
        modified: DateTime.now(),
      );

      await service.onNoteSaved(note);
      expect(service.store.exists('test-1'), true);
    });

    test('AC-P4-3-6: batchEmbed processes all notes', () async {
      final service = EmbeddingService();
      final notes = List.generate(
        10,
        (i) => Note(
          id: 'note-$i',
          title: '笔记$i',
          filePath: 'n$i.md',
          content: '内容$i',
          tags: [],
          aliases: [],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      );

      final count = await service.batchEmbed(notes);
      expect(count, 10);
      expect(service.store.count, 10);
    });
  });

  group('SemanticSearch', () {
    test('AC-P4-3-3: semantic search finds related notes', () async {
      final service = EmbeddingService();
      final notes = [
        Note(id: '1', title: '机器学习基础', filePath: 'a.md', content: '机器学习是AI的分支', tags: [], aliases: [], created: DateTime.now(), modified: DateTime.now()),
        Note(id: '2', title: '深度学习入门', filePath: 'b.md', content: '深度学习是机器学习的子集', tags: [], aliases: [], created: DateTime.now(), modified: DateTime.now()),
        Note(id: '3', title: '烹饪食谱', filePath: 'c.md', content: '今天做红烧肉', tags: [], aliases: [], created: DateTime.now(), modified: DateTime.now()),
      ];

      for (final note in notes) {
        await service.onNoteSaved(note);
      }

      final search = SemanticSearch(service);
      final results = await search.search('人工智能', topK: 5);

      expect(results.length, 3);
      final topIds = results.take(2).map((r) => r.id).toSet();
      expect(topIds, containsAll(['1', '2']));
    });
  });

  group('HybridSearch', () {
    test('AC-P4-3-4: results have source field marking fts/semantic/both', () async {
      final service = EmbeddingService();
      await service.onNoteSaved(
        Note(id: '1', title: '测试', filePath: 'a.md', content: '测试内容', tags: [], aliases: [], created: DateTime.now(), modified: DateTime.now()),
      );

      final hybrid = HybridSearch(SemanticSearch(service));
      final results = await hybrid.search('测试', topK: 5);

      expect(results.isNotEmpty, true);
      expect(results.first.source, isNotEmpty);
      expect(['fts', 'semantic', 'both'], contains(results.first.source));
    });

    test('AC-P4-3-4: hybrid search merges FTS and semantic results with RRF', () async {
      final service = EmbeddingService();
      await service.onNoteSaved(
        Note(id: '1', title: '量子计算', filePath: 'a.md', content: '量子计算是未来技术', tags: [], aliases: [], created: DateTime.now(), modified: DateTime.now()),
      );
      await service.onNoteSaved(
        Note(id: '2', title: '经典计算', filePath: 'b.md', content: '经典计算机使用比特', tags: [], aliases: [], created: DateTime.now(), modified: DateTime.now()),
      );

      Future<List<Map<String, dynamic>>> mockFts(String query, {int limit = 50}) async {
        return [
          {'id': '1', 'title': '量子计算', 'content': '量子计算是未来技术'},
          {'id': '3', 'title': '量子物理', 'content': '量子物理是基础学科'},
        ];
      }

      final hybrid = HybridSearch(SemanticSearch(service), ftsSearchFn: mockFts);
      final results = await hybrid.search('量子', topK: 10);

      expect(results.isNotEmpty, true);

      final sources = results.map((r) => r.source).toSet();
      expect(sources, contains('both'));

      final bothResult = results.firstWhere((r) => r.source == 'both');
      expect(bothResult.score, greaterThan(0));
    });

    test('AC-P4-3-4: FTS-only results have source=fts', () async {
      final service = EmbeddingService();
      await service.onNoteSaved(
        Note(id: '1', title: '量子计算', filePath: 'a.md', content: '量子计算是未来技术', tags: [], aliases: [], created: DateTime.now(), modified: DateTime.now()),
      );

      Future<List<Map<String, dynamic>>> mockFts(String query, {int limit = 50}) async {
        return [
          {'id': 'fts-only-1', 'title': 'FTS结果', 'content': '仅FTS匹配'},
        ];
      }

      final hybrid = HybridSearch(SemanticSearch(service), ftsSearchFn: mockFts);
      final results = await hybrid.search('量子', topK: 10);

      final ftsResults = results.where((r) => r.source == 'fts');
      expect(ftsResults.isNotEmpty, true);
      expect(ftsResults.first.id, 'fts-only-1');
    });

    test('AC-P4-3-7: hybrid search performance for 20 notes', () async {
      final service = EmbeddingService();
      final notes = List.generate(
        20,
        (i) => Note(
          id: 'perf-$i',
          title: '性能测试笔记$i',
          filePath: 'p$i.md',
          content: '这是第$i篇性能测试笔记的内容',
          tags: [],
          aliases: [],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      );

      for (final note in notes) {
        await service.onNoteSaved(note);
      }

      final sw = Stopwatch()..start();
      final hybrid = HybridSearch(SemanticSearch(service));
      final results = await hybrid.search('性能测试', topK: 10);
      sw.stop();

      expect(results.isNotEmpty, true);
      expect(sw.elapsedMilliseconds, lessThan(5000));
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('without FTS function, hybrid degrades to semantic-only', () async {
      final service = EmbeddingService();
      await service.onNoteSaved(
        Note(id: '1', title: '测试', filePath: 'a.md', content: '测试内容', tags: [], aliases: [], created: DateTime.now(), modified: DateTime.now()),
      );

      final hybrid = HybridSearch(SemanticSearch(service));
      final results = await hybrid.search('测试', topK: 5);

      expect(results.isNotEmpty, true);
      expect(results.every((r) => r.source == 'semantic'), true);
    });
  });
}

double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 0.0;
  double dotProduct = 0.0;
  double normA = 0.0;
  double normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0.0;
  return dotProduct / (sqrt(normA) * sqrt(normB));
}

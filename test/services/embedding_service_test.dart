import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/embedding_service.dart';

List<double> _makeEmbedding(String text) {
  final random = Random(text.hashCode);
  return List<double>.generate(128, (_) => random.nextDouble() * 2 - 1);
}

void main() {
  group('EmbeddingService', () {
    late EmbeddingService service;

    setUp(() {
      service = EmbeddingService();
    });

    test('HNSW Index: can insert and search vectors', () {
      final hnsw = service.hnswIndex;

      final vec1 = _makeEmbedding('Flutter UI toolkit');
      final vec2 = _makeEmbedding('Flutter widget development');
      final vec3 = _makeEmbedding('Python data science');

      hnsw.insert('note-1', vec1, metadata: {'title': 'Flutter'});
      hnsw.insert('note-2', vec2, metadata: {'title': 'Dart'});
      hnsw.insert('note-3', vec3, metadata: {'title': 'Python'});

      final query = _makeEmbedding('Flutter development');
      final results = hnsw.search(query, k: 2, ef: 50);

      expect(results.length, 2);
    });

    test('HNSW Index: search returns metadata', () {
      final hnsw = service.hnswIndex;

      hnsw.insert(
        'doc-1',
        _makeEmbedding('test document one'),
        metadata: {'title': 'Document One', 'tags': ['test']},
      );

      final results = hnsw.search(_makeEmbedding('test'), k: 1, ef: 50);

      expect(results.length, 1);
      expect(results[0].id, 'doc-1');
      expect(results[0].metadata['title'], 'Document One');
      expect(results[0].metadata['tags'], ['test']);
    });

    test('HybridSearch: semantic results returned', () async {
      final semanticSearch = SemanticSearch(service);
      final hnsw = service.hnswIndex;

      hnsw.insert(
        'note-a',
        _makeEmbedding('Flutter widget testing guide'),
        metadata: {'title': 'Test Guide'},
      );

      final results = await semanticSearch.search('Flutter testing');
      expect(results.isNotEmpty, isTrue);
    });

    test('HybridSearch: with FTS fallback merges results', () async {
      final semanticSearch = SemanticSearch(service);
      final hnsw = service.hnswIndex;

      hnsw.insert(
        'semantic-note',
        _makeEmbedding('Machine learning basics'),
        metadata: {'title': 'ML Basics'},
      );

      final hybridSearch = HybridSearch(
        semanticSearch,
        ftsSearchFn: (query, {limit = 50}) async {
          return [
            {
              'id': 'fts-note',
              'title': 'ML Advanced',
              'file_path': 'ml-advanced.md',
            },
          ];
        },
      );

      final results = await hybridSearch.search('machine learning', topK: 10);

      expect(results.length, 2);
    });

    test('HybridSearchResult: has required fields', () {
      final result = HybridSearchResult(
        id: 'test-id',
        score: 0.85,
        source: 'semantic',
        metadata: {'title': 'Test'},
      );

      expect(result.id, 'test-id');
      expect(result.score, 0.85);
      expect(result.source, 'semantic');
      expect(result.metadata['title'], 'Test');
    });

    test('HybridSearch: respects topK limit', () async {
      final semanticSearch = SemanticSearch(service);
      final hnsw = service.hnswIndex;

      for (int i = 0; i < 10; i++) {
        hnsw.insert(
          'note-$i',
          _makeEmbedding('document number $i'),
          metadata: {'title': 'Doc $i'},
        );
      }

      final hybridSearch = HybridSearch(semanticSearch);
      final results = await hybridSearch.search('document', topK: 5);

      expect(results.length, lessThanOrEqualTo(5));
    });
  });
}

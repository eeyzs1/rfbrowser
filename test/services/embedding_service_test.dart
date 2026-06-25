import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../helpers/sqflite_test_setup.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
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
        metadata: {
          'title': 'Document One',
          'tags': ['test'],
        },
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

    group('cosineSimilarity (G10-AC2)', () {
      test('returns 1.0 for identical vectors', () {
        final v = [1.0, 2.0, 3.0];
        expect(EmbeddingService.cosineSimilarity(v, v), closeTo(1.0, 1e-9));
      });

      test('returns -1.0 for opposite vectors', () {
        final a = [1.0, 0.0];
        final b = [-1.0, 0.0];
        expect(EmbeddingService.cosineSimilarity(a, b), closeTo(-1.0, 1e-9));
      });

      test('returns ~0.0 for orthogonal vectors', () {
        final a = [1.0, 0.0];
        final b = [0.0, 1.0];
        expect(EmbeddingService.cosineSimilarity(a, b), closeTo(0.0, 1e-9));
      });

      test('returns 0.0 for zero-norm vectors', () {
        expect(EmbeddingService.cosineSimilarity([0.0, 0.0], [1.0, 2.0]), 0.0);
        expect(EmbeddingService.cosineSimilarity([1.0, 2.0], [0.0, 0.0]), 0.0);
      });

      test('returns 0.0 for empty vectors', () {
        expect(EmbeddingService.cosineSimilarity([], [1.0, 2.0]), 0.0);
        expect(EmbeddingService.cosineSimilarity([1.0, 2.0], []), 0.0);
      });

      test('handles different-length vectors (uses min length)', () {
        final a = [1.0, 2.0, 3.0];
        final b = [1.0, 2.0];
        // dot = 1 + 4 = 5; |a|² = 14; |b|² = 5; cos = 5 / sqrt(70)
        expect(
          EmbeddingService.cosineSimilarity(a, b),
          closeTo(5.0 / sqrt(70.0), 1e-9),
        );
      });

      test('result is always within [-1, 1] (clamped)', () {
        // Construct pathological vectors where floating-point could overflow.
        final v = [1e200, 1e200, 1e200];
        final r = EmbeddingService.cosineSimilarity(v, v);
        expect(r, greaterThanOrEqualTo(-1.0));
        expect(r, lessThanOrEqualTo(1.0));
      });
    });

    group('loadPersistedEmbeddings dimension mismatch', () {
      setUpAll(setupSqfliteForTests);

      test('clears persisted vectors when dimensions are inconsistent', () async {
        final tempDir =
            Directory.systemTemp.createTempSync('rfbrowser_emb_test_');
        final dbPath = p.join(tempDir.path, 'index.db');
        final indexStore = IndexStore(dbPath);
        final service = EmbeddingService(indexStore);

        try {
          // Insert 128-dim vectors (simulating old local-fallback embeddings).
          await indexStore.upsertEmbedding(
            'note-1',
            List.generate(128, (i) => i * 0.01),
            metadata: {'title': 'Old Note 1'},
          );
          await indexStore.upsertEmbedding(
            'note-2',
            List.generate(128, (i) => i * 0.02),
            metadata: {'title': 'Old Note 2'},
          );
          // Insert a 384-dim vector (simulating ONNX embeddings).
          await indexStore.upsertEmbedding(
            'note-3',
            List.generate(384, (i) => i * 0.001),
            metadata: {'title': 'ONNX Note'},
          );

          // loadPersistedEmbeddings should detect the mismatch and clear all.
          final result = await service.loadPersistedEmbeddings();
          expect(result, isEmpty);

          // All persisted vectors should be deleted.
          final remaining = await indexStore.getAllEmbeddings();
          expect(remaining, isEmpty);
        } finally {
          await indexStore.close();
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });

      test('loads consistent-dimension vectors without clearing', () async {
        final tempDir =
            Directory.systemTemp.createTempSync('rfbrowser_emb_test_');
        final dbPath = p.join(tempDir.path, 'index.db');
        final indexStore = IndexStore(dbPath);
        final service = EmbeddingService(indexStore);

        try {
          // Insert 128-dim vectors (all consistent).
          await indexStore.upsertEmbedding(
            'note-1',
            List.generate(128, (i) => i * 0.01),
            metadata: {'title': 'Note 1'},
          );
          await indexStore.upsertEmbedding(
            'note-2',
            List.generate(128, (i) => i * 0.02),
            metadata: {'title': 'Note 2'},
          );

          final result = await service.loadPersistedEmbeddings();
          expect(result.length, 2);
          expect(result, containsAll(['note-1', 'note-2']));
          expect(service.hnswIndex.size, 2);
        } finally {
          await indexStore.close();
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });
    });
  });
}

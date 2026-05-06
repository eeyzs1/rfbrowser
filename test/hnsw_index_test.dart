// ignore_for_file: unused_element
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/stores/hnsw_index.dart';

SearchResult? _bruteForceSearch(Map<String, List<double>> vectors, List<double> query, String targetId) {
  double bestDist = double.infinity;
  for (final entry in vectors.entries) {
    final dist = _euclideanDist(entry.value, query);
    if (dist < bestDist) {
      bestDist = dist;
      if (entry.key == targetId) return SearchResult(id: entry.key, score: 1.0 - dist);
    }
  }
  return null;
}

double _euclideanDist(List<double> a, List<double> b) {
  double sum = 0;
  for (int i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]) * (a[i] - b[i]);
  }
  return sqrt(sum);
}

List<SearchResult> _bruteForceTopK(Map<String, List<double>> vectors, List<double> query, int k) {
  final results = <SearchResult>[];
  for (final entry in vectors.entries) {
    final dist = _euclideanDist(entry.value, query);
    results.add(SearchResult(id: entry.key, score: 1.0 - dist));
  }
  results.sort((a, b) => b.score.compareTo(a.score));
  return results.take(k).toList();
}

void main() {
  group('HnswIndex basic operations', () {
    test('AC-1.1 empty index returns empty results', () {
      final index = HnswIndex();
      final results = index.search([1.0, 0.0], k: 10);
      expect(results, isEmpty);
    });

    test('AC-1.2 insert and search returns the inserted node', () {
      final index = HnswIndex();
      index.insert('n1', [1.0, 0.0, 0.0]);
      final results = index.search([1.0, 0.0, 0.0], k: 1);
      expect(results.length, 1);
      expect(results.first.id, 'n1');
      expect(results.first.score, closeTo(1.0, 0.01));
    });

    test('AC-1.3 remove eliminates node from search', () {
      final index = HnswIndex();
      index.insert('n1', [1.0, 0.0]);
      index.remove('n1');
      expect(index.search([1.0, 0.0], k: 10), isEmpty);
    });

    test('AC-1.4 clear empties index', () {
      final index = HnswIndex();
      index.insert('n1', [1.0, 0.0]);
      index.clear();
      expect(index.size, 0);
      expect(index.search([1.0, 0.0], k: 10), isEmpty);
    });

    test('AC-1.5 many inserts do not crash', () {
      final index = HnswIndex(M: 8, efConstruction: 50);
      final rng = Random(42);
      for (var i = 0; i < 500; i++) {
        final vec = List.generate(128, (_) => rng.nextDouble());
        index.insert('n$i', vec);
      }
      expect(index.size, 500);
      final results = index.search(List.generate(128, (_) => rng.nextDouble()), k: 5);
      expect(results.length, 5);
    });

    test('inserting same id twice updates the vector', () {
      final index = HnswIndex();
      index.insert('n1', [1.0, 0.0]);
      index.insert('n1', [0.0, 1.0]);
      expect(index.size, 1);
      final results = index.search([0.0, 1.0], k: 1);
      expect(results.first.id, 'n1');
      expect(results.first.score, closeTo(1.0, 0.01));
    });

    test('remove non-existent id does not throw', () {
      final index = HnswIndex();
      index.insert('n1', [1.0, 0.0]);
      index.remove('n999');
      expect(index.size, 1);
    });

    test('search with zero k returns empty', () {
      final index = HnswIndex();
      index.insert('n1', [1.0, 0.0]);
      final results = index.search([1.0, 0.0], k: 0);
      expect(results, isEmpty);
    });

    test('stats returns correct structure', () {
      final index = HnswIndex(M: 4, efConstruction: 50);
      index.insert('n1', [1.0, 0.0]);
      index.insert('n2', [0.0, 1.0]);
      final stats = index.stats();
      expect(stats.containsKey('layers'), true);
      expect(stats.containsKey('nodes'), true);
      expect(stats.containsKey('connections'), true);
      expect(stats['nodes'], 2);
    });

    test('metadata is preserved', () {
      final index = HnswIndex();
      index.insert('n1', [1.0, 0.0], metadata: {'title': 'Test Note'});
      final results = index.search([1.0, 0.0], k: 1);
      expect(results.first.metadata['title'], 'Test Note');
    });
  });

  group('HnswIndex recall', () {
    test('AC-1.8 recall >= 80% against brute-force baseline', () {
      final index = HnswIndex(M: 16, efConstruction: 200);
      final rng = Random(42);
      final vectors = <String, List<double>>{};
      for (var i = 0; i < 500; i++) {
        final vec = List.generate(128, (_) => rng.nextDouble());
        vectors['n$i'] = vec;
        index.insert('n$i', vec);
      }

      int totalOverlap = 0;
      const numQueries = 20;
      for (var t = 0; t < numQueries; t++) {
        final query = List.generate(128, (_) => rng.nextDouble());

        final bruteTop10 = _bruteForceTopK(vectors, query, 10);
        final bruteIds = bruteTop10.map((e) => e.id).toSet();

        final hnswTop10 = index.search(query, k: 10, ef: 100);
        final hnswIds = hnswTop10.map((e) => e.id).toSet();

        final overlap = bruteIds.intersection(hnswIds).length;
        totalOverlap += overlap;
        expect(overlap, greaterThanOrEqualTo(8));
      }

      final avgRecall = totalOverlap / (numQueries * 10);
      expect(avgRecall, greaterThanOrEqualTo(0.80));
    });

    test('higher ef improves recall', () {
      final index = HnswIndex(M: 16, efConstruction: 200);
      final rng = Random(42);
      final vectors = <String, List<double>>{};
      for (var i = 0; i < 200; i++) {
        final vec = List.generate(64, (_) => rng.nextDouble());
        vectors['n$i'] = vec;
        index.insert('n$i', vec);
      }

      final query = List.generate(64, (_) => rng.nextDouble());
      final bruteTop5 = _bruteForceTopK(vectors, query, 5).map((e) => e.id).toSet();

      final efLow = index.search(query, k: 5, ef: 10).map((e) => e.id).toSet();
      final efHigh = index.search(query, k: 5, ef: 100).map((e) => e.id).toSet();

      final recallLow = bruteTop5.intersection(efLow).length;
      final recallHigh = bruteTop5.intersection(efHigh).length;

      expect(recallHigh, greaterThanOrEqualTo(recallLow));
    });
  });

  group('HnswIndex performance', () {
    test('AC-1.6 search <= 5ms for 2000 notes x 768d', () {
      final index = HnswIndex(M: 16, efConstruction: 200);
      final rng = Random(42);
      for (var i = 0; i < 2000; i++) {
        index.insert('n$i', List.generate(768, (_) => rng.nextDouble()));
      }
      final query = List.generate(768, (_) => rng.nextDouble());
      final sw = Stopwatch()..start();
      index.search(query, k: 10, ef: 100);
      sw.stop();
      expect(sw.elapsedMicroseconds, lessThan(5000));
    });

    test('AC-1.7 insert <= 50ms for 2000 existing notes', () {
      final index = HnswIndex(M: 16, efConstruction: 200);
      final rng = Random(42);
      for (var i = 0; i < 2000; i++) {
        index.insert('n$i', List.generate(768, (_) => rng.nextDouble()));
      }
      final sw = Stopwatch()..start();
      index.insert('new', List.generate(768, (_) => rng.nextDouble()));
      sw.stop();
      expect(sw.elapsedMicroseconds, lessThan(50000));
    });
  });
}

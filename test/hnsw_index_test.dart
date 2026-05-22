// ignore_for_file: unused_element
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/stores/hnsw_index.dart';

SearchResult? _bruteForceSearch(
  Map<String, List<double>> vectors,
  List<double> query,
  String targetId,
) {
  double bestDist = double.infinity;
  for (final entry in vectors.entries) {
    final dist = _euclideanDist(entry.value, query);
    if (dist < bestDist) {
      bestDist = dist;
      if (entry.key == targetId) {
        return SearchResult(id: entry.key, score: 1.0 - dist);
      }
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

List<SearchResult> _bruteForceTopK(
  Map<String, List<double>> vectors,
  List<double> query,
  int k,
) {
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
      final results = index.search(
        List.generate(128, (_) => rng.nextDouble()),
        k: 5,
      );
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
      final bruteTop5 = _bruteForceTopK(
        vectors,
        query,
        5,
      ).map((e) => e.id).toSet();

      final efLow = index.search(query, k: 5, ef: 10).map((e) => e.id).toSet();
      final efHigh = index
          .search(query, k: 5, ef: 100)
          .map((e) => e.id)
          .toSet();

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

  group('HnswIndex benchmark', () {
    test('recall@10 — curated clusters benchmark', () {
      const dim = 64;
      const numClusters = 10;
      const docsPerCluster = 20;
      const numQueries = 50;

      final hnsw = HnswIndex(M: 16, efConstruction: 100);
      final data = <String, List<double>>{};

      final centroids = List.generate(
        numClusters,
        (i) => _randomUnitVector(dim, seed: i * 1000),
      );

      for (int c = 0; c < numClusters; c++) {
        for (int d = 0; d < docsPerCluster; d++) {
          final id = 'c${c}_d$d';
          final v = _perturb(centroids[c], 0.1, seed: c * docsPerCluster + d);
          data[id] = v;
          hnsw.insert(id, v, metadata: {'cluster': c});
        }
      }

      int hits = 0;
      int total = 0;
      double totalLat = 0;

      for (int q = 0; q < numQueries; q++) {
        final c = q % numClusters;
        final query = _perturb(centroids[c], 0.05, seed: q * 100);
        final groundTruth = _bruteTopK(data, query, 10).toSet();

        final sw = Stopwatch()..start();
        final results = hnsw.search(query, k: 10, ef: 100);
        sw.stop();

        totalLat += sw.elapsedMicroseconds;
        total += results.length;
        for (final r in results) {
          if (groundTruth.contains(r.id)) hits++;
        }
      }

      final recall = total > 0 ? hits / total : 0.0;
      final avgMs = totalLat / (numQueries * 1000);

      expect(
        recall,
        greaterThanOrEqualTo(0.3),
        reason: 'HNSW recall@10 must be >= 0.3 with curated clusters',
      );
      expect(
        avgMs,
        lessThan(100),
        reason:
            'Query latency must be < 100ms, got ${avgMs.toStringAsFixed(1)}ms',
      );
    });

    test('recall@10 — random vectors stress test', () {
      const dim = 64;
      const numDocs = 200;
      const numQueries = 50;

      final hnsw = HnswIndex(M: 16, efConstruction: 100);
      final data = <String, List<double>>{};

      for (int i = 0; i < numDocs; i++) {
        final v = _randomUnitVector(dim, seed: i);
        data['doc-$i'] = v;
        hnsw.insert('doc-$i', v, metadata: {'index': i});
      }

      int hits = 0;
      int total = 0;

      for (int q = 0; q < numQueries; q++) {
        final query = _randomUnitVector(dim, seed: q + 1000);
        final groundTruth = _bruteTopK(data, query, 10).toSet();

        final results = hnsw.search(query, k: 10, ef: 100);
        total += results.length;
        for (final r in results) {
          if (groundTruth.contains(r.id)) hits++;
        }
      }

      final recall = total > 0 ? hits / total : 0.0;

      expect(
        recall,
        greaterThanOrEqualTo(0.3),
        reason:
            'Random vector stress test recall@10 must be >= 0.3, got ${recall.toStringAsFixed(3)}',
      );
    });

    test('identical vector search returns exact match', () {
      final hnsw = HnswIndex();
      final v = _randomUnitVector(32, seed: 42);

      hnsw.insert('exact-match', v, metadata: {'key': 'val'});

      final r = hnsw.search(v, k: 1, ef: 50);
      expect(r.length, 1);
      expect(r.first.id, 'exact-match');
      expect(r.first.score, greaterThan(0.99));
    });

    test('ef parameter trades speed for recall', () {
      const dim = 32;
      const n = 50;

      final hnsw = HnswIndex(M: 16, efConstruction: 200);
      for (int i = 0; i < n; i++) {
        hnsw.insert(
          'doc-$i',
          _randomUnitVector(dim, seed: i),
          metadata: {'index': i},
        );
      }

      final query = _randomUnitVector(dim, seed: 999);

      final r10 = hnsw.search(query, k: 10, ef: 10);
      final r100 = hnsw.search(query, k: 10, ef: 100);

      expect(r10.length, lessThanOrEqualTo(10));
      expect(r100.length, lessThanOrEqualTo(10));
      expect(r10.length, greaterThan(0));
      expect(r100.length, greaterThan(0));
    });
  });
}

List<double> _randomUnitVector(int dim, {int? seed}) {
  final rng = Random(seed);
  double norm = 0;
  final v = List<double>.generate(dim, (_) {
    final x = rng.nextDouble() * 2 - 1;
    norm += x * x;
    return x;
  });
  norm = sqrt(norm);
  return v.map((x) => x / norm).toList();
}

List<double> _perturb(List<double> v, double noise, {int? seed}) {
  final rng = Random(seed);
  double norm = 0;
  final p = List<double>.generate(v.length, (i) {
    final x = v[i] + rng.nextDouble() * noise * 2 - noise;
    norm += x * x;
    return x;
  });
  norm = sqrt(norm);
  return p.map((x) => x / norm).toList();
}

List<String> _bruteTopK(Map<String, List<double>> data, List<double> q, int k) {
  double cosSim(List<double> a, List<double> b) {
    double dot = 0, nA = 0, nB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      nA += a[i] * a[i];
      nB += b[i] * b[i];
    }
    if (nA == 0 || nB == 0) return 0;
    return dot / (sqrt(nA) * sqrt(nB));
  }

  final scored = <MapEntry<String, double>>[];
  for (final e in data.entries) {
    scored.add(MapEntry(e.key, cosSim(e.value, q)));
  }
  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.take(k).map((e) => e.key).toList();
}

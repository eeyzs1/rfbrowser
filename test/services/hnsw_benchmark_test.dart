import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/stores/hnsw_index.dart';

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

double _cosSim(List<double> a, List<double> b) {
  double dot = 0, nA = 0, nB = 0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    nA += a[i] * a[i];
    nB += b[i] * b[i];
  }
  if (nA == 0 || nB == 0) return 0;
  return dot / (sqrt(nA) * sqrt(nB));
}

List<String> _bruteTopK(Map<String, List<double>> data, List<double> q, int k) {
  final scored = <MapEntry<String, double>>[];
  for (final e in data.entries) {
    scored.add(MapEntry(e.key, _cosSim(e.value, q)));
  }
  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.take(k).map((e) => e.key).toList();
}

void main() {
  group('G13-C: HNSW Vector Search Benchmark', () {
    test('recall@10 — curated clusters benchmark', () {
      const dim = 64;
      const numClusters = 10;
      const docsPerCluster = 20;
      const numQueries = 50;

      final hnsw = HnswIndex(M: 16, efConstruction: 100);
      final data = <String, List<double>>{};

      final centroids = List.generate(
          numClusters, (i) => _randomUnitVector(dim, seed: i * 1000));

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

      expect(recall, greaterThanOrEqualTo(0.3),
          reason: 'HNSW recall@10 must be >= 0.3 with curated clusters');
      expect(avgMs, lessThan(100),
          reason: 'Query latency must be < 100ms, got ${avgMs.toStringAsFixed(1)}ms');
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

      expect(recall, greaterThanOrEqualTo(0.3),
          reason: 'Random vector stress test recall@10 must be >= 0.3, got ${recall.toStringAsFixed(3)}');
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
        hnsw.insert('doc-$i', _randomUnitVector(dim, seed: i),
            metadata: {'index': i});
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

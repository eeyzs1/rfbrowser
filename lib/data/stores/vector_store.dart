import 'dart:math';

class VectorRecord {
  final String id;
  final List<double> embedding;
  final Map<String, dynamic> metadata;
  final double _norm;

  VectorRecord({
    required this.id,
    required this.embedding,
    this.metadata = const {},
  }) : _norm = _computeNorm(embedding);

  static double _computeNorm(List<double> v) {
    double sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    return sqrt(sum);
  }

  double get norm => _norm;
}

class VectorStore {
  final Map<String, VectorRecord> _records = {};

  VectorStore();

  int get count => _records.length;

  bool exists(String id) => _records.containsKey(id);

  void insert(String id, List<double> embedding, {Map<String, dynamic>? metadata}) {
    _records[id] = VectorRecord(
      id: id,
      embedding: embedding,
      metadata: metadata ?? {},
    );
  }

  void remove(String id) {
    _records.remove(id);
  }

  List<SearchResult> search(List<double> queryEmbedding, {int topK = 20}) {
    if (_records.isEmpty) return [];

    final queryNorm = VectorRecord._computeNorm(queryEmbedding);
    if (queryNorm == 0) return [];

    final heap = <_HeapEntry>[];
    final queryLen = queryEmbedding.length;

    for (final record in _records.values) {
      if (record.embedding.length != queryLen || record.norm == 0) continue;

      double dotProduct = 0.0;
      final emb = record.embedding;
      for (var i = 0; i < queryLen; i++) {
        dotProduct += queryEmbedding[i] * emb[i];
      }
      final score = dotProduct / (queryNorm * record.norm);

      if (heap.length < topK) {
        heap.add(_HeapEntry(record.id, score, record.metadata));
        if (heap.length == topK) {
          _heapifyMin(heap);
        }
      } else if (score > heap.first.score) {
        heap[0] = _HeapEntry(record.id, score, record.metadata);
        _siftDownMin(heap, 0);
      }
    }

    heap.sort((a, b) => b.score.compareTo(a.score));
    return heap
        .map((e) => SearchResult(id: e.id, score: e.score, metadata: e.metadata))
        .toList();
  }

  void _heapifyMin(List<_HeapEntry> heap) {
    for (var i = heap.length ~/ 2 - 1; i >= 0; i--) {
      _siftDownMin(heap, i);
    }
  }

  void _siftDownMin(List<_HeapEntry> heap, int i) {
    final n = heap.length;
    while (true) {
      var smallest = i;
      final left = 2 * i + 1;
      final right = 2 * i + 2;
      if (left < n && heap[left].score < heap[smallest].score) smallest = left;
      if (right < n && heap[right].score < heap[smallest].score) smallest = right;
      if (smallest == i) break;
      final tmp = heap[i];
      heap[i] = heap[smallest];
      heap[smallest] = tmp;
      i = smallest;
    }
  }

  void clear() {
    _records.clear();
  }
}

class _HeapEntry {
  final String id;
  final double score;
  final Map<String, dynamic> metadata;

  _HeapEntry(this.id, this.score, this.metadata);
}

class SearchResult {
  final String id;
  final double score;
  final Map<String, dynamic> metadata;

  SearchResult({
    required this.id,
    required this.score,
    this.metadata = const {},
  });
}

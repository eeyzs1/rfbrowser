import 'dart:math';

class HnswIndex {
  final int M;
  final int efConstruction;
  final int _maxLayer0Connections;
  final double _mL;

  int _entryPoint = -1;
  int _maxLevel = -1;

  final List<List<double>> _vectors = [];
  final List<String> _ids = [];
  final List<Map<String, dynamic>> _metadata = [];
  final List<int> _levels = [];
  final List<List<int>> _graphs = [];

  final Random _rng;

  HnswIndex({
    this.M = 16,
    this.efConstruction = 200,
    int? maxLayer0Connections,
    double? mL,
    int? seed,
  })  : _maxLayer0Connections = maxLayer0Connections ?? M * 2,
        _mL = mL ?? 1.0 / log(M),
        _rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch);

  int get size => _ids.length;
  bool get isEmpty => _ids.isEmpty;

  void insert(String id, List<double> vector, {Map<String, dynamic>? metadata}) {
    final existingIndex = _ids.indexOf(id);
    if (existingIndex >= 0) {
      _vectors[existingIndex] = List.from(vector);
      _metadata[existingIndex] = metadata ?? {};
      return;
    }

    final level = _randomLevel();
    final nodeIndex = _ids.length;

    _ids.add(id);
    _vectors.add(List.from(vector));
    _metadata.add(metadata ?? {});
    _levels.add(level);
    _graphs.add([]);

    if (_entryPoint == -1) {
      _entryPoint = nodeIndex;
      _maxLevel = level;
      return;
    }

    var currNode = _entryPoint;
    var currDist = _distance(_vectors[nodeIndex], _vectors[currNode]);

    for (var lc = _maxLevel; lc > level; lc--) {
      var changed = true;
      while (changed) {
        changed = false;
        for (final neighbor in _graphs[currNode]) {
          if (_levels[neighbor] < lc) continue;
          final dist = _distance(_vectors[nodeIndex], _vectors[neighbor]);
          if (dist < currDist) {
            currDist = dist;
            currNode = neighbor;
            changed = true;
          }
        }
      }
    }

    for (var lc = min(level, _maxLevel); lc >= 0; lc--) {
      final candidates = _searchLayer(_vectors[nodeIndex], currNode, efConstruction, lc);

      final mMax = lc == 0 ? _maxLayer0Connections : M;
      final neighbors = _selectNeighborsHeuristic(candidates, mMax, lc);

      for (final neighbor in neighbors) {
        _addBidirectionalConnection(nodeIndex, neighbor);

        final neighborConnections = _graphs[neighbor];
        if (neighborConnections.length > mMax) {
          _pruneConnections(neighbor, mMax);
        }
      }

      if (candidates.isNotEmpty) {
        currNode = candidates.first;
        currDist = _distance(_vectors[nodeIndex], _vectors[currNode]);
      }
    }

    if (level > _maxLevel) {
      _maxLevel = level;
      _entryPoint = nodeIndex;
    }
  }

  void remove(String id) {
    final index = _ids.indexOf(id);
    if (index < 0) return;

    for (final neighbor in List.from(_graphs[index])) {
      _graphs[neighbor].remove(index);
    }
    _graphs[index].clear();

    _vectors[index] = List.filled(_vectors[index].length, 0.0);

    if (index == _entryPoint) {
      _entryPoint = -1;
      for (var i = 0; i < _ids.length; i++) {
        if (_vectors[i].every((v) => v == 0.0)) continue;
        if (_entryPoint == -1 || _levels[i] > _levels[_entryPoint]) {
          _entryPoint = i;
        }
      }
      _maxLevel = _entryPoint >= 0 ? _levels[_entryPoint] : -1;
    }
  }

  List<SearchResult> search(List<double> query, {int k = 20, int ef = 100}) {
    if (_entryPoint == -1) return [];

    var currNode = _entryPoint;
    var currDist = _distance(query, _vectors[currNode]);

    for (var lc = _maxLevel; lc > 0; lc--) {
      var changed = true;
      while (changed) {
        changed = false;
        for (final neighbor in _graphs[currNode]) {
          if (_levels[neighbor] < lc) continue;
          final dist = _distance(query, _vectors[neighbor]);
          if (dist < currDist) {
            currDist = dist;
            currNode = neighbor;
            changed = true;
          }
        }
      }
    }

    final searchEf = max(k, ef);
    final candidates = _searchLayer(query, currNode, searchEf, 0);
    final results = candidates.take(k).toList();

    return results.map((idx) {
      return SearchResult(
        id: _ids[idx],
        score: 1.0 - _distance(query, _vectors[idx]),
        metadata: _metadata[idx],
      );
    }).toList();
  }

  void clear() {
    _entryPoint = -1;
    _maxLevel = -1;
    _vectors.clear();
    _ids.clear();
    _metadata.clear();
    _levels.clear();
    _graphs.clear();
  }

  Map<String, dynamic> stats() {
    var totalConnections = 0;
    var layerCounts = <int, int>{};
    for (var i = 0; i < _ids.length; i++) {
      totalConnections += _graphs[i].length;
      layerCounts[_levels[i]] = (layerCounts[_levels[i]] ?? 0) + 1;
    }
    return {
      'layers': _maxLevel + 1,
      'nodes': _ids.length,
      'connections': totalConnections,
      'layerNodes': layerCounts,
    };
  }

  int _randomLevel() {
    final r = max(1e-10, _rng.nextDouble());
    return max(0, (-log(r) * _mL).floor());
  }

  double _distance(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  List<int> _searchLayer(List<double> query, int entryPoint, int ef, int layer) {
    final visited = <int>{entryPoint};
    final candidates = HeapPriorityQueue<_DistNode>((a, b) => a.dist.compareTo(b.dist));
    final results = HeapPriorityQueue<_DistNode>((a, b) => b.dist.compareTo(a.dist));

    final entryDist = _distance(query, _vectors[entryPoint]);
    candidates.add(_DistNode(entryPoint, entryDist));
    results.add(_DistNode(entryPoint, entryDist));

    while (candidates.isNotEmpty) {
      final current = candidates.removeFirst();
      final worstResult = results.first;

      if (current.dist > worstResult.dist && results.length >= ef) break;

      for (final neighbor in _graphs[current.node]) {
        if (_levels[neighbor] < layer) continue;
        if (visited.contains(neighbor)) continue;
        visited.add(neighbor);

        final dist = _distance(query, _vectors[neighbor]);
        final worstDist = results.first.dist;

        if (dist < worstDist || results.length < ef) {
          candidates.add(_DistNode(neighbor, dist));
          results.add(_DistNode(neighbor, dist));
          if (results.length > ef) {
            results.removeFirst();
          }
        }
      }
    }

    final sorted = <int>[];
    while (results.isNotEmpty) {
      sorted.insert(0, results.removeFirst().node);
    }
    return sorted;
  }

  List<int> _selectNeighborsHeuristic(List<int> candidates, int mMax, int layer) {
    if (candidates.length <= mMax) return candidates;

    final selected = <int>[];
    final discarded = <int>[];

    for (final c in candidates) {
      if (selected.length >= mMax) break;

      if (selected.isEmpty) {
        selected.add(c);
        continue;
      }

      final distToQuery = _distance(_vectors[c], _vectors[candidates.first]);

      var keepCloser = false;

      for (final s in selected) {
        final distToSelected = _distance(_vectors[c], _vectors[s]);
        if (distToSelected < distToQuery) {
          keepCloser = true;
          break;
        }
      }

      if (keepCloser) {
        selected.add(c);
      } else {
        discarded.add(c);
      }
    }

    var result = List<int>.from(selected);
    var remaining = mMax - result.length;
    if (remaining > 0) {
      for (final d in discarded.take(remaining)) {
        result.add(d);
      }
      result = result.take(mMax).toList();
    }

    return result;
  }

  void _addBidirectionalConnection(int from, int to) {
    if (!_graphs[from].contains(to)) {
      _graphs[from].add(to);
    }
    if (!_graphs[to].contains(from)) {
      _graphs[to].add(from);
    }
  }

  void _pruneConnections(int nodeIndex, int mMax) {
    final connections = _graphs[nodeIndex];
    if (connections.length <= mMax) return;

    final entries = <_DistNode>[];
    for (final neighbor in connections) {
      entries.add(_DistNode(neighbor, _distance(_vectors[nodeIndex], _vectors[neighbor])));
    }
    entries.sort((a, b) => a.dist.compareTo(b.dist));
    _graphs[nodeIndex] = entries.take(mMax).map((e) => e.node).toList();
  }
}

class _DistNode {
  final int node;
  final double dist;
  _DistNode(this.node, this.dist);
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

class HeapPriorityQueue<E> {
  final Comparator<E> comparison;
  final List<E> _queue = [];

  HeapPriorityQueue(this.comparison);

  void add(E value) {
    _queue.add(value);
    _siftUp(_queue.length - 1);
  }

  E removeFirst() {
    if (_queue.length == 1) return _queue.removeLast();
    final result = _queue[0];
    _queue[0] = _queue.removeLast();
    _siftDown(0);
    return result;
  }

  E get first => _queue[0];

  bool get isNotEmpty => _queue.isNotEmpty;
  int get length => _queue.length;

  void _siftUp(int index) {
    while (index > 0) {
      final parent = (index - 1) ~/ 2;
      if (comparison(_queue[index], _queue[parent]) >= 0) break;
      _swap(index, parent);
      index = parent;
    }
  }

  void _siftDown(int index) {
    while (true) {
      var smallest = index;
      final left = 2 * index + 1;
      final right = 2 * index + 2;
      if (left < _queue.length && comparison(_queue[left], _queue[smallest]) < 0) {
        smallest = left;
      }
      if (right < _queue.length && comparison(_queue[right], _queue[smallest]) < 0) {
        smallest = right;
      }
      if (smallest == index) break;
      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int i, int j) {
    final tmp = _queue[i];
    _queue[i] = _queue[j];
    _queue[j] = tmp;
  }
}

import 'dart:collection';
import '../../data/models/note.dart';
import '../../data/models/link.dart';
import '../../data/models/graph_stat.dart';

class GraphAlgorithm {
  final List<Note> allNotes;
  final List<Link> allLinks;

  late final Map<String, Set<String>> _adjacency;
  late final Set<String> _allNodeIds;

  GraphAlgorithm({
    this.allNotes = const [],
    this.allLinks = const [],
  }) {
    _allNodeIds = allNotes.map((n) => n.id).toSet();
    _adjacency = {};
    for (final link in allLinks) {
      _adjacency.putIfAbsent(link.sourceId, () => {}).add(link.targetId);
      _adjacency.putIfAbsent(link.targetId, () => {}).add(link.sourceId);
    }
    for (final note in allNotes) {
      _adjacency.putIfAbsent(note.id, () => {});
    }
  }

  List<String> shortestPath(String fromId, String toId) {
    if (fromId == toId && _adjacency.containsKey(fromId)) {
      return [fromId];
    }

    if (!_adjacency.containsKey(fromId) || !_adjacency.containsKey(toId)) {
      return [];
    }

    final visitedFrom = <String, String?>{fromId: null};
    final visitedTo = <String, String?>{toId: null};
    final queueFrom = Queue<String>()..add(fromId);
    final queueTo = Queue<String>()..add(toId);

    String? intersectionNode;

    while (queueFrom.isNotEmpty && queueTo.isNotEmpty) {
      intersectionNode = _bfsStep(queueFrom, visitedFrom, visitedTo);
      if (intersectionNode != null) break;

      intersectionNode = _bfsStep(queueTo, visitedTo, visitedFrom);
      if (intersectionNode != null) break;
    }

    if (intersectionNode == null) return [];

    return _reconstructPath(visitedFrom, visitedTo, intersectionNode);
  }

  String? _bfsStep(
    Queue<String> queue,
    Map<String, String?> visited,
    Map<String, String?> otherVisited,
  ) {
    if (queue.isEmpty) return null;
    final current = queue.removeFirst();
    for (final neighbor in _adjacency[current] ?? {}) {
      if (visited.containsKey(neighbor)) continue;
      visited[neighbor] = current;
      queue.add(neighbor);
      if (otherVisited.containsKey(neighbor)) {
        return neighbor;
      }
    }
    return null;
  }

  List<String> _reconstructPath(
    Map<String, String?> fromVisited,
    Map<String, String?> toVisited,
    String mid,
  ) {
    final path = <String>[];

    String? current = mid;
    while (current != null) {
      path.insert(0, current);
      current = fromVisited[current];
    }

    current = toVisited[mid];
    while (current != null) {
      path.add(current);
      current = toVisited[current];
    }

    return path;
  }

  Map<String, double> pageRank({
    int iterations = 50,
    double damping = 0.85,
  }) {
    final nodeList = allNotes.toList();
    if (nodeList.isEmpty) return {};

    final n = nodeList.length;
    final indexMap = <String, int>{};
    for (var i = 0; i < n; i++) {
      indexMap[nodeList[i].id] = i;
    }

    final outDegree = List<int>.filled(n, 0);
    final outLinks = List<Set<int>>.generate(n, (_) => {});

    for (final link in allLinks) {
      final si = indexMap[link.sourceId];
      final ti = indexMap[link.targetId];
      if (si != null && ti != null) {
        outLinks[si].add(ti);
      }
    }
    for (var i = 0; i < n; i++) {
      outDegree[i] = outLinks[i].length;
    }

    final rank = List<double>.filled(n, 1.0 / n);
    final newRank = List<double>.filled(n, 0.0);
    final dampedConst = (1.0 - damping) / n;

    for (var iter = 0; iter < iterations; iter++) {
      for (var i = 0; i < n; i++) {
        newRank[i] = dampedConst;
      }

      for (var i = 0; i < n; i++) {
        if (outDegree[i] == 0) {
          for (var j = 0; j < n; j++) {
            newRank[j] += damping * rank[i] / n;
          }
        } else {
          final share = damping * rank[i] / outDegree[i];
          for (final target in outLinks[i]) {
            newRank[target] += share;
          }
        }
      }

      for (var i = 0; i < n; i++) {
        rank[i] = newRank[i];
        newRank[i] = 0.0;
      }
    }

    final result = <String, double>{};
    for (var i = 0; i < n; i++) {
      result[nodeList[i].id] = rank[i];
    }
    return result;
  }

  ConnectedComponentsResult connectedComponents() {
    final visited = <String>{};
    final components = <Set<String>>{};

    for (final nodeId in _allNodeIds) {
      if (visited.contains(nodeId)) continue;

      final component = <String>{};
      final queue = Queue<String>()..add(nodeId);

      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        if (visited.contains(current)) continue;
        visited.add(current);
        component.add(current);

        for (final neighbor in _adjacency[current] ?? {}) {
          if (!visited.contains(neighbor)) {
            queue.add(neighbor);
          }
        }
      }

      components.add(component);
    }

    int maxComponentSize = 0;
    for (final c in components) {
      if (c.length > maxComponentSize) maxComponentSize = c.length;
    }

    return ConnectedComponentsResult(
      componentCount: components.length,
      maxComponentSize: maxComponentSize,
      components: components,
    );
  }

  List<BridgeNode> getBridgeNodes() {
    final visited = <String, bool>{};
    final discovery = <String, int>{};
    final low = <String, int>{};
    final parent = <String, String?>{};
    final bridgeSet = <String>{};

    var time = 0;

    void dfs(String u) {
      visited[u] = true;
      discovery[u] = time;
      low[u] = time;
      time++;

      for (final v in _adjacency[u] ?? {}) {
        if (visited[v] != true) {
          parent[v] = u;
          dfs(v);
          low[u] = min(low[u]!, low[v]!);

          if (low[v]! > discovery[u]!) {
            bridgeSet.add(u);
            bridgeSet.add(v);
          }
        } else if (v != parent[u]) {
          low[u] = min(low[u]!, discovery[v]!);
        }
      }
    }

    for (final nodeId in _allNodeIds) {
      if (visited[nodeId] != true) {
        dfs(nodeId);
      }
    }

    final noteMap = {for (final n in allNotes) n.id: n};
    return bridgeSet.map((id) {
      return BridgeNode(
        noteId: id,
        noteTitle: noteMap[id]?.title,
        incidentEdgeCount: (_adjacency[id] ?? {}).length,
      );
    }).toList();
  }

  GraphStats getGraphStats() {
    final totalNodes = _allNodeIds.length;
    final totalEdges = allLinks.length;
    final avgDegree = totalNodes > 0
        ? (allLinks.length * 2) / totalNodes
        : 0.0;

    final cc = connectedComponents();

    return GraphStats(
      totalNodes: totalNodes,
      totalEdges: totalEdges,
      avgDegree: avgDegree,
      componentCount: cc.componentCount,
      maxComponentSize: cc.maxComponentSize,
    );
  }

  int min(int a, int b) => a < b ? a : b;
}

class ConnectedComponentsResult {
  final int componentCount;
  final int maxComponentSize;
  final Set<Set<String>> components;

  ConnectedComponentsResult({
    required this.componentCount,
    required this.maxComponentSize,
    required this.components,
  });
}

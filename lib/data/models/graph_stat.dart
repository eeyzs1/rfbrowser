class BridgeNode {
  final String noteId;
  final String? noteTitle;
  final int incidentEdgeCount;

  BridgeNode({
    required this.noteId,
    this.noteTitle,
    this.incidentEdgeCount = 0,
  });
}

class GraphStats {
  final int totalNodes;
  final int totalEdges;
  final double avgDegree;
  final int componentCount;
  final int maxComponentSize;

  GraphStats({
    required this.totalNodes,
    required this.totalEdges,
    required this.avgDegree,
    required this.componentCount,
    required this.maxComponentSize,
  });
}

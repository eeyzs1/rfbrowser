part of '../graph_page.dart';

/// Mixin providing graph layout computation and local-graph helpers.
mixin _GraphLayoutMixin on _GraphViewStateBase {
  @override
  int _countLinks(List<GraphLink> links, String noteId) {
    return links
        .where((l) => l.sourceId == noteId || l.targetId == noteId)
        .length;
  }

  @override
  LocalGraphResult? _computeLocalGraph(KnowledgeState knowledgeState) {
    return ref
        .read(knowledgeProvider.notifier)
        .getLocalGraph(_localGraphCenter!, depth: _localGraphDepth);
  }

  @override
  Map<String, Offset>? _computeLayout(List<Note> notes, List<GraphLink> links) {
    if (notes.isEmpty) return null;

    if (_layoutMode == GraphLayoutMode.circular) {
      final positions = <String, Offset>{};
      for (var i = 0; i < notes.length; i++) {
        final angle = (i / notes.length) * 2 * pi;
        final radius = 80.0 * (1 + (i % 3) * 0.5);
        positions[notes[i].id] = Offset(
          radius * cos(angle),
          radius * sin(angle),
        );
      }
      return positions;
    }

    final linkCounts = <String, int>{};
    for (final l in links) {
      final key = '${l.sourceId}->${l.targetId}';
      linkCounts[key] = (linkCounts[key] ?? 0) + 1;
    }

    final layoutNodes = notes.map((n) => LayoutNode(id: n.id)).toList();
    final layoutEdges = links.map((l) {
      final key = '${l.sourceId}->${l.targetId}';
      final weight = linkCounts[key]?.toDouble() ?? 1.0;
      return LayoutEdge(
        sourceId: l.sourceId,
        targetId: l.targetId,
        weight: weight,
      );
    }).toList();

    final layout = ForceDirectedLayout.adaptive(notes.length, seed: 42);
    final result = layout.compute(layoutNodes, layoutEdges);
    return result.positions;
  }
}

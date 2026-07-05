part of '../graph_page.dart';

/// Top-level isolate entry point for force-directed layout computation.
///
/// Reconstructs [ForceDirectedLayout] from primitive serializable data and
/// runs the full O(n²×iterations) computation off the UI thread (Rule 6.1).
/// Returns node positions as a `Map<String, List<double>>` (id → [x, y]) so
/// the message only carries primitive types across the isolate boundary.
Map<String, List<double>> _computeForceDirectedLayout(
  Map<String, dynamic> input,
) {
  final nodeIds = (input['nodeIds'] as List).cast<String>();
  final rawEdges = (input['edges'] as List).cast<List<dynamic>>();
  final areaWidth = input['areaWidth'] as double;
  final areaHeight = input['areaHeight'] as double;
  final idealEdgeLength = input['idealEdgeLength'] as double;
  final coolingFactor = input['coolingFactor'] as double;
  final maxIterations = input['maxIterations'] as int;
  final seed = input['seed'] as int?;

  final layoutNodes = nodeIds.map((id) => LayoutNode(id: id)).toList();
  final layoutEdges = rawEdges.map((e) {
    return LayoutEdge(
      sourceId: e[0] as String,
      targetId: e[1] as String,
      weight: (e[2] as num).toDouble(),
    );
  }).toList();

  final layout = ForceDirectedLayout(
    areaWidth: areaWidth,
    areaHeight: areaHeight,
    idealEdgeLength: idealEdgeLength,
    coolingFactor: coolingFactor,
    maxIterations: maxIterations,
    seed: seed,
  );
  final result = layout.compute(layoutNodes, layoutEdges);

  return result.positions.map(
    (id, offset) => MapEntry(id, <double>[offset.dx, offset.dy]),
  );
}

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
  Future<Map<String, Offset>?> _computeLayout(
    List<Note> notes,
    List<GraphLink> links,
  ) async {
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

    final layoutEngine = ForceDirectedLayout.adaptive(notes.length, seed: 42);

    // Large graphs: run in a worker isolate to avoid blocking the UI thread.
    // 500 nodes × 200 iterations × O(n²) repulsion ≈ 25M ops (~2-5s).
    if (notes.length > 50) {
      final input = <String, dynamic>{
        'nodeIds': notes.map((n) => n.id).toList(),
        'edges': links.map((l) {
          final key = '${l.sourceId}->${l.targetId}';
          return <dynamic>[
            l.sourceId,
            l.targetId,
            linkCounts[key]?.toDouble() ?? 1.0,
          ];
        }).toList(),
        'areaWidth': layoutEngine.areaWidth,
        'areaHeight': layoutEngine.areaHeight,
        'idealEdgeLength': layoutEngine.idealEdgeLength,
        'coolingFactor': layoutEngine.coolingFactor,
        'maxIterations': layoutEngine.maxIterations,
        'seed': layoutEngine.seed,
      };
      final positions = await compute(_computeForceDirectedLayout, input);
      return positions.map((id, xy) => MapEntry(id, Offset(xy[0], xy[1])));
    }

    // Small graphs (≤50 nodes): synchronous, fast enough.
    final layoutNodes = notes.map((n) => LayoutNode(id: n.id)).toList();
    final layoutEdges = links.map((l) {
      final key = '${l.sourceId}->${l.targetId}';
      return LayoutEdge(
        sourceId: l.sourceId,
        targetId: l.targetId,
        weight: linkCounts[key]?.toDouble() ?? 1.0,
      );
    }).toList();
    final result = layoutEngine.compute(layoutNodes, layoutEdges);
    return result.positions;
  }
}

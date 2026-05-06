import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/knowledge_service.dart';
import '../../data/models/note.dart';
import '../../data/models/link.dart';
import '../../core/graph/layout_engine.dart';
import '../../core/graph/filter_engine.dart';
import '../../core/graph/graph_algorithm.dart';
import '../widgets/graph_stats_card.dart';

enum GraphLayoutMode { circular, forceDirected }
enum GraphViewMode { full, local }

class GraphView extends ConsumerStatefulWidget {
  const GraphView({super.key});

  @override
  ConsumerState<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends ConsumerState<GraphView> {
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  String? _hoveredNode;
  String? _selectedNode;
  final _graphKey = GlobalKey();
  GraphLayoutMode _layoutMode = GraphLayoutMode.forceDirected;
  GraphViewMode _viewMode = GraphViewMode.full;
  String? _localGraphCenter;
  int _localGraphDepth = 2;
  Map<String, Offset>? _cachedLayout;
  String? _cachedLayoutKey;
  bool _showStats = false;

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final theme = Theme.of(context);
    final notes = knowledgeState.notes;

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.hub,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text('Knowledge Graph', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Create notes with [[links]] to see connections',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final allLinks = <GraphLink>[];
    final allDataLinks = <Link>[];
    final seenLinks = <String>{};
    for (final link in knowledgeState.outlinks) {
      final key = '${link.sourceId}->${link.targetId}';
      if (!seenLinks.contains(key)) {
        seenLinks.add(key);
        allLinks.add(
          GraphLink(sourceId: link.sourceId, targetId: link.targetId),
        );
        allDataLinks.add(link);
      }
    }
    for (final link in knowledgeState.backlinks) {
      final key = '${link.sourceId}->${link.targetId}';
      if (!seenLinks.contains(key)) {
        seenLinks.add(key);
        allLinks.add(
          GraphLink(sourceId: link.sourceId, targetId: link.targetId),
        );
        allDataLinks.add(link);
      }
    }

    List<Note> displayNotes = notes;
    List<GraphLink> displayLinks = allLinks;
    List<Link> displayDataLinks = allDataLinks;

    if (_viewMode == GraphViewMode.local && _localGraphCenter != null) {
      final localResult = knowledgeState.notes.isNotEmpty
          ? _computeLocalGraph(knowledgeState)
          : null;
      if (localResult != null) {
        final localIds = localResult.notes.map((n) => n.id).toSet();
        displayNotes = localResult.notes;
        displayLinks = allLinks
            .where(
              (l) =>
                  localIds.contains(l.sourceId) &&
                  localIds.contains(l.targetId),
            )
            .toList();
        displayDataLinks = allDataLinks
            .where(
              (l) =>
                  localIds.contains(l.sourceId) &&
                  localIds.contains(l.targetId),
            )
            .toList();
      }
    }

    final algorithm = GraphAlgorithm(
      allNotes: displayNotes,
      allLinks: displayDataLinks,
    );
    final bridgeNodes = algorithm.getBridgeNodes();
    final bridgeIds = bridgeNodes.map((b) => b.noteId).toSet();
    final graphStats = algorithm.getGraphStats();

    final layoutKey = '${displayNotes.map((n) => n.id).join(",")}|${displayLinks.map((l) => '${l.sourceId}->${l.targetId}').join(",")}|$_layoutMode';
    if (_cachedLayoutKey != layoutKey) {
      _cachedLayout = _computeLayout(displayNotes, displayLinks);
      _cachedLayoutKey = layoutKey;
    }

    return Container(
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          GestureDetector(
            onScaleUpdate: (details) {
              setState(() {
                _scale = (_scale * details.scale).clamp(0.3, 3.0);
                _offset += details.focalPointDelta;
              });
            },
            onTapUp: (details) {
              final size =
                  (_graphKey.currentContext?.findRenderObject() as RenderBox?)
                      ?.size ??
                  Size.zero;
              final nodeRadius = 6.0 * _scale;
              final layout = _cachedLayout;

              String? tappedNoteId;
              if (layout != null) {
                for (final entry in layout.entries) {
                  final pos = Offset(
                    entry.value.dx * _scale + size.width / 2 + _offset.dx,
                    entry.value.dy * _scale + size.height / 2 + _offset.dy,
                  );
                  final dist = (pos - details.localPosition).distance;
                  if (dist < nodeRadius * 3) {
                    tappedNoteId = entry.key;
                    break;
                  }
                }
              }

              if (tappedNoteId != null) {
                final note = displayNotes.where((n) => n.id == tappedNoteId).firstOrNull;
                if (note != null) {
                  ref.read(knowledgeProvider.notifier).openNote(note.filePath);
                }
              }
            },
            child: CustomPaint(
              key: _graphKey,
              painter: GraphPainter(
                notes: displayNotes,
                links: displayLinks,
                scale: _scale,
                offset: _offset,
                layout: _cachedLayout,
                hoveredNode: _hoveredNode,
                selectedNode: _selectedNode,
                bridgeIds: bridgeIds,
                primaryColor: theme.colorScheme.primary,
                secondaryColor: theme.colorScheme.secondary,
                surfaceColor: theme.colorScheme.surface,
                onSurfaceColor: theme.colorScheme.onSurface,
                hintColor: theme.hintColor,
                cardColor: theme.cardColor,
              ),
              size: Size.infinite,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hub, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${displayNotes.length} notes',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _layoutMode == GraphLayoutMode.forceDirected
                          ? Icons.scatter_plot
                          : Icons.circle,
                      size: 14,
                    ),
                    onPressed: () => setState(() {
                      _layoutMode =
                          _layoutMode == GraphLayoutMode.forceDirected
                              ? GraphLayoutMode.circular
                              : GraphLayoutMode.forceDirected;
                      _cachedLayoutKey = null;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: _layoutMode == GraphLayoutMode.forceDirected
                        ? 'Switch to circular'
                        : 'Switch to force-directed',
                  ),
                  IconButton(
                    icon: Icon(
                      _viewMode == GraphViewMode.full
                          ? Icons.account_tree
                          : Icons.hub,
                      size: 14,
                    ),
                    onPressed: () => setState(() {
                      _viewMode = _viewMode == GraphViewMode.full
                          ? GraphViewMode.local
                          : GraphViewMode.full;
                      if (_viewMode == GraphViewMode.local && _localGraphCenter == null) {
                        _localGraphCenter = knowledgeState.activeNote?.id ?? notes.first.id;
                      }
                      _cachedLayoutKey = null;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: _viewMode == GraphViewMode.full
                        ? 'Local graph'
                        : 'Full graph',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      _showStats ? Icons.analytics : Icons.analytics_outlined,
                      size: 16,
                    ),
                    onPressed: () => setState(() => _showStats = !_showStats),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Toggle statistics',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, size: 16),
                    onPressed: () =>
                        setState(() => _scale = (_scale * 1.2).clamp(0.3, 3.0)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, size: 16),
                    onPressed: () =>
                        setState(() => _scale = (_scale / 1.2).clamp(0.3, 3.0)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                  IconButton(
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    onPressed: () => setState(() {
                      _offset = Offset.zero;
                      _scale = 1.0;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
          ),
          if (_showStats)
            Positioned(
              top: 60,
              right: 12,
              child: GraphStatsCard(stats: graphStats),
            ),
          if (_viewMode == GraphViewMode.local)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Depth: ', style: theme.textTheme.bodySmall),
                    Slider(
                      value: _localGraphDepth.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_localGraphDepth',
                      onChanged: (v) => setState(() {
                        _localGraphDepth = v.toInt();
                        _cachedLayoutKey = null;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          if (bridgeNodes.isNotEmpty)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    Text(
                      '${bridgeNodes.length} bridge nodes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  LocalGraphResult? _computeLocalGraph(KnowledgeState knowledgeState) {
    return ref.read(knowledgeProvider.notifier).getLocalGraph(
      _localGraphCenter!,
      depth: _localGraphDepth,
    );
  }

  Map<String, Offset>? _computeLayout(
    List<Note> notes,
    List<GraphLink> links,
  ) {
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

    final layoutNodes = notes
        .map((n) => LayoutNode(id: n.id))
        .toList();
    final layoutEdges = links
        .map((l) => LayoutEdge(sourceId: l.sourceId, targetId: l.targetId))
        .toList();

    final layout = ForceDirectedLayout(
      areaWidth: 800,
      areaHeight: 600,
      idealEdgeLength: 120,
      seed: 42,
    );
    final result = layout.compute(layoutNodes, layoutEdges);
    return result.positions;
  }
}

class GraphLink {
  final String sourceId;
  final String targetId;
  GraphLink({required this.sourceId, required this.targetId});
}

class GraphPainter extends CustomPainter {
  final List<Note> notes;
  final List<GraphLink> links;
  final double scale;
  final Offset offset;
  final Map<String, Offset>? layout;
  final String? hoveredNode;
  final String? selectedNode;
  final Set<String> bridgeIds;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;
  final Color hintColor;
  final Color cardColor;

  GraphPainter({
    required this.notes,
    required this.links,
    required this.scale,
    required this.offset,
    this.layout,
    this.hoveredNode,
    this.selectedNode,
    this.bridgeIds = const {},
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
    required this.hintColor,
    required this.cardColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty) return;

    final centerX = size.width / 2 + offset.dx;
    final centerY = size.height / 2 + offset.dy;
    final nodePositions = <String, Offset>{};
    final nodeRadius = 6.0 * scale;

    final linkCount = <String, int>{};
    for (final link in links) {
      linkCount[link.sourceId] = (linkCount[link.sourceId] ?? 0) + 1;
      linkCount[link.targetId] = (linkCount[link.targetId] ?? 0) + 1;
    }

    if (layout != null) {
      for (final entry in layout!.entries) {
        nodePositions[entry.key] = Offset(
          entry.value.dx * scale + centerX,
          entry.value.dy * scale + centerY,
        );
      }
    } else {
      final spacing = 80.0 * scale;
      for (var i = 0; i < notes.length; i++) {
        final angle = (i / notes.length) * 2 * pi;
        final radius = spacing * (1 + (i % 3) * 0.5);
        final x = centerX + radius * cos(angle);
        final y = centerY + radius * sin(angle);
        nodePositions[notes[i].id] = Offset(x, y);
      }
    }

    final edgePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..strokeWidth = 1.0 * scale
      ..style = PaintingStyle.stroke;

    for (final link in links) {
      final sourcePos = nodePositions[link.sourceId];
      final targetPos = nodePositions[link.targetId];
      if (sourcePos != null && targetPos != null) {
        canvas.drawLine(sourcePos, targetPos, edgePaint);
      }
    }

    final redColor = Colors.red.shade400;

    for (final note in notes) {
      final pos = nodePositions[note.id];
      if (pos == null) continue;

      final connections = linkCount[note.id] ?? 0;
      final r = (nodeRadius + connections * 1.5).clamp(
        nodeRadius,
        nodeRadius * 3,
      );
      final isHovered = hoveredNode == note.id;
      final isSelected = selectedNode == note.id;
      final isBridge = bridgeIds.contains(note.id);

      final nodePaint = Paint()
        ..color = isBridge
            ? redColor
            : isSelected
            ? primaryColor
            : isHovered
            ? secondaryColor
            : primaryColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;

      final bridgePaint = Paint()
        ..color = redColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;

      if (isBridge) {
        canvas.drawCircle(pos, r * 1.8, bridgePaint);
      } else if (connections > 2) {
        canvas.drawCircle(pos, r * 2, glowPaint);
      }
      canvas.drawCircle(pos, r, nodePaint);

      if (isBridge && scale > 0.4) {
        final starSpan = TextSpan(
          text: '\u2605',
          style: TextStyle(
            color: redColor,
            fontSize: (12 * scale).clamp(8, 16),
          ),
        );
        final starPainter = TextPainter(
          text: starSpan,
          textDirection: TextDirection.ltr,
        );
        starPainter.layout();
        starPainter.paint(
          canvas,
          Offset(pos.dx - starPainter.width / 2, pos.dy - r - starPainter.height),
        );
      }

      if (scale > 0.5) {
        final textSpan = TextSpan(
          text: note.title,
          style: TextStyle(
            color: isSelected
                ? primaryColor
                : isBridge
                ? redColor
                : onSurfaceColor.withValues(alpha: 0.8),
            fontSize: (10 * scale).clamp(8, 14),
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout(maxWidth: 100 * scale);
        textPainter.paint(
          canvas,
          Offset(pos.dx - textPainter.width / 2, pos.dy + r + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) =>
      oldDelegate.notes != notes ||
      oldDelegate.links != links ||
      oldDelegate.scale != scale ||
      oldDelegate.offset != offset ||
      oldDelegate.layout != layout ||
      oldDelegate.hoveredNode != hoveredNode ||
      oldDelegate.selectedNode != selectedNode ||
      oldDelegate.bridgeIds != bridgeIds;
}

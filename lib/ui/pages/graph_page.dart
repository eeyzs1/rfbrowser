import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/knowledge_service.dart';
import '../../data/models/note.dart';
import '../../data/models/link.dart';

class GraphView extends ConsumerStatefulWidget {
  const GraphView({super.key});

  @override
  ConsumerState<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends ConsumerState<GraphView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  String? _hoveredNode;
  String? _selectedNode;
  final _graphKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final theme = Theme.of(context);
    final notes = knowledgeState.notes;
    final backlinks = knowledgeState.backlinks;

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
            child: CustomPaint(
              key: _graphKey,
              painter: GraphPainter(
                notes: notes,
                links: _buildLinks(notes, backlinks),
                scale: _scale,
                offset: _offset,
                hoveredNode: _hoveredNode,
                selectedNode: _selectedNode,
                primaryColor: theme.colorScheme.primary,
                secondaryColor: theme.colorScheme.secondary,
                surfaceColor: theme.colorScheme.surface,
                onSurfaceColor: theme.colorScheme.onSurface,
                hintColor: theme.hintColor,
                cardColor: theme.cardColor,
                animation: _controller,
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
                    '${notes.length} notes',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, size: 16),
                    onPressed: () =>
                        setState(() => _scale = (_scale * 1.2).clamp(0.3, 3.0)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, size: 16),
                    onPressed: () =>
                        setState(() => _scale = (_scale / 1.2).clamp(0.3, 3.0)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    onPressed: () => setState(() {
                      _offset = Offset.zero;
                      _scale = 1.0;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
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

  List<GraphLink> _buildLinks(List<Note> notes, List<Link> backlinks) {
    final links = <GraphLink>[];
    final noteMap = {for (var n in notes) n.id: n};
    for (final link in backlinks) {
      final source = noteMap[link.sourceId];
      final target = noteMap[link.targetId];
      if (source != null && target != null) {
        links.add(GraphLink(sourceId: source.id, targetId: target.id));
      }
    }
    return links;
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
  final String? hoveredNode;
  final String? selectedNode;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;
  final Color hintColor;
  final Color cardColor;
  final Animation<double> animation;

  GraphPainter({
    required this.notes,
    required this.links,
    required this.scale,
    required this.offset,
    this.hoveredNode,
    this.selectedNode,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
    required this.hintColor,
    required this.cardColor,
    required this.animation,
  }) : super(repaint: animation);

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

    final spacing = 80.0 * scale;
    for (var i = 0; i < notes.length; i++) {
      final angle = (i / notes.length) * 2 * pi + animation.value * 0.01;
      final radius = spacing * (1 + (i % 3) * 0.5);
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      nodePositions[notes[i].id] = Offset(x, y);
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

      final nodePaint = Paint()
        ..color = isSelected
            ? primaryColor
            : isHovered
            ? secondaryColor
            : primaryColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;

      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;

      if (connections > 2) {
        canvas.drawCircle(pos, r * 2, glowPaint);
      }
      canvas.drawCircle(pos, r, nodePaint);

      if (scale > 0.5) {
        final textSpan = TextSpan(
          text: note.title,
          style: TextStyle(
            color: isSelected
                ? primaryColor
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
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}

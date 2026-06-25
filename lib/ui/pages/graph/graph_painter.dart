// ignore_for_file: unused_element, unused_element_parameter

part of '../graph_page.dart';

class GraphLink {
  final String sourceId;
  final String targetId;
  final bool isAuto;
  GraphLink({
    required this.sourceId,
    required this.targetId,
    this.isAuto = false,
  });
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
  final Color errorColor;
  final double baseFontSize;

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
    required this.errorColor,
    this.baseFontSize = 10.0,
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

    final autoEdgePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.2 * scale
      ..style = PaintingStyle.stroke;

    for (final link in links) {
      final sourcePos = nodePositions[link.sourceId];
      final targetPos = nodePositions[link.targetId];
      if (sourcePos == null || targetPos == null) continue;
      if (link.isAuto) {
        // A-6: auto-discovered wikilinks are rendered as dashed lines
        _drawDashedLine(
          canvas,
          sourcePos,
          targetPos,
          autoEdgePaint,
          dash: 6.0,
          gap: 4.0,
        );
      } else {
        canvas.drawLine(sourcePos, targetPos, edgePaint);
      }
    }

    final redColor = errorColor;

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

      if (isHovered) {
        final hoverPaint = Paint()
          ..color = secondaryColor.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          pos,
          _GraphViewStateBase._nodeHitRadius * scale,
          hoverPaint,
        );
      }

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
            fontSize: (baseFontSize * 1.2 * scale).clamp(8, 16),
          ),
        );
        final starPainter = TextPainter(
          text: starSpan,
          textDirection: TextDirection.ltr,
        );
        starPainter.layout();
        starPainter.paint(
          canvas,
          Offset(
            pos.dx - starPainter.width / 2,
            pos.dy - r - starPainter.height,
          ),
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
            fontSize: (baseFontSize * scale).clamp(8, 14),
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

  /// Draws a straight line between [a] and [b] as a dashed pattern.
  /// Used for A-6: auto-discovered [[wikilink]] edges in the graph.
  void _drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double dash = 6.0,
    double gap = 4.0,
  }) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        if (draw) {
          final end = (dist + dash).clamp(0.0, metric.length);
          if (end > dist) {
            canvas.drawPath(metric.extractPath(dist, end), paint);
          }
          dist = end;
        } else {
          dist += gap;
        }
        draw = !draw;
      }
    }
  }
}

/// Tiny painter used by [_GraphLegend] to draw a dashed line sample,
/// matching the auto-discovered [[wikilink]] edge style (A-6).
class _DashedLineLegendPainter extends CustomPainter {
  final Color color;
  _DashedLineLegendPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    double x = 0;
    bool draw = true;
    while (x < size.width) {
      if (draw) {
        final end = (x + 4).clamp(0.0, size.width);
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(end, size.height / 2),
          paint,
        );
        x = end;
      } else {
        x += 3;
      }
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLineLegendPainter oldDelegate) =>
      oldDelegate.color != color;
}

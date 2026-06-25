part of '../canvas_painter.dart';

/// Path-building and arrow-head drawing helpers for connection rendering.
mixin _CanvasConnectionPathMixin on _CanvasPainterBase {
  @override
  Path _buildOrthogonalPath(
    Offset fp,
    Offset tp,
    ConnectionSide fromSide,
    ConnectionSide toSide, [
    List<Offset> waypoints = const [],
  ]) {
    final path = Path()..moveTo(fp.dx, fp.dy);

    if (waypoints.isNotEmpty) {
      for (final wp in waypoints) {
        final swp = _w2s(wp.dx, wp.dy);
        final midX = (path.getBounds().right + swp.dx) / 2;
        path.lineTo(midX, path.getBounds().bottom);
        path.lineTo(midX, swp.dy);
        path.lineTo(swp.dx, swp.dy);
      }
      final midX = (path.getBounds().right + tp.dx) / 2;
      path.lineTo(midX, path.getBounds().bottom);
      path.lineTo(midX, tp.dy);
      path.lineTo(tp.dx, tp.dy);
      return path;
    }

    final midX = (fp.dx + tp.dx) / 2;
    final midY = (fp.dy + tp.dy) / 2;

    Offset p1, p2;
    switch (fromSide) {
      case ConnectionSide.right:
        p1 = Offset(midX, fp.dy);
      case ConnectionSide.left:
        p1 = Offset(midX, fp.dy);
      case ConnectionSide.bottom:
        p1 = Offset(fp.dx, midY);
      case ConnectionSide.top:
        p1 = Offset(fp.dx, midY);
    }
    switch (toSide) {
      case ConnectionSide.left:
        p2 = Offset(midX, tp.dy);
      case ConnectionSide.right:
        p2 = Offset(midX, tp.dy);
      case ConnectionSide.top:
        p2 = Offset(tp.dx, midY);
      case ConnectionSide.bottom:
        p2 = Offset(tp.dx, midY);
    }

    path.lineTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(tp.dx, tp.dy);
    return path;
  }

  @override
  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap, [
    double offset = 0,
  ]) {
    for (final metric in path.computeMetrics()) {
      double dist = offset % (dash + gap);
      bool draw = dist < dash;
      while (dist < metric.length) {
        if (draw) {
          final start = dist.clamp(0.0, metric.length);
          final end = (dist + dash).clamp(0.0, metric.length);
          if (end > start) {
            canvas.drawPath(metric.extractPath(start, end), paint);
          }
          dist = end;
        } else {
          dist += gap;
        }
        draw = !draw;
      }
    }
  }

  @override
  void _drawArrowHead(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    ArrowStyle style, [
    double arrowSize = 8.0,
  ]) {
    if (style == ArrowStyle.none) return;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final len = arrowSize * scale;
    const a = math.pi / 6;
    final p1 = Offset(
      to.dx - len * math.cos(angle - a),
      to.dy - len * math.sin(angle - a),
    );
    final p2 = Offset(
      to.dx - len * math.cos(angle + a),
      to.dy - len * math.sin(angle + a),
    );

    switch (style) {
      case ArrowStyle.none:
        break;
      case ArrowStyle.triangle:
        final path = Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case ArrowStyle.filledTriangle:
        final path = Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      case ArrowStyle.diamond:
        final mid = Offset((to.dx + p1.dx) / 2, (to.dy + p1.dy) / 2);
        final mid2 = Offset((to.dx + p2.dx) / 2, (to.dy + p2.dy) / 2);
        final back = Offset(
          to.dx - len * 0.8 * math.cos(angle),
          to.dy - len * 0.8 * math.sin(angle),
        );
        final path = Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(back.dx, back.dy)
          ..lineTo(mid2.dx, mid2.dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      case ArrowStyle.circle:
        canvas.drawCircle(
          Offset(
            to.dx - len * 0.4 * math.cos(angle),
            to.dy - len * 0.4 * math.sin(angle),
          ),
          len * 0.35,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
    }
  }
}

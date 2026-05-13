part of '../canvas_painter.dart';

mixin CanvasOverlayPainterMixin on _CanvasPainterBase {
    void _drawAlignmentGuides(Canvas canvas) {
      if (alignmentGuides.isEmpty) return;
      final guidePaint = Paint()
        ..color = const Color(0xFF3B82F6).withValues(alpha: 0.6)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      for (final guide in alignmentGuides) {
        final start = _w2s(guide.start.dx, guide.start.dy);
        final end = _w2s(guide.end.dx, guide.end.dy);
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);
        _drawDashedPath(canvas, path, guidePaint, 4.0, 3.0);
      }
    }

    void _drawSelectionRect(Canvas canvas) {
      if (selectionRect == null) return;
      final screenRect = Rect.fromLTRB(
        _w2s(selectionRect!.left, 0).dx,
        _w2s(0, selectionRect!.top).dy,
        _w2s(selectionRect!.right, 0).dx,
        _w2s(0, selectionRect!.bottom).dy,
      );
      canvas.drawRect(
        screenRect,
        Paint()
          ..color = const Color(0xFF3B82F6).withValues(alpha: 0.1)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        screenRect,
        Paint()
          ..color = const Color(0xFF3B82F6).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    void _drawCardTypeIcon(
      Canvas canvas,
      CanvasCardType type,
      Offset pos,
      double size,
      Paint paint,
    ) {
      final path = switch (type) {
        CanvasCardType.note =>
          Path()
            ..moveTo(pos.dx + size * 0.2, pos.dy)
            ..lineTo(pos.dx + size * 0.7, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size * 0.3)
            ..lineTo(pos.dx + size, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size)
            ..close(),
        CanvasCardType.text =>
          Path()
            ..moveTo(pos.dx + size * 0.1, pos.dy + size * 0.2)
            ..lineTo(pos.dx + size * 0.9, pos.dy + size * 0.2)
            ..moveTo(pos.dx + size * 0.1, pos.dy + size * 0.5)
            ..lineTo(pos.dx + size * 0.9, pos.dy + size * 0.5)
            ..moveTo(pos.dx + size * 0.1, pos.dy + size * 0.8)
            ..lineTo(pos.dx + size * 0.6, pos.dy + size * 0.8),
        CanvasCardType.image =>
          Path()
            ..moveTo(pos.dx, pos.dy)
            ..lineTo(pos.dx + size, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size)
            ..close()
            ..moveTo(pos.dx + size * 0.2, pos.dy + size * 0.6)
            ..lineTo(pos.dx + size * 0.4, pos.dy + size * 0.35)
            ..lineTo(pos.dx + size * 0.6, pos.dy + size * 0.55)
            ..lineTo(pos.dx + size * 0.75, pos.dy + size * 0.4)
            ..lineTo(pos.dx + size * 0.9, pos.dy + size * 0.6),
        CanvasCardType.link =>
          Path()
            ..moveTo(pos.dx + size * 0.4, pos.dy + size * 0.4)
            ..lineTo(pos.dx + size * 0.6, pos.dy + size * 0.4)
            ..moveTo(pos.dx + size * 0.6, pos.dy + size * 0.6)
            ..lineTo(pos.dx + size * 0.4, pos.dy + size * 0.6),
        CanvasCardType.container =>
          Path()
            ..moveTo(pos.dx, pos.dy)
            ..lineTo(pos.dx + size, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size)
            ..close()
            ..moveTo(pos.dx, pos.dy + size * 0.3)
            ..lineTo(pos.dx + size, pos.dy + size * 0.3),
        CanvasCardType.rectangle =>
          Path()
            ..moveTo(pos.dx, pos.dy)
            ..lineTo(pos.dx + size, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size)
            ..close(),
        CanvasCardType.roundedRect =>
          Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(pos.dx, pos.dy, size, size),
              Radius.circular(size * 0.2),
            ),
          ),
        CanvasCardType.ellipse =>
          Path()..addOval(Rect.fromLTWH(pos.dx, pos.dy, size, size)),
        CanvasCardType.diamond =>
          Path()
            ..moveTo(pos.dx + size / 2, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size / 2)
            ..lineTo(pos.dx + size / 2, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size / 2)
            ..close(),
        CanvasCardType.hexagon =>
          Path()
            ..moveTo(pos.dx + size * 0.25, pos.dy)
            ..lineTo(pos.dx + size * 0.75, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size / 2)
            ..lineTo(pos.dx + size * 0.75, pos.dy + size)
            ..lineTo(pos.dx + size * 0.25, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size / 2)
            ..close(),
        CanvasCardType.parallelogram =>
          Path()
            ..moveTo(pos.dx + size * 0.2, pos.dy)
            ..lineTo(pos.dx + size, pos.dy)
            ..lineTo(pos.dx + size * 0.8, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size)
            ..close(),
        CanvasCardType.triangle =>
          Path()
            ..moveTo(pos.dx + size / 2, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size)
            ..close(),
        CanvasCardType.cylinder =>
          Path()
            ..moveTo(pos.dx, pos.dy + size * 0.15)
            ..addOval(Rect.fromLTWH(pos.dx, pos.dy, size, size * 0.3))
            ..moveTo(pos.dx, pos.dy + size * 0.15)
            ..lineTo(pos.dx, pos.dy + size * 0.85)
            ..moveTo(pos.dx + size, pos.dy + size * 0.15)
            ..lineTo(pos.dx + size, pos.dy + size * 0.85)
            ..addOval(
              Rect.fromLTWH(pos.dx, pos.dy + size * 0.7, size, size * 0.3),
            ),
        CanvasCardType.star =>
          Path()
            ..moveTo(pos.dx + size * 0.5, pos.dy)
            ..lineTo(pos.dx + size * 0.62, pos.dy + size * 0.35)
            ..lineTo(pos.dx + size, pos.dy + size * 0.35)
            ..lineTo(pos.dx + size * 0.7, pos.dy + size * 0.58)
            ..lineTo(pos.dx + size * 0.8, pos.dy + size)
            ..lineTo(pos.dx + size * 0.5, pos.dy + size * 0.72)
            ..lineTo(pos.dx + size * 0.2, pos.dy + size)
            ..lineTo(pos.dx + size * 0.3, pos.dy + size * 0.58)
            ..lineTo(pos.dx, pos.dy + size * 0.35)
            ..lineTo(pos.dx + size * 0.38, pos.dy + size * 0.35)
            ..close(),
        CanvasCardType.swimlaneH || CanvasCardType.swimlaneV =>
          Path()
            ..moveTo(pos.dx, pos.dy)
            ..lineTo(pos.dx + size, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size)
            ..close()
            ..moveTo(pos.dx, pos.dy + size * 0.25)
            ..lineTo(pos.dx + size, pos.dy + size * 0.25),
        CanvasCardType.table =>
          Path()
            ..moveTo(pos.dx, pos.dy)
            ..lineTo(pos.dx + size, pos.dy)
            ..lineTo(pos.dx + size, pos.dy + size)
            ..lineTo(pos.dx, pos.dy + size)
            ..close()
            ..moveTo(pos.dx, pos.dy + size * 0.3)
            ..lineTo(pos.dx + size, pos.dy + size * 0.3)
            ..moveTo(pos.dx + size * 0.33, pos.dy + size * 0.3)
            ..lineTo(pos.dx + size * 0.33, pos.dy + size)
            ..moveTo(pos.dx + size * 0.66, pos.dy + size * 0.3)
            ..lineTo(pos.dx + size * 0.66, pos.dy + size),
        CanvasCardType.freehand =>
          Path()
            ..moveTo(pos.dx + size * 0.1, pos.dy + size * 0.5)
            ..quadraticBezierTo(
              pos.dx + size * 0.3,
              pos.dy + size * 0.1,
              pos.dx + size * 0.5,
              pos.dy + size * 0.5,
            )
            ..quadraticBezierTo(
              pos.dx + size * 0.7,
              pos.dy + size * 0.9,
              pos.dx + size * 0.9,
              pos.dy + size * 0.4,
            ),
      };
      canvas.drawPath(
        path,
        paint
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }


}

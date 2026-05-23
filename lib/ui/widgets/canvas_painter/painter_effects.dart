part of '../canvas_painter.dart';

mixin _CanvasEffectsPainterMixin on _CanvasPainterBase {
  @override
  void _drawConnectionPoints(Canvas canvas) {
    final dotRadius = 3.0 * scale;
    final hoverDotRadius = 5.0 * scale;
    final gap = 8.0 * scale;
    final spacing = 16.0 * scale;
    for (final card in cards) {
      if (!_isCardInSelectedLayer(card)) continue;
      if (card.type == CanvasCardType.freehand) continue;
      final showDots =
          selectedCardIds.contains(card.id) ||
          card.id == hoveredCardId ||
          card.id == connectingFromCardId;
      if (!showDots) continue;
      final pos = _w2s(card.x, card.y);
      final w = card.width * scale;
      final h = card.height * scale;
      final dotColor = primaryColor.withValues(alpha: 0.35);
      final hoverColor = primaryColor;
      final dotBorder = Colors.white.withValues(alpha: 0.6);

      void drawDot(double sx, double sy, ConnectionSide side) {
        final isHovered =
            card.id == hoveredCardId && side == hoveredConnectionSide;
        final r = isHovered ? hoverDotRadius : dotRadius;
        final color = isHovered ? hoverColor : dotColor;
        canvas.drawCircle(
          Offset(sx, sy),
          r,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(sx, sy),
          r,
          Paint()
            ..color = dotBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      final topY = pos.dy - gap;
      final bottomY = pos.dy + h + gap;
      final leftX = pos.dx - gap;
      final rightX = pos.dx + w + gap;

      final topCount = (w / spacing).floor().clamp(2, 20);
      for (int i = 0; i <= topCount; i++) {
        final x = pos.dx + w * i / topCount;
        drawDot(x, topY, ConnectionSide.top);
      }

      final bottomCount = (w / spacing).floor().clamp(2, 20);
      for (int i = 0; i <= bottomCount; i++) {
        final x = pos.dx + w * i / bottomCount;
        drawDot(x, bottomY, ConnectionSide.bottom);
      }

      final leftCount = (h / spacing).floor().clamp(2, 20);
      for (int i = 1; i < leftCount; i++) {
        final y = pos.dy + h * i / leftCount;
        drawDot(leftX, y, ConnectionSide.left);
      }

      final rightCount = (h / spacing).floor().clamp(2, 20);
      for (int i = 1; i < rightCount; i++) {
        final y = pos.dy + h * i / rightCount;
        drawDot(rightX, y, ConnectionSide.right);
      }
    }
  }

  @override
  void _drawFlowAnimation(
    Canvas canvas,
    Path path,
    CanvasConnectionStyle style,
  ) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final totalLen = metric.length;
    final baseColor = Color(style.colorValue);

    switch (style.flowAnimation) {
      case FlowAnimationStyle.flow:
        final dotCount = (totalLen / 30).floor().clamp(3, 20);
        final spacing = totalLen / dotCount;
        for (int i = 0; i < dotCount; i++) {
          final offset = (animationValue * totalLen + i * spacing) % totalLen;
          final tangent = metric.getTangentForOffset(offset);
          if (tangent != null) {
            final pos = tangent.position;
            canvas.drawCircle(
              pos,
              5.0 * scale,
              Paint()
                ..color = baseColor.withValues(alpha: 0.15)
                ..style = PaintingStyle.fill,
            );
            canvas.drawCircle(
              pos,
              3.0 * scale,
              Paint()
                ..color = baseColor.withValues(alpha: 0.8)
                ..style = PaintingStyle.fill,
            );
            canvas.drawCircle(
              pos,
              1.5 * scale,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.6)
                ..style = PaintingStyle.fill,
            );
          }
        }
      case FlowAnimationStyle.pulse:
        final pulsePos = (animationValue * totalLen) % totalLen;
        final pulseWidth = totalLen * 0.2;
        final start = (pulsePos - pulseWidth / 2).clamp(0.0, totalLen);
        final end = (pulsePos + pulseWidth / 2).clamp(0.0, totalLen);
        if (start < end) {
          final pulsePath = metric.extractPath(start, end);
          canvas.drawPath(
            pulsePath,
            Paint()
              ..color = baseColor.withValues(alpha: 0.12)
              ..style = PaintingStyle.stroke
              ..strokeWidth = style.strokeWidth + 8,
          );
          canvas.drawPath(
            pulsePath,
            Paint()
              ..color = baseColor.withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = style.strokeWidth + 3,
          );
          canvas.drawPath(
            pulsePath,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = style.strokeWidth,
          );
        }
      case FlowAnimationStyle.dash:
        final dashLen = 16.0;
        final gapLen = 12.0;
        final offset = (animationValue * 80) % (dashLen + gapLen);
        canvas.drawPath(
          path,
          Paint()
            ..color = baseColor.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.strokeWidth + 6,
        );
        _drawDashedPath(
          canvas,
          path,
          Paint()
            ..color = baseColor.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.strokeWidth + 1,
          dashLen,
          gapLen,
          offset,
        );
      case FlowAnimationStyle.none:
        break;
    }
  }

  @override
  void _drawRulers(Canvas canvas) {
    const rulerWidth = 24.0;
    final rulerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final tickColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.3);
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.5);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, viewW, rulerWidth),
      Paint()
        ..color = rulerColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, rulerWidth, viewH),
      Paint()
        ..color = rulerColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, rulerWidth, rulerWidth),
      Paint()
        ..color = rulerColor
        ..style = PaintingStyle.fill,
    );

    final tickInterval = gridSize * scale;
    final majorEvery = 5;
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 0.5;

    final startX = (rulerWidth - cameraX * scale + viewW / 2) % tickInterval;
    for (double x = startX; x < viewW; x += tickInterval) {
      if (x < rulerWidth) continue;
      final isMajor = ((x - startX) / tickInterval).round() % majorEvery == 0;
      final tickH = isMajor ? 10.0 : 5.0;
      canvas.drawLine(
        Offset(x, rulerWidth - tickH),
        Offset(x, rulerWidth),
        tickPaint,
      );
      if (isMajor) {
        final worldX = cameraX + (x - viewW / 2) / scale;
        final label = '${worldX.round()}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 7, color: textColor),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 2));
      }
    }

    final startY = (rulerWidth - cameraY * scale + viewH / 2) % tickInterval;
    for (double y = startY; y < viewH; y += tickInterval) {
      if (y < rulerWidth) continue;
      final isMajor = ((y - startY) / tickInterval).round() % majorEvery == 0;
      final tickW = isMajor ? 10.0 : 5.0;
      canvas.drawLine(
        Offset(rulerWidth - tickW, y),
        Offset(rulerWidth, y),
        tickPaint,
      );
      if (isMajor) {
        final worldY = cameraY + (y - viewH / 2) / scale;
        final label = '${worldY.round()}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 7, color: textColor),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        canvas.save();
        canvas.translate(2, y + tp.width / 2);
        canvas.rotate(-math.pi / 2);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.drawLine(
      Offset(rulerWidth, 0),
      Offset(rulerWidth, viewH),
      Paint()
        ..color = tickColor
        ..strokeWidth = 0.5,
    );
    canvas.drawLine(
      Offset(0, rulerWidth),
      Offset(viewW, rulerWidth),
      Paint()
        ..color = tickColor
        ..strokeWidth = 0.5,
    );
  }
}

part of '../canvas_painter.dart';

mixin _CanvasSwimlanePainterMixin on _CanvasPainterBase {
  @override
  void _drawSwimlaneCard(
    Canvas canvas,
    CanvasCard card,
    Map<String, Note> noteMap,
  ) {
    final pos = _w2s(card.x, card.y);
    final cardRect = Rect.fromLTWH(
      pos.dx,
      pos.dy,
      card.width * scale,
      card.height * scale,
    );

    final isSelected = selectedCardIds.contains(card.id);
    final cardColor = Color(card.colorValue);
    final headerH = 32.0 * scale;

    final rrect = RRect.fromRectAndRadius(
      cardRect,
      Radius.circular(6.0 * scale),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = cardColor.withValues(alpha: isDark ? 0.06 : 0.03)
        ..style = PaintingStyle.fill,
    );

    final headerRect = Rect.fromLTWH(
      cardRect.left,
      cardRect.top,
      cardRect.width,
      headerH,
    );
    final headerRRect = RRect.fromRectAndCorners(
      headerRect,
      topLeft: Radius.circular(6.0 * scale),
      topRight: Radius.circular(6.0 * scale),
    );
    canvas.drawRRect(
      headerRRect,
      Paint()
        ..color = cardColor.withValues(alpha: isDark ? 0.15 : 0.08)
        ..style = PaintingStyle.fill,
    );

    if (card.title.isNotEmpty) {
      final titleStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        fontSize: baseFontSize * 0.8,
        color: cardColor.withValues(alpha: 0.8),
      );
      final tp = TextPainter(
        text: TextSpan(text: card.title, style: titleStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      tp.layout(maxWidth: cardRect.width - 16 * scale);
      tp.paint(
        canvas,
        Offset(
          cardRect.left + 8 * scale,
          cardRect.top + (headerH - tp.height) / 2,
        ),
      );
    }

    if (card.type == CanvasCardType.swimlaneH) {
      final laneCount = math.max(1, (card.width / 200).floor().clamp(1, 10));
      final laneW = cardRect.width / laneCount;
      for (int i = 1; i < laneCount; i++) {
        final x = cardRect.left + laneW * i;
        canvas.drawLine(
          Offset(x, cardRect.top + headerH),
          Offset(x, cardRect.bottom),
          Paint()
            ..color = dividerColor.withValues(alpha: 0.3)
            ..strokeWidth = 1,
        );
      }
    } else {
      final laneCount = math.max(1, (card.height / 150).floor().clamp(1, 10));
      final laneH = (cardRect.height - headerH) / laneCount;
      for (int i = 1; i < laneCount; i++) {
        final y = cardRect.top + headerH + laneH * i;
        canvas.drawLine(
          Offset(cardRect.left, y),
          Offset(cardRect.right, y),
          Paint()
            ..color = dividerColor.withValues(alpha: 0.3)
            ..strokeWidth = 1,
        );
      }
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isSelected
            ? primaryColor
            : dividerColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2 : 1,
    );
  }
}

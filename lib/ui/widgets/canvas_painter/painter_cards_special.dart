part of '../canvas_painter.dart';

mixin _CanvasCardPainterSpecialMixin on _CanvasPainterBase {
  @override
  void _drawContainerCard(
    Canvas canvas,
    CanvasCard card,
    Map<String, Note> noteMap,
  ) {
    final childCards = cards
        .where((c) => card.childIds.contains(c.id))
        .toList();

    double minX = card.x, minY = card.y;
    double maxX = card.x + card.width, maxY = card.y + card.height;

    if (!card.collapsed) {
      for (final child in childCards) {
        minX = math.min(minX, child.x);
        minY = math.min(minY, child.y);
        maxX = math.max(maxX, child.x + child.width);
        maxY = math.max(maxY, child.y + child.height);
      }
    }

    final containerW = card.collapsed ? card.width : (maxX - minX + 32);
    final containerH = card.collapsed ? 40 : (maxY - minY + 32 + 40);
    final pos = _w2s(card.x, card.y);
    final containerRect = Rect.fromLTWH(
      pos.dx,
      pos.dy,
      containerW * scale,
      containerH * scale,
    );

    final isSelected = selectedCardIds.contains(card.id);
    final cardColor = Color(card.colorValue);
    final effectiveRadius = 12.0 * scale;

    final rrect = RRect.fromRectAndRadius(
      containerRect,
      Radius.circular(effectiveRadius),
    );

    canvas.drawShadow(
      Path()..addRRect(rrect),
      Colors.black.withValues(alpha: 0.08),
      8,
      false,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = cardColor.withValues(alpha: isDark ? 0.08 : 0.05)
        ..style = PaintingStyle.fill,
    );

    final headerRect = Rect.fromLTWH(
      containerRect.left,
      containerRect.top,
      containerRect.width,
      40 * scale,
    );
    final headerRRect = RRect.fromRectAndCorners(
      headerRect,
      topLeft: Radius.circular(effectiveRadius),
      topRight: Radius.circular(effectiveRadius),
    );
    canvas.drawRRect(
      headerRRect,
      Paint()
        ..color = cardColor.withValues(alpha: isDark ? 0.15 : 0.08)
        ..style = PaintingStyle.fill,
    );

    final collapseIconSize = 12.0 * scale;
    final collapseX = containerRect.left + 10 * scale;
    final collapseY = containerRect.top + (40 * scale - collapseIconSize) / 2;
    final collapsePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.2 * scale
      ..style = PaintingStyle.stroke;
    if (card.collapsed) {
      canvas.drawRect(
        Rect.fromLTWH(collapseX, collapseY, collapseIconSize, collapseIconSize),
        collapsePaint,
      );
      canvas.drawLine(
        Offset(collapseX + collapseIconSize / 2, collapseY + 2 * scale),
        Offset(
          collapseX + collapseIconSize / 2,
          collapseY + collapseIconSize - 2 * scale,
        ),
        collapsePaint,
      );
      canvas.drawLine(
        Offset(collapseX + 2 * scale, collapseY + collapseIconSize / 2),
        Offset(
          collapseX + collapseIconSize - 2 * scale,
          collapseY + collapseIconSize / 2,
        ),
        collapsePaint,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(collapseX, collapseY, collapseIconSize, collapseIconSize),
        collapsePaint,
      );
      canvas.drawLine(
        Offset(collapseX + 2 * scale, collapseY + collapseIconSize / 2),
        Offset(
          collapseX + collapseIconSize - 2 * scale,
          collapseY + collapseIconSize / 2,
        ),
        collapsePaint,
      );
    }

    final titleStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
      fontSize: baseFontSize * 0.85,
      color: cardColor.withValues(alpha: isDark ? 0.8 : 0.7),
    );
    final titleText = card.title.isEmpty ? 'Container' : card.title;
    final childCount = card.collapsed ? ' (${childCards.length})' : '';
    final tp = TextPainter(
      text: TextSpan(text: '$titleText$childCount', style: titleStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    tp.layout(maxWidth: containerRect.width - 36 * scale);
    tp.paint(
      canvas,
      Offset(
        containerRect.left + 28 * scale,
        containerRect.top + (40 * scale - tp.height) / 2,
      ),
    );

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

  @override
  void _drawImageCard(Canvas canvas, CanvasCard card) {
    final pos = _w2s(card.x, card.y);
    final cardRect = Rect.fromLTWH(
      pos.dx,
      pos.dy,
      card.width * scale,
      card.height * scale,
    );

    final isSelected = selectedCardIds.contains(card.id);
    final s = card.style ?? CanvasCardStyle.defaults;
    final effectiveRadius = s.borderRadius * scale;
    final rrect = RRect.fromRectAndRadius(
      cardRect,
      Radius.circular(effectiveRadius),
    );

    if (s.shadow) {
      canvas.drawShadow(
        Path()..addRRect(rrect),
        Colors.black.withValues(alpha: 0.12),
        10,
        false,
      );
    }

    canvas.save();
    canvas.clipRRect(rrect);

    // Draw background
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03)
        ..style = PaintingStyle.fill,
    );

    // Draw actual image if available in cache
    final cachedImage = cardImageCache[card.imagePath];
    if (cachedImage != null) {
      final imageRect = Rect.fromLTWH(
        cardRect.left,
        cardRect.top,
        cardRect.width,
        cardRect.height,
      );
      paintImage(
        canvas: canvas,
        rect: imageRect,
        image: cachedImage,
        fit: BoxFit.contain,
      );
    } else {
      // Draw placeholder icon when no image is loaded
      final iconPaint = Paint()..color = hintColor.withValues(alpha: 0.3);
      final iconSize = cardRect.shortestSide * 0.25;
      final iconCenter = cardRect.center;
      final iconPath = Path()
        ..moveTo(
          iconCenter.dx - iconSize * 0.5,
          iconCenter.dy - iconSize * 0.35,
        )
        ..lineTo(
          iconCenter.dx + iconSize * 0.5,
          iconCenter.dy - iconSize * 0.35,
        )
        ..lineTo(
          iconCenter.dx + iconSize * 0.5,
          iconCenter.dy + iconSize * 0.35,
        )
        ..lineTo(
          iconCenter.dx - iconSize * 0.5,
          iconCenter.dy + iconSize * 0.35,
        )
        ..close()
        ..moveTo(
          iconCenter.dx - iconSize * 0.3,
          iconCenter.dy + iconSize * 0.15,
        )
        ..lineTo(iconCenter.dx - iconSize * 0.1, iconCenter.dy - iconSize * 0.1)
        ..lineTo(
          iconCenter.dx + iconSize * 0.15,
          iconCenter.dy + iconSize * 0.05,
        )
        ..lineTo(
          iconCenter.dx + iconSize * 0.3,
          iconCenter.dy - iconSize * 0.1,
        );
      canvas.drawPath(
        iconPath,
        iconPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * scale,
      );

      // Draw "No Image" text
      final textStyle = TextStyle(
        color: hintColor.withValues(alpha: 0.5),
        fontSize: 11 * scale,
        fontStyle: FontStyle.italic,
      );
      final tp = TextPainter(
        text: TextSpan(text: 'No image', style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(
          iconCenter.dx - tp.width / 2,
          iconCenter.dy + iconSize * 0.35 + 4 * scale,
        ),
      );
    }

    canvas.restore();

    // Draw border
    if (isSelected) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = dividerColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale,
      );
    }
  }
}

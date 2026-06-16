part of '../canvas_painter.dart';

mixin _CanvasCardPainterMixin on _CanvasPainterBase {
  @override
  void _drawCards(Canvas canvas) {
    final noteMap = <String, Note>{};
    for (final n in knowledgeState.notes) {
      noteMap[n.id] = n;
    }

    for (final card in cards) {
      if (!_isCardInSelectedLayer(card)) continue;
      if (card.type == CanvasCardType.container) {
        _drawContainerCard(canvas, card, noteMap);
        continue;
      }
      if (card.type.isSwimlane) {
        _drawSwimlaneCard(canvas, card, noteMap);
        continue;
      }
      if (card.type == CanvasCardType.table) {
        _drawTableCard(canvas, card);
        continue;
      }
      if (card.type == CanvasCardType.freehand) {
        _drawFreehandCard(canvas, card);
        continue;
      }
      if (card.type.isGeometric) {
        _drawGeometricCard(canvas, card);
        continue;
      }
      if (card.type == CanvasCardType.image) {
        _drawImageCard(canvas, card);
        continue;
      }

      final pos = _w2s(card.x, card.y);
      final cardRect = Rect.fromLTWH(
        pos.dx,
        pos.dy,
        card.width * scale,
        card.height * scale,
      );

      final isSelected = selectedCardIds.contains(card.id);
      final isConnecting = card.id == connectingFromCardId;
      final isSearchMatch = searchMatchedIds.contains(card.id);
      final isSearchActive =
          searchMatchedIds.isNotEmpty &&
          searchActiveIndex < searchMatchedIds.length &&
          card.id == searchMatchedIds[searchActiveIndex];
      final isInlineEditing = card.id == inlineEditingCardId;

      final s = card.style ?? CanvasCardStyle.defaults;
      final effectiveRadius = s.borderRadius * scale;

      Color borderColor;
      double borderW;
      if (isSearchActive) {
        borderColor = Colors.orange;
        borderW = 2.5;
      } else if (isSearchMatch) {
        borderColor = Colors.orangeAccent;
        borderW = 2;
      } else if (isSelected) {
        borderColor = primaryColor;
        borderW = 2;
      } else if (isConnecting) {
        borderColor = primaryColor.withValues(alpha: 0.6);
        borderW = 1;
      } else {
        borderColor = Color(s.borderColor);
        borderW = s.borderWidth * scale;
      }

      final cardColor = Color(card.colorValue);
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
        canvas.drawShadow(
          Path()..addRRect(rrect),
          Colors.black.withValues(alpha: 0.06),
          20,
          false,
        );
      }

      if (s.gradientColor != null) {
        final gradientPaint = Paint()
          ..shader = LinearGradient(
            begin: s.gradientDirection.begin,
            end: s.gradientDirection.end,
            colors: [Color(s.fillColor), Color(s.gradientColor!)],
          ).createShader(cardRect)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, gradientPaint);
      } else {
        final bgColor = isDark
            ? cardColor.withValues(alpha: 0.15)
            : cardColor.withValues(alpha: 0.06);
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = bgColor
            ..style = PaintingStyle.fill,
        );
      }

      if (s.opacity < 1.0) {
        canvas.saveLayer(
          cardRect,
          Paint()..color = Colors.white.withValues(alpha: s.opacity),
        );
      }

      final highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.04 : 0.15),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5],
        ).createShader(cardRect);
      canvas.drawRRect(rrect, highlightPaint);

      if (isInlineEditing) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = primaryColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = primaryColor.withValues(alpha: 0.08)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        if (s.opacity < 1.0) canvas.restore();
        continue;
      }

      canvas.save();
      canvas.clipRRect(rrect);

      final headerBg = cardColor.withValues(alpha: isDark ? 0.18 : 0.10);
      final headerRect = Rect.fromLTWH(
        cardRect.left,
        cardRect.top,
        cardRect.width,
        30 * scale,
      );
      final headerRRect = RRect.fromRectAndCorners(
        headerRect,
        topLeft: Radius.circular(effectiveRadius),
        topRight: Radius.circular(effectiveRadius),
      );
      canvas.drawRRect(
        headerRRect,
        Paint()
          ..color = headerBg
          ..style = PaintingStyle.fill,
      );

      final headerGradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            cardColor.withValues(alpha: isDark ? 0.12 : 0.06),
            Colors.transparent,
          ],
        ).createShader(headerRect);
      canvas.drawRRect(headerRRect, headerGradientPaint);

      final iconSize = 13.0 * scale;
      final iconPaint = Paint()..color = primaryColor.withValues(alpha: 0.7);
      final iconPos = Offset(
        cardRect.left + 10 * scale,
        cardRect.top + (30 * scale - iconSize) / 2,
      );
      _drawCardTypeIcon(canvas, card.type, iconPos, iconSize, iconPaint);

      Note? linkedNote;
      bool noteDeleted = false;
      if (card.noteId != null) {
        linkedNote = noteMap[card.noteId];
        if (linkedNote == null) noteDeleted = true;
      }
      final displayTitle = linkedNote != null
          ? linkedNote.title
          : noteDeleted
          ? '${card.title} [deleted]'
          : (card.title.isEmpty ? card.type.label : card.title);
      final displayContent = linkedNote != null
          ? (linkedNote.content.length > 500
                ? '${linkedNote.content.substring(0, 500)}...'
                : linkedNote.content)
          : card.content;

      final cardFontSize = card.effectiveFontSize(baseFontSize);
      final titleStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        fontSize: cardFontSize,
        color: noteDeleted ? Colors.orange : null,
        letterSpacing: 0.2,
      );
      final tp = TextPainter(
        text: TextSpan(text: displayTitle, style: titleStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      tp.layout(maxWidth: cardRect.width - 36 * scale);
      tp.paint(
        canvas,
        Offset(
          cardRect.left + 26 * scale,
          cardRect.top + (30 * scale - tp.height) / 2,
        ),
      );

      final separatorY = cardRect.top + 30 * scale;
      canvas.drawLine(
        Offset(cardRect.left + 10 * scale, separatorY),
        Offset(cardRect.right - 10 * scale, separatorY),
        Paint()
          ..color = dividerColor.withValues(alpha: 0.5)
          ..strokeWidth = 0.5,
      );

      final contentTop = separatorY + 8 * scale;
      final contentHeight = cardRect.bottom - contentTop - 6 * scale;
      final lineHeight = cardFontSize * 1.06 * 1.4;
      final maxLines = contentHeight > 0
          ? (contentHeight / lineHeight).floor().clamp(1, 50)
          : 1;

      if (displayContent.isNotEmpty) {
        final contentStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
          fontSize: cardFontSize * 1.06,
          height: 1.4,
          color: displayContent == 'Empty note' ? hintColor : null,
        );
        final cp = TextPainter(
          text: TextSpan(text: displayContent, style: contentStyle),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
          ellipsis: '...',
        );
        cp.layout(maxWidth: cardRect.width - 20 * scale);
        cp.paint(canvas, Offset(cardRect.left + 10 * scale, contentTop));
      }

      if (displayContent.isEmpty && linkedNote == null) {
        final emptyStyle = TextStyle(
          color: hintColor.withValues(alpha: 0.7),
          fontSize: cardFontSize * 1.06,
          fontStyle: FontStyle.italic,
        );
        final emptyTp = TextPainter(
          text: TextSpan(
            text: card.type == CanvasCardType.note
                ? 'Empty note'
                : 'Type something...',
            style: emptyStyle,
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        emptyTp.layout(maxWidth: cardRect.width - 20 * scale);
        emptyTp.paint(canvas, Offset(cardRect.left + 10 * scale, contentTop));
      }

      canvas.restore();

      switch (s.borderStyle) {
        case CardBorderStyle.solid:
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = borderColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = borderW,
          );
        case CardBorderStyle.dashed:
          _drawDashedRRect(
            canvas,
            rrect,
            Paint()
              ..color = borderColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = borderW,
            6.0 * scale,
            4.0 * scale,
          );
        case CardBorderStyle.dotted:
          _drawDashedRRect(
            canvas,
            rrect,
            Paint()
              ..color = borderColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = borderW,
            2.0 * scale,
            2.0 * scale,
          );
        case CardBorderStyle.none:
          break;
      }

      if (s.opacity < 1.0) {
        canvas.restore();
      }

      if (!isSelected && s.borderStyle != CardBorderStyle.none) {
        final dotR = 2.5 * scale;
        canvas.drawCircle(
          Offset(cardRect.right - 7 * scale, cardRect.bottom - 7 * scale),
          dotR,
          Paint()..color = hintColor.withValues(alpha: 0.35),
        );
      }

      if (isSelected) {
        final handleSize = 16.0 * scale;
        final cornerX = cardRect.right - handleSize * 0.3;
        final cornerY = cardRect.bottom - handleSize * 0.3;
        final cornerR = handleSize * 0.55;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cornerX, cornerY),
              width: cornerR * 2.5,
              height: cornerR * 2.5,
            ),
            Radius.circular(cornerR * 0.6),
          ),
          Paint()
            ..color = primaryColor.withValues(alpha: 0.08)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        final cornerHandle = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cornerX, cornerY),
            width: cornerR * 2,
            height: cornerR * 2,
          ),
          Radius.circular(cornerR * 0.4),
        );
        canvas.drawRRect(
          cornerHandle,
          Paint()
            ..color = primaryColor.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(
          cornerHandle,
          Paint()
            ..color = primaryColor.withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 * scale,
        );

        final gLen = cornerR * 0.45;
        final gOff = cornerR * 0.22;
        final gp = Paint()
          ..color = primaryColor
          ..strokeWidth = 1.3 * scale
          ..style = PaintingStyle.stroke;
        final gcx = cornerX + gOff;
        final gcy = cornerY + gOff;
        canvas.drawLine(Offset(gcx - gLen, gcy), Offset(gcx, gcy), gp);
        canvas.drawLine(Offset(gcx, gcy - gLen), Offset(gcx, gcy), gp);
        canvas.drawLine(
          Offset(gcx - gLen * 0.45, gcy - gLen * 0.45),
          Offset(gcx, gcy),
          gp,
        );

        final ew = 4 * scale;
        canvas.drawRect(
          Rect.fromLTWH(
            cardRect.right - ew,
            cardRect.top + 30 * scale,
            ew,
            cardRect.height - 30 * scale - handleSize,
          ),
          Paint()..color = primaryColor.withValues(alpha: 0.07),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            cardRect.left,
            cardRect.bottom - ew,
            cardRect.width - handleSize,
            ew,
          ),
          Paint()..color = primaryColor.withValues(alpha: 0.07),
        );
      }
    }
  }

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

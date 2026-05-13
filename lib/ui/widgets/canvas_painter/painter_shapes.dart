part of '../canvas_painter.dart';

mixin CanvasShapePainterMixin on _CanvasPainterBase {
    Path _buildGeometricPath(CanvasCard card, Rect cardRect) {
      final w = cardRect.width;
      final h = cardRect.height;
      final l = cardRect.left;
      final t = cardRect.top;
      final r = cardRect.right;
      final b = cardRect.bottom;
      final cx = cardRect.center.dx;
      final cy = cardRect.center.dy;

      return switch (card.type) {
        CanvasCardType.rectangle => Path()..addRect(cardRect),
        CanvasCardType.roundedRect =>
          Path()..addRRect(
            RRect.fromRectAndRadius(cardRect, Radius.circular(8.0 * scale)),
          ),
        CanvasCardType.ellipse => Path()..addOval(cardRect),
        CanvasCardType.diamond =>
          Path()
            ..moveTo(cx, t)
            ..lineTo(r, cy)
            ..lineTo(cx, b)
            ..lineTo(l, cy)
            ..close(),
        CanvasCardType.hexagon =>
          Path()
            ..moveTo(l + w * 0.25, t)
            ..lineTo(l + w * 0.75, t)
            ..lineTo(r, cy)
            ..lineTo(l + w * 0.75, b)
            ..lineTo(l + w * 0.25, b)
            ..lineTo(l, cy)
            ..close(),
        CanvasCardType.parallelogram =>
          Path()
            ..moveTo(l + w * 0.15, t)
            ..lineTo(r, t)
            ..lineTo(r - w * 0.15, b)
            ..lineTo(l, b)
            ..close(),
        CanvasCardType.triangle =>
          Path()
            ..moveTo(cx, t)
            ..lineTo(r, b)
            ..lineTo(l, b)
            ..close(),
        CanvasCardType.cylinder =>
          Path()
            ..moveTo(l, t + h * 0.12)
            ..lineTo(l, b - h * 0.12)
            ..quadraticBezierTo(l, b, cx, b)
            ..quadraticBezierTo(r, b, r, b - h * 0.12)
            ..lineTo(r, t + h * 0.12)
            ..quadraticBezierTo(r, t, cx, t)
            ..quadraticBezierTo(l, t, l, t + h * 0.12),
        CanvasCardType.star =>
          Path()
            ..moveTo(cx, t)
            ..lineTo(l + w * 0.62, t + h * 0.35)
            ..lineTo(r, t + h * 0.35)
            ..lineTo(l + w * 0.7, t + h * 0.58)
            ..lineTo(l + w * 0.8, b)
            ..lineTo(cx, t + h * 0.72)
            ..lineTo(l + w * 0.2, b)
            ..lineTo(l + w * 0.3, t + h * 0.58)
            ..lineTo(l, t + h * 0.35)
            ..lineTo(l + w * 0.38, t + h * 0.35)
            ..close(),
        CanvasCardType.table =>
          Path()..addRRect(
            RRect.fromRectAndRadius(cardRect, Radius.circular(4.0 * scale)),
          ),
        CanvasCardType.freehand => Path()..addRect(cardRect),
        _ =>
          Path()..addRRect(
            RRect.fromRectAndRadius(cardRect, Radius.circular(8.0 * scale)),
          ),
      };
    }

    void _drawGeometricCard(Canvas canvas, CanvasCard card, Rect clipRect) {
      final pos = _w2s(card.x, card.y);
      final cardRect = Rect.fromLTWH(
        pos.dx,
        pos.dy,
        card.width * scale,
        card.height * scale,
      );
      if (!clipRect.overlaps(cardRect)) return;

      final isSelected = selectedCardIds.contains(card.id);
      final s = card.style ?? CanvasCardStyle.defaults;
      final cardColor = Color(card.colorValue);
      final shapePath = _buildGeometricPath(card, cardRect);

      if (s.shadow) {
        canvas.drawShadow(
          shapePath,
          Colors.black.withValues(alpha: 0.12),
          8,
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
        canvas.drawPath(shapePath, gradientPaint);
      } else {
        final bgColor = isDark
            ? cardColor.withValues(alpha: 0.15)
            : cardColor.withValues(alpha: 0.06);
        canvas.drawPath(
          shapePath,
          Paint()
            ..color = bgColor
            ..style = PaintingStyle.fill,
        );
      }

      final highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5],
        ).createShader(cardRect);
      canvas.drawPath(shapePath, highlightPaint);

      final hasContent =
          card.title.isNotEmpty ||
          card.content.isNotEmpty ||
          card.richContent.isNotEmpty;
      if (hasContent) {
        canvas.save();
        canvas.clipPath(shapePath);
        final cardFontSize = card.effectiveFontSize(baseFontSize);
        final textColor = Color(card.textColorValue);
        final effectiveFontFamily = card.fontFamily.isNotEmpty
            ? card.fontFamily
            : null;
        final textAlign = switch (card.textAlignH) {
          TextAlignH.left => TextAlign.left,
          TextAlignH.center => TextAlign.center,
          TextAlignH.right => TextAlign.right,
        };

        double maxTextWidth = cardRect.width - 16 * scale;

        double textY;
        switch (card.textAlignV) {
          case TextAlignV.top:
            textY = cardRect.top + 8 * scale;
          case TextAlignV.middle:
            textY = cardRect.center.dy - 20 * scale;
          case TextAlignV.bottom:
            textY = cardRect.bottom - 40 * scale;
        }

        if (card.title.isNotEmpty) {
          final titleStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: cardFontSize,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
            fontFamily: effectiveFontFamily,
          );
          final tp = TextPainter(
            text: TextSpan(text: card.title, style: titleStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '...',
            textAlign: textAlign,
          );
          tp.layout(maxWidth: maxTextWidth);
          final offsetX = card.textAlignH == TextAlignH.center
              ? (cardRect.width - tp.width) / 2
              : card.textAlignH == TextAlignH.right
              ? cardRect.width - tp.width - 8 * scale
              : 8 * scale;
          tp.paint(canvas, Offset(cardRect.left + offsetX, textY));
          textY += tp.height + 4 * scale;
        }

        if (card.richContent.isNotEmpty) {
          final baseStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
            fontSize: cardFontSize * 0.9,
            height: 1.3,
            color: isDark ? Colors.white70 : textColor.withValues(alpha: 0.7),
            fontFamily: effectiveFontFamily,
          );
          final spans = card.richContent.map((seg) {
            final style = switch (seg.type) {
              RichTextSegmentType.bold => baseStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
              RichTextSegmentType.italic => baseStyle.copyWith(
                fontStyle: FontStyle.italic,
              ),
              RichTextSegmentType.underline => baseStyle.copyWith(
                decoration: TextDecoration.underline,
              ),
              RichTextSegmentType.code => baseStyle.copyWith(
                fontFamily: 'monospace',
                backgroundColor: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05),
              ),
              RichTextSegmentType.strikethrough => baseStyle.copyWith(
                decoration: TextDecoration.lineThrough,
              ),
              RichTextSegmentType.text => baseStyle,
            };
            return TextSpan(text: seg.text, style: style);
          }).toList();
          final cp = TextPainter(
            text: TextSpan(children: spans),
            textDirection: TextDirection.ltr,
            maxLines: 5,
            ellipsis: '...',
            textAlign: textAlign,
          );
          cp.layout(maxWidth: maxTextWidth);
          final offsetX = card.textAlignH == TextAlignH.center
              ? (cardRect.width - cp.width) / 2
              : card.textAlignH == TextAlignH.right
              ? cardRect.width - cp.width - 8 * scale
              : 8 * scale;
          cp.paint(canvas, Offset(cardRect.left + offsetX, textY));
        } else if (card.content.isNotEmpty) {
          final contentStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
            fontSize: cardFontSize * 0.9,
            height: 1.3,
            color: isDark ? Colors.white70 : textColor.withValues(alpha: 0.7),
            fontFamily: effectiveFontFamily,
          );
          final cp = TextPainter(
            text: TextSpan(text: card.content, style: contentStyle),
            textDirection: TextDirection.ltr,
            maxLines: 3,
            ellipsis: '...',
            textAlign: textAlign,
          );
          cp.layout(maxWidth: maxTextWidth);
          final offsetX = card.textAlignH == TextAlignH.center
              ? (cardRect.width - cp.width) / 2
              : card.textAlignH == TextAlignH.right
              ? cardRect.width - cp.width - 8 * scale
              : 8 * scale;
          cp.paint(canvas, Offset(cardRect.left + offsetX, textY));
        }
        canvas.restore();
      }

      if (card.tags.isNotEmpty) {
        canvas.save();
        canvas.clipPath(shapePath);
        double tagX = cardRect.left + 6 * scale;
        final tagY = cardRect.bottom - 16 * scale;
        for (final tag in card.tags.take(3)) {
          final tagStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
            fontSize: (baseFontSize * 0.55).clamp(6.0, 9.0),
            color: primaryColor.withValues(alpha: 0.8),
          );
          final tp = TextPainter(
            text: TextSpan(text: '#$tag', style: tagStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          );
          tp.layout();
          final tagBg = RRect.fromRectAndRadius(
            Rect.fromLTWH(tagX, tagY, tp.width + 6 * scale, 12 * scale),
            Radius.circular(3 * scale),
          );
          canvas.drawRRect(
            tagBg,
            Paint()
              ..color = primaryColor.withValues(alpha: 0.08)
              ..style = PaintingStyle.fill,
          );
          tp.paint(canvas, Offset(tagX + 3 * scale, tagY + 1 * scale));
          tagX += tp.width + 10 * scale;
        }
        canvas.restore();
      }

      Color borderColor;
      double borderW;
      if (isSelected) {
        borderColor = primaryColor;
        borderW = 2;
      } else {
        borderColor = Color(s.borderColor);
        borderW = s.borderWidth * scale;
      }

      switch (s.borderStyle) {
        case CardBorderStyle.solid:
          canvas.drawPath(
            shapePath,
            Paint()
              ..color = borderColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = borderW,
          );
        case CardBorderStyle.dashed:
          _drawDashedPath(
            canvas,
            shapePath,
            Paint()
              ..color = borderColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = borderW,
            6.0 * scale,
            4.0 * scale,
          );
        case CardBorderStyle.dotted:
          _drawDashedPath(
            canvas,
            shapePath,
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

      if (isSelected) {
        final handleSize = 8.0 * scale;
        final handles = [
          Offset(cardRect.left, cardRect.top),
          Offset(cardRect.right, cardRect.top),
          Offset(cardRect.left, cardRect.bottom),
          Offset(cardRect.right, cardRect.bottom),
          Offset(cardRect.center.dx, cardRect.top),
          Offset(cardRect.center.dx, cardRect.bottom),
          Offset(cardRect.left, cardRect.center.dy),
          Offset(cardRect.right, cardRect.center.dy),
        ];
        for (final h in handles) {
          canvas.drawRect(
            Rect.fromCenter(center: h, width: handleSize, height: handleSize),
            Paint()
              ..color = scaffoldBg
              ..style = PaintingStyle.fill,
          );
          canvas.drawRect(
            Rect.fromCenter(center: h, width: handleSize, height: handleSize),
            Paint()
              ..color = primaryColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }

    void _drawSwimlaneCard(
      Canvas canvas,
      CanvasCard card,
      Rect clipRect,
      Map<String, Note> noteMap,
    ) {
      final pos = _w2s(card.x, card.y);
      final cardRect = Rect.fromLTWH(
        pos.dx,
        pos.dy,
        card.width * scale,
        card.height * scale,
      );
      if (!clipRect.overlaps(cardRect)) return;

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

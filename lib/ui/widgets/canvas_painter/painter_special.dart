part of '../canvas_painter.dart';

mixin _CanvasSpecialPainterMixin on _CanvasPainterBase {
    @override
  void _drawLineJumps(
      Canvas canvas,
      Path path,
      CanvasConnectionStyle style,
      String currentConnId,
    ) {
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) return;
      final metric = metrics.first;

      final allConns = [...connections, ...autoConnections];
      final cardById = <String, CanvasCard>{};
      for (final c in cards) {
        cardById[c.id] = c;
      }

      final otherPaths = <Path>[];
      for (final otherConn in allConns) {
        if (otherConn.id == currentConnId) continue;
        final from = cardById[otherConn.fromCardId];
        final to = cardById[otherConn.toCardId];
        if (from == null || to == null) continue;
        if (!_isCardLayerVisible(from) || !_isCardLayerVisible(to)) continue;
        final fp = _w2s(
          otherConn.fromSide.point(from.rect, otherConn.fromSideOffset).dx,
          otherConn.fromSide.point(from.rect, otherConn.fromSideOffset).dy,
        );
        final tp = _w2s(
          otherConn.toSide.point(to.rect, otherConn.toSideOffset).dx,
          otherConn.toSide.point(to.rect, otherConn.toSideOffset).dy,
        );
        final otherStyle = otherConn.style ?? CanvasConnectionStyle.defaults;
        final otherPathType = otherConn.isAuto
            ? ConnectionPath.curved
            : otherStyle.pathType;
        Path otherPath;
        switch (otherPathType) {
          case ConnectionPath.straight:
            otherPath = Path()
              ..moveTo(fp.dx, fp.dy)
              ..lineTo(tp.dx, tp.dy);
          case ConnectionPath.orthogonal:
            otherPath = _buildOrthogonalPath(
              fp,
              tp,
              otherConn.fromSide,
              otherConn.toSide,
              otherConn.waypoints,
            );
          case ConnectionPath.curved:
            final dx = (tp.dx - fp.dx).abs();
            final dy = (tp.dy - fp.dy).abs();
            final cp = math.max(dx, dy) * 0.4;
            Offset cp1, cp2;
            if (dx > dy) {
              final dir = tp.dx > fp.dx ? 1.0 : -1.0;
              cp1 = Offset(fp.dx + cp * dir, fp.dy);
              cp2 = Offset(tp.dx - cp * dir, tp.dy);
            } else {
              final dir = tp.dy > fp.dy ? 1.0 : -1.0;
              cp1 = Offset(fp.dx, fp.dy + cp * dir);
              cp2 = Offset(tp.dx, tp.dy - cp * dir);
            }
            otherPath = Path()
              ..moveTo(fp.dx, fp.dy)
              ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, tp.dx, tp.dy);
        }
        otherPaths.add(otherPath);
      }

      if (otherPaths.isEmpty) return;

      final jumpSize = style.lineJumpSize * scale;
      final jumpBgPaint = Paint()
        ..color = scaffoldBg
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth + 4;
      final jumpFgPaint = Paint()
        ..color = Color(style.colorValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth;

      final step = 2.0;
      for (double d = 0; d < metric.length; d += step) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent == null) continue;
        final point = tangent.position;
        for (final otherPath in otherPaths) {
          final otherMetrics = otherPath.computeMetrics();
          for (final om in otherMetrics) {
            for (double od = 0; od < om.length; od += step) {
              final ot = om.getTangentForOffset(od);
              if (ot == null) continue;
              final dist =
                  (point.dx - ot.position.dx) * (point.dx - ot.position.dx) +
                  (point.dy - ot.position.dy) * (point.dy - ot.position.dy);
              if (dist < jumpSize * jumpSize * 0.25) {
                switch (style.lineJumpStyle) {
                  case LineJumpStyle.arc:
                    final arcRect = Rect.fromCenter(
                      center: point,
                      width: jumpSize * 2,
                      height: jumpSize * 2,
                    );
                    canvas.drawArc(
                      arcRect,
                      -math.pi,
                      math.pi,
                      false,
                      jumpBgPaint,
                    );
                    final arcPath = Path()..addArc(arcRect, -math.pi, math.pi);
                    canvas.drawPath(arcPath, jumpFgPaint);
                  case LineJumpStyle.gap:
                    canvas.drawLine(
                      Offset(point.dx - jumpSize * 0.5, point.dy),
                      Offset(point.dx + jumpSize * 0.5, point.dy),
                      jumpBgPaint,
                    );
                  case LineJumpStyle.square:
                    canvas.drawRect(
                      Rect.fromCenter(
                        center: point,
                        width: jumpSize,
                        height: jumpSize,
                      ),
                      jumpBgPaint,
                    );
                    final sqPath = Path()
                      ..moveTo(point.dx - jumpSize * 0.5, point.dy)
                      ..lineTo(
                        point.dx - jumpSize * 0.5,
                        point.dy - jumpSize * 0.5,
                      )
                      ..lineTo(
                        point.dx + jumpSize * 0.5,
                        point.dy - jumpSize * 0.5,
                      )
                      ..lineTo(point.dx + jumpSize * 0.5, point.dy);
                    canvas.drawPath(sqPath, jumpFgPaint);
                  case LineJumpStyle.none:
                    break;
                }
                d += jumpSize;
                break;
              }
            }
          }
        }
      }
    }

    @override
  void _drawTableCard(Canvas canvas, CanvasCard card, Rect clipRect) {
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

      if (s.shadow) {
        canvas.drawRect(
          cardRect.translate(2, 2),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.08)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawRect(
        cardRect,
        Paint()
          ..color = cardColor.withValues(alpha: isDark ? 0.15 : 0.06)
          ..style = PaintingStyle.fill,
      );

      final headerH = 28.0 * scale;
      canvas.drawRect(
        Rect.fromLTWH(cardRect.left, cardRect.top, cardRect.width, headerH),
        Paint()
          ..color = cardColor.withValues(alpha: isDark ? 0.2 : 0.1)
          ..style = PaintingStyle.fill,
      );

      if (card.title.isNotEmpty) {
        final titleStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: baseFontSize * 0.75,
          color: isDark ? Colors.white70 : Colors.black87,
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

      final rows = card.tableRows;
      final cols = card.tableCols;
      final cellW = cardRect.width / cols;
      final cellH = (cardRect.height - headerH) / rows;
      final linePaint = Paint()
        ..color = dividerColor.withValues(alpha: 0.3)
        ..strokeWidth = 0.5;

      for (int c = 1; c < cols; c++) {
        final x = cardRect.left + cellW * c;
        canvas.drawLine(
          Offset(x, cardRect.top + headerH),
          Offset(x, cardRect.bottom),
          linePaint,
        );
      }
      for (int r = 0; r < rows; r++) {
        final y = cardRect.top + headerH + cellH * r;
        canvas.drawLine(
          Offset(cardRect.left, y),
          Offset(cardRect.right, y),
          linePaint,
        );
        for (int c = 0; c < cols; c++) {
          final idx = r * cols + c;
          if (idx < card.tableCells.length &&
              card.tableCells[idx].text.isNotEmpty) {
            final cellStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
              fontSize: baseFontSize * 0.65,
              color: isDark ? Colors.white60 : Colors.black54,
            );
            final cp = TextPainter(
              text: TextSpan(text: card.tableCells[idx].text, style: cellStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              ellipsis: '...',
            );
            cp.layout(maxWidth: cellW - 6 * scale);
            cp.paint(
              canvas,
              Offset(
                cardRect.left + cellW * c + 3 * scale,
                y + (cellH - cp.height) / 2,
              ),
            );
          }
        }
      }

      canvas.drawRect(
        cardRect,
        Paint()
          ..color = isSelected
              ? primaryColor
              : dividerColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2 : 1,
      );
    }

    @override
  void _drawFreehandCard(Canvas canvas, CanvasCard card, Rect clipRect) {
      if (card.freehandPoints.isEmpty) return;
      final isSelected = selectedCardIds.contains(card.id);
      final cardColor = Color(card.colorValue);
      final path = Path();
      bool first = true;
      for (final p in card.freehandPoints) {
        final sp = _w2s(p.dx, p.dy);
        if (first) {
          path.moveTo(sp.dx, sp.dy);
          first = false;
        } else {
          path.lineTo(sp.dx, sp.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = cardColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (isSelected) {
        final bounds = path.getBounds();
        canvas.drawRect(
          bounds.inflate(4),
          Paint()
            ..color = primaryColor.withValues(alpha: 0.2)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          bounds.inflate(4),
          Paint()
            ..color = primaryColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }


}

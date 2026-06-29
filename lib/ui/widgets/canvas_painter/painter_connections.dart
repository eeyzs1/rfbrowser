part of '../canvas_painter.dart';

mixin _CanvasConnectionPainterMixin on _CanvasPainterBase {
  @override
  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = dividerColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    final xs = (visibleWorldRect.left / gridSize).floor() * gridSize;
    final ys = (visibleWorldRect.top / gridSize).floor() * gridSize;
    final tl = _w2s(visibleWorldRect.left, visibleWorldRect.top);
    final br = _w2s(visibleWorldRect.right, visibleWorldRect.bottom);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, viewW, viewH));
    for (double x = xs; x <= visibleWorldRect.right; x += gridSize) {
      final p = _w2s(x, 0);
      canvas.drawLine(Offset(p.dx, tl.dy), Offset(p.dx, br.dy), paint);
    }
    for (double y = ys; y <= visibleWorldRect.bottom; y += gridSize) {
      final p = _w2s(0, y);
      canvas.drawLine(Offset(tl.dx, p.dy), Offset(br.dx, p.dy), paint);
    }
    canvas.restore();
  }

  @override
  void _drawGroups(Canvas canvas) {
    for (final group in groups) {
      if (group.cardIds.isEmpty) continue;
      // Issue 9: Use the cached cardById map instead of O(n) where().contains().
      final groupCards = group.cardIds
          .map((id) => _cardByIdMap[id])
          .whereType<CanvasCard>()
          .toList();
      if (groupCards.isEmpty) continue;

      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final card in groupCards) {
        minX = math.min(minX, card.x);
        minY = math.min(minY, card.y);
        maxX = math.max(maxX, card.x + card.width);
        maxY = math.max(maxY, card.y + card.height);
      }

      const padding = 16.0;
      final groupRect = Rect.fromLTRB(
        minX - padding,
        minY - padding - 20,
        maxX + padding,
        maxY + padding,
      );
      final screenRect = Rect.fromLTRB(
        _w2s(groupRect.left, 0).dx,
        _w2s(0, groupRect.top).dy,
        _w2s(groupRect.right, 0).dx,
        _w2s(0, groupRect.bottom).dy,
      );

      final groupColor = Color(group.colorValue);
      final bgPaint = Paint()
        ..color = groupColor.withValues(alpha: isDark ? 0.06 : 0.04)
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(
        screenRect,
        const Radius.circular(12),
      );
      canvas.drawRRect(rrect, bgPaint);

      final dashPaint = Paint()
        ..color = groupColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      _drawDashedRRect(canvas, rrect, dashPaint, 6.0, 4.0);

      if (group.name.isNotEmpty) {
        final nameStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
          fontSize: (baseFontSize * 0.7).clamp(8.0, 12.0),
          color: groupColor.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
        );
        final tp = TextPainter(
          text: TextSpan(text: group.name, style: nameStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        tp.layout();
        tp.paint(canvas, Offset(screenRect.left + 8, screenRect.top + 4));
      }
    }
  }

  @override
  void _drawDashedRRect(
    Canvas canvas,
    RRect rrect,
    Paint paint,
    double dashWidth,
    double dashGap,
  ) {
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint, dashWidth, dashGap);
  }

  @override
  void _drawConnections(Canvas canvas) {
    // Issue 8: Use the cached cardById map (built once per painter instance)
    // instead of rebuilding it on every paint() call.
    final cardById = _cardByIdMap;

    void drawLine(CanvasConnection conn, bool forceDashed) {
      final from = cardById[conn.fromCardId];
      final to = cardById[conn.toCardId];
      if (from == null || to == null) return;
      if (!_isCardInSelectedLayer(from) || !_isCardInSelectedLayer(to)) return;
      final fromPoint = conn.fromSide.point(from.rect, conn.fromSideOffset);
      final toPoint = conn.toSide.point(to.rect, conn.toSideOffset);
      final fp = _w2s(fromPoint.dx, fromPoint.dy);
      final tp = _w2s(toPoint.dx, toPoint.dy);

      final connStyle = conn.style ?? CanvasConnectionStyle.defaults;
      final isDashed = forceDashed || conn.isAuto;
      final lineColor = isDashed
          ? primaryColor.withValues(alpha: 0.5)
          : Color(connStyle.colorValue);
      final lineW = isDashed ? 1.5 : connStyle.strokeWidth;

      final pathType = forceDashed ? ConnectionPath.curved : connStyle.pathType;
      Path path;
      Offset arrowFrom;

      switch (pathType) {
        case ConnectionPath.straight:
          path = Path()..moveTo(fp.dx, fp.dy);
          for (final wp in conn.waypoints) {
            final swp = _w2s(wp.dx, wp.dy);
            path.lineTo(swp.dx, swp.dy);
          }
          path.lineTo(tp.dx, tp.dy);
          arrowFrom = conn.waypoints.isNotEmpty
              ? _w2s(conn.waypoints.last.dx, conn.waypoints.last.dy)
              : fp;
        case ConnectionPath.orthogonal:
          path = _buildOrthogonalPath(
            fp,
            tp,
            conn.fromSide,
            conn.toSide,
            conn.waypoints,
          );
          arrowFrom = conn.waypoints.isNotEmpty
              ? _w2s(conn.waypoints.last.dx, conn.waypoints.last.dy)
              : fp;
        case ConnectionPath.curved:
          if (conn.waypoints.isNotEmpty) {
            path = Path()..moveTo(fp.dx, fp.dy);
            final screenWaypoints = conn.waypoints
                .map((w) => _w2s(w.dx, w.dy))
                .toList();
            for (int i = 0; i < screenWaypoints.length; i++) {
              final prev = i == 0 ? fp : screenWaypoints[i - 1];
              final curr = screenWaypoints[i];
              final next = i < screenWaypoints.length - 1
                  ? screenWaypoints[i + 1]
                  : tp;
              final cp1 = Offset(
                prev.dx + (curr.dx - prev.dx) * 0.5,
                prev.dy + (curr.dy - prev.dy) * 0.1,
              );
              final cp2 = Offset(
                curr.dx - (next.dx - curr.dx) * 0.1,
                curr.dy - (next.dy - curr.dy) * 0.5,
              );
              path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
            }
            final lastWp = screenWaypoints.last;
            final cp1 = Offset(
              lastWp.dx + (tp.dx - lastWp.dx) * 0.5,
              lastWp.dy + (tp.dy - lastWp.dy) * 0.1,
            );
            final cp2 = Offset(
              tp.dx - (tp.dx - lastWp.dx) * 0.1,
              tp.dy - (tp.dy - lastWp.dy) * 0.5,
            );
            path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, tp.dx, tp.dy);
            arrowFrom = lastWp;
          } else {
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
            path = Path()
              ..moveTo(fp.dx, fp.dy)
              ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, tp.dx, tp.dy);
            arrowFrom = cp2;
          }
      }

      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = lineW
        ..style = PaintingStyle.stroke;
      if (conn.id == selectedConnectionId) {
        final selPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.15)
          ..strokeWidth = lineW + 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, selPaint);
      }
      if (isDashed) {
        _drawDashedPath(canvas, path, paint, 4.0, 4.0);
      } else {
        canvas.drawPath(path, paint);
      }

      if (connStyle.lineJumpStyle != LineJumpStyle.none && !isDashed) {
        _drawLineJumps(canvas, path, connStyle, conn.id);
      }

      if (connStyle.flowAnimation != FlowAnimationStyle.none && !forceDashed) {
        _drawFlowAnimation(canvas, path, connStyle);
      }

      if (connStyle.arrowStyle != ArrowStyle.none && !forceDashed) {
        _drawArrowHead(
          canvas,
          arrowFrom,
          tp,
          lineColor,
          connStyle.arrowStyle,
          connStyle.arrowSize,
        );
      } else if (connStyle.arrowStyle == ArrowStyle.none) {
        // no arrow
      } else if (!isDashed) {
        _drawArrowHead(
          canvas,
          arrowFrom,
          tp,
          lineColor,
          ArrowStyle.filledTriangle,
          connStyle.arrowSize,
        );
      } else {
        _drawArrowHead(
          canvas,
          arrowFrom,
          tp,
          lineColor,
          ArrowStyle.triangle,
          connStyle.arrowSize,
        );
      }

      if (connStyle.startArrowStyle != ArrowStyle.none && !forceDashed) {
        final firstWp = conn.waypoints.isNotEmpty
            ? _w2s(conn.waypoints.first.dx, conn.waypoints.first.dy)
            : tp;
        _drawArrowHead(
          canvas,
          firstWp,
          fp,
          lineColor,
          connStyle.startArrowStyle,
          connStyle.arrowSize,
        );
      }

      if (conn.label.isNotEmpty) {
        final labelPos = _pathMidpoint(path);
        final effectiveFontSize = connStyle.labelFontSize > 0
            ? connStyle.labelFontSize * scale
            : (baseFontSize * 0.7).clamp(8.0, 14.0);
        final labelStyle = (bodySmallStyle ?? const TextStyle()).copyWith(
          fontSize: effectiveFontSize,
          color: isDashed ? hintColor : Color(connStyle.colorValue),
        );
        final tp2 = TextPainter(
          text: TextSpan(text: conn.label, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        tp2.layout();
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(labelPos.dx, labelPos.dy - 8),
            width: tp2.width + 8,
            height: tp2.height + 4,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          bgRect,
          Paint()
            ..color = scaffoldBg
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(
          bgRect,
          Paint()
            ..color = (isDashed ? hintColor : Color(connStyle.colorValue))
                .withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
        tp2.paint(
          canvas,
          Offset(labelPos.dx - tp2.width / 2, labelPos.dy - 8 - tp2.height / 2),
        );
      }

      if (conn.waypoints.isNotEmpty && !forceDashed) {
        final wpSize = connStyle.waypointSize * scale;
        for (final wp in conn.waypoints) {
          final swp = _w2s(wp.dx, wp.dy);
          canvas.drawCircle(
            swp,
            wpSize,
            Paint()
              ..color = scaffoldBg
              ..style = PaintingStyle.fill,
          );
          canvas.drawCircle(
            swp,
            wpSize,
            Paint()
              ..color = lineColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          canvas.drawCircle(
            swp,
            wpSize * 0.375,
            Paint()
              ..color = lineColor
              ..style = PaintingStyle.fill,
          );
        }
      }
    }

    for (final conn in connections) {
      drawLine(conn, false);
    }
    for (final conn in autoConnections) {
      drawLine(conn, true);
    }

    if (connectingFromCardId != null && connectingPreviewEnd != null) {
      final fromCard = cardById[connectingFromCardId];
      if (fromCard != null) {
        // 起点使用实际的连接点（卡片边缘上的点），而不是卡片中心
        // 这样预览线从用户拖拽的 connection point 出发，与最终落点连线视觉一致
        final side = connectingFromSide ?? ConnectionSide.top;
        final startWorld = side.point(fromCard.rect, connectingFromSideOffset);
        final fp = _w2s(startWorld.dx, startWorld.dy);
        final tp = connectingPreviewEnd!;
        final path = Path()
          ..moveTo(fp.dx, fp.dy)
          ..quadraticBezierTo(
            fp.dx + (tp.dx - fp.dx) * 0.5,
            fp.dy + (tp.dy - fp.dy) * 0.3,
            tp.dx,
            tp.dy,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = primaryColor.withValues(alpha: 0.3)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/canvas_model.dart';
import '../../data/models/note.dart';
import '../../services/knowledge_service.dart';

class CanvasPainter extends CustomPainter {
  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final List<CanvasConnection> autoConnections;
  final double cameraX, cameraY, scale, viewW, viewH, gridSize;
  final Rect visibleWorldRect;
  final List<String> selectedCardIds;
  final String? connectingFromCardId;
  final List<String> searchMatchedIds;
  final int searchActiveIndex;
  final Offset? connectingPreviewEnd;
  final String? hoveredCardId;
  final ConnectionSide? hoveredConnectionSide;
  final String? selectedConnectionId;
  final Color primaryColor, dividerColor, scaffoldBg, hintColor;
  final bool isDark;
  final bool gridVisible;
  final TextStyle? bodySmallStyle, bodyMediumStyle;
  final KnowledgeState knowledgeState;
  final double baseFontSize;
  final String? inlineEditingCardId;
  final List<CanvasGroup> groups;
  final List<CanvasLayer> layers;
  final Rect? selectionRect;
  final List<AlignmentGuide> alignmentGuides;
  final int? backgroundColorValue;
  final bool rulersVisible;
  final double animationValue;

  CanvasPainter({
    required this.cards,
    required this.connections,
    required this.autoConnections,
    required this.cameraX,
    required this.cameraY,
    required this.scale,
    required this.viewW,
    required this.viewH,
    required this.gridSize,
    required this.visibleWorldRect,
    required this.selectedCardIds,
    this.connectingFromCardId,
    required this.searchMatchedIds,
    required this.searchActiveIndex,
    this.connectingPreviewEnd,
    this.hoveredCardId,
    this.hoveredConnectionSide,
    this.selectedConnectionId,
    required this.primaryColor,
    required this.dividerColor,
    required this.scaffoldBg,
    required this.isDark,
    required this.hintColor,
    required this.gridVisible,
    this.bodySmallStyle,
    this.bodyMediumStyle,
    required this.knowledgeState,
    required this.baseFontSize,
    this.inlineEditingCardId,
    this.groups = const [],
    this.layers = const [],
    this.selectionRect,
    this.alignmentGuides = const [],
    this.backgroundColorValue,
    this.rulersVisible = false,
    this.animationValue = 0,
  });

  bool _isCardLayerVisible(CanvasCard card) {
    if (card.layerId == null) return true;
    final layer = layers.where((l) => l.id == card.layerId).firstOrNull;
    return layer?.visible ?? true;
  }

  Offset _w2s(double wx, double wy) => Offset(
    (wx - cameraX) * scale + viewW / 2,
    (wy - cameraY) * scale + viewH / 2,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColorValue != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, viewW, viewH),
        Paint()
          ..color = Color(backgroundColorValue!)
          ..style = PaintingStyle.fill,
      );
    }
    if (gridVisible) _drawGrid(canvas);
    _drawGroups(canvas);
    _drawConnections(canvas);
    _drawCards(canvas);
    _drawConnectionPoints(canvas);
    _drawAlignmentGuides(canvas);
    _drawSelectionRect(canvas);
    if (rulersVisible) _drawRulers(canvas);
  }

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

  void _drawGroups(Canvas canvas) {
    for (final group in groups) {
      if (group.cardIds.isEmpty) continue;
      final groupCards = cards
          .where((c) => group.cardIds.contains(c.id))
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

  void _drawDashedRRect(
    Canvas canvas,
    RRect rrect,
    Paint paint,
    double dash,
    double gap,
  ) {
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint, dash, gap);
  }

  void _drawConnections(Canvas canvas) {
    final cardById = <String, CanvasCard>{};
    for (final c in cards) {
      cardById[c.id] = c;
    }

    void drawLine(CanvasConnection conn, bool forceDashed) {
      final from = cardById[conn.fromCardId];
      final to = cardById[conn.toCardId];
      if (from == null || to == null) return;
      if (!_isCardLayerVisible(from) || !_isCardLayerVisible(to)) return;
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
        final midX = (fp.dx + tp.dx) / 2;
        final midY = (fp.dy + tp.dy) / 2;
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
            center: Offset(midX, midY - 8),
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
          Offset(midX - tp2.width / 2, midY - 8 - tp2.height / 2),
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
        final fp = _w2s(fromCard.center.dx, fromCard.center.dy);
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

  void _drawCards(Canvas canvas) {
    final clipRect = Rect.fromLTRB(-200, -200, viewW + 200, viewH + 200);
    final noteMap = <String, Note>{};
    for (final n in knowledgeState.notes) {
      noteMap[n.id] = n;
    }

    for (final card in cards) {
      if (!_isCardLayerVisible(card)) continue;
      if (card.type == CanvasCardType.container) {
        _drawContainerCard(canvas, card, clipRect, noteMap);
        continue;
      }
      if (card.type.isSwimlane) {
        _drawSwimlaneCard(canvas, card, clipRect, noteMap);
        continue;
      }
      if (card.type == CanvasCardType.table) {
        _drawTableCard(canvas, card, clipRect);
        continue;
      }
      if (card.type == CanvasCardType.freehand) {
        _drawFreehandCard(canvas, card, clipRect);
        continue;
      }
      if (card.type.isGeometric) {
        _drawGeometricCard(canvas, card, clipRect);
        continue;
      }

      final pos = _w2s(card.x, card.y);
      final cardRect = Rect.fromLTWH(
        pos.dx,
        pos.dy,
        card.width * scale,
        card.height * scale,
      );
      if (!clipRect.overlaps(cardRect)) continue;

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

  void _drawContainerCard(
    Canvas canvas,
    CanvasCard card,
    Rect clipRect,
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
    if (!clipRect.overlaps(containerRect)) return;

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

  void _drawConnectionPoints(Canvas canvas) {
    final dotRadius = 3.0 * scale;
    final hoverDotRadius = 5.0 * scale;
    final gap = 8.0 * scale;
    final spacing = 16.0 * scale;
    for (final card in cards) {
      if (!_isCardLayerVisible(card)) continue;
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

  @override
  bool shouldRepaint(covariant CanvasPainter old) {
    return !identical(cards, old.cards) ||
        !identical(connections, old.connections) ||
        !identical(autoConnections, old.autoConnections) ||
        cameraX != old.cameraX ||
        cameraY != old.cameraY ||
        scale != old.scale ||
        viewW != old.viewW ||
        viewH != old.viewH ||
        gridSize != old.gridSize ||
        visibleWorldRect != old.visibleWorldRect ||
        !identical(selectedCardIds, old.selectedCardIds) ||
        connectingFromCardId != old.connectingFromCardId ||
        !identical(searchMatchedIds, old.searchMatchedIds) ||
        searchActiveIndex != old.searchActiveIndex ||
        connectingPreviewEnd != old.connectingPreviewEnd ||
        selectedConnectionId != old.selectedConnectionId ||
        primaryColor != old.primaryColor ||
        dividerColor != old.dividerColor ||
        scaffoldBg != old.scaffoldBg ||
        hintColor != old.hintColor ||
        isDark != old.isDark ||
        gridVisible != old.gridVisible ||
        !identical(knowledgeState, old.knowledgeState) ||
        baseFontSize != old.baseFontSize ||
        inlineEditingCardId != old.inlineEditingCardId ||
        !identical(groups, old.groups) ||
        !identical(layers, old.layers) ||
        selectionRect != old.selectionRect ||
        !identical(alignmentGuides, old.alignmentGuides) ||
        backgroundColorValue != old.backgroundColorValue ||
        rulersVisible != old.rulersVisible ||
        animationValue != old.animationValue;
  }
}

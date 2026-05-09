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
  final String? selectedCardId, connectingFromCardId;
  final List<String> searchMatchedIds;
  final int searchActiveIndex;
  final Offset? connectingPreviewEnd;
  final Color primaryColor, dividerColor, scaffoldBg, hintColor;
  final bool isDark;
  final TextStyle? bodySmallStyle, bodyMediumStyle;
  final KnowledgeState knowledgeState;
  final double baseFontSize;

  CanvasPainter({
    required this.cards, required this.connections, required this.autoConnections,
    required this.cameraX, required this.cameraY, required this.scale,
    required this.viewW, required this.viewH, required this.gridSize,
    required this.visibleWorldRect, this.selectedCardId, this.connectingFromCardId,
    required this.searchMatchedIds, required this.searchActiveIndex,
    this.connectingPreviewEnd, required this.primaryColor, required this.dividerColor,
    required this.scaffoldBg, required this.isDark, required this.hintColor,
    this.bodySmallStyle, this.bodyMediumStyle, required this.knowledgeState,
    required this.baseFontSize,
  });

  Offset _w2s(double wx, double wy) => Offset((wx - cameraX) * scale + viewW / 2, (wy - cameraY) * scale + viewH / 2);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas);
    _drawConnections(canvas);
    _drawCards(canvas);
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()..color = dividerColor.withValues(alpha: 0.3)..strokeWidth = 0.5;
    final xs = (visibleWorldRect.left / gridSize).floor() * gridSize;
    final ys = (visibleWorldRect.top / gridSize).floor() * gridSize;
    final tl = _w2s(visibleWorldRect.left, visibleWorldRect.top);
    final br = _w2s(visibleWorldRect.right, visibleWorldRect.bottom);
    final clipRect = Rect.fromLTRB(0, 0, viewW, viewH);
    canvas.save();
    canvas.clipRect(clipRect);
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

  void _drawConnections(Canvas canvas) {
    final cardById = <String, CanvasCard>{};
    for (final c in cards) { cardById[c.id] = c; }

    void drawLine(CanvasConnection conn, bool dashed) {
      final from = cardById[conn.fromCardId];
      final to = cardById[conn.toCardId];
      if (from == null || to == null) return;
      final fromPoint = conn.fromSide.point(from.rect);
      final toPoint = conn.toSide.point(to.rect);
      final fp = _w2s(fromPoint.dx, fromPoint.dy);
      final tp = _w2s(toPoint.dx, toPoint.dy);

      final dx = (tp.dx - fp.dx).abs();
      final dy = (tp.dy - fp.dy).abs();
      final cp = math.max(dx, dy) * 0.4;
      Offset cp1, cp2;
      if (dx > dy) { final dir = tp.dx > fp.dx ? 1.0 : -1.0; cp1 = Offset(fp.dx + cp * dir, fp.dy); cp2 = Offset(tp.dx - cp * dir, tp.dy); }
      else { final dir = tp.dy > fp.dy ? 1.0 : -1.0; cp1 = Offset(fp.dx, fp.dy + cp * dir); cp2 = Offset(tp.dx, tp.dy - cp * dir); }
      final path = Path()..moveTo(fp.dx, fp.dy)..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, tp.dx, tp.dy);

      if (dashed) {
        final paint = Paint()..color = primaryColor.withValues(alpha: 0.5)..strokeWidth = 1.5..style = PaintingStyle.stroke;
        _drawDashedPath(canvas, path, paint, 4.0, 4.0);
      } else {
        final paint = Paint()..color = primaryColor..strokeWidth = 2..style = PaintingStyle.stroke;
        canvas.drawPath(path, paint);
      }
      _drawArrowHead(canvas, cp2, tp, dashed ? primaryColor.withValues(alpha: 0.5) : primaryColor);
    }

    for (final conn in connections) { drawLine(conn, conn.isAuto); }
    for (final conn in autoConnections) { drawLine(conn, true); }

    if (connectingFromCardId != null && connectingPreviewEnd != null) {
      final fromCard = cardById[connectingFromCardId];
      if (fromCard != null) {
        final fp = _w2s(fromCard.center.dx, fromCard.center.dy);
        final tp = connectingPreviewEnd!;
        final path = Path()..moveTo(fp.dx, fp.dy)..quadraticBezierTo(fp.dx + (tp.dx - fp.dx) * 0.5, fp.dy + (tp.dy - fp.dy) * 0.3, tp.dx, tp.dy);
        final paint = Paint()..color = primaryColor.withValues(alpha: 0.3)..strokeWidth = 1.5..style = PaintingStyle.stroke;
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    double dist = 0;
    bool draw = true;
    for (final metric in path.computeMetrics()) {
      while (dist < metric.length) {
        final end = math.min(dist + dash, metric.length);
        if (draw) canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dash;
        if (!draw) dist += gap;
        draw = !draw;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Color color) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const len = 8.0; const a = math.pi / 6;
    final p1 = Offset(to.dx - len * math.cos(angle - a), to.dy - len * math.sin(angle - a));
    final p2 = Offset(to.dx - len * math.cos(angle + a), to.dy - len * math.sin(angle + a));
    final path = Path()..moveTo(to.dx, to.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawCards(Canvas canvas) {
    final clipRect = Rect.fromLTRB(-200, -200, viewW + 200, viewH + 200);
    final noteMap = <String, Note>{};
    for (final n in knowledgeState.notes) { noteMap[n.id] = n; }

    for (final card in cards) {
      final pos = _w2s(card.x, card.y);
      final cardRect = Rect.fromLTWH(pos.dx, pos.dy, card.width * scale, card.height * scale);
      if (!clipRect.overlaps(cardRect)) continue;

      final isSelected = card.id == selectedCardId;
      final isConnecting = card.id == connectingFromCardId;
      final isSearchMatch = searchMatchedIds.contains(card.id);
      final isSearchActive = searchMatchedIds.isNotEmpty && searchActiveIndex < searchMatchedIds.length && card.id == searchMatchedIds[searchActiveIndex];

      Color borderColor; double borderW;
      if (isSearchActive) { borderColor = Colors.orange; borderW = 2.5; }
      else if (isSearchMatch) { borderColor = Colors.orangeAccent; borderW = 2; }
      else if (isSelected) { borderColor = primaryColor; borderW = 2; }
      else if (isConnecting) { borderColor = primaryColor.withValues(alpha: 0.6); borderW = 1; }
      else { borderColor = dividerColor; borderW = 1; }

      final cardColor = Color(card.colorValue);
      final bgColor = isDark ? cardColor.withValues(alpha: 0.12) : cardColor.withValues(alpha: 0.04);
      final headerColor = cardColor.withValues(alpha: 0.15);

      final rrect = RRect.fromRectAndRadius(cardRect, const Radius.circular(8));

      canvas.drawShadow(Path()..addRRect(rrect), Colors.black.withValues(alpha: 0.08), 8, false);
      canvas.drawRRect(rrect, Paint()..color = bgColor..style = PaintingStyle.fill);
      canvas.drawRRect(rrect, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = borderW);

      final headerRect = Rect.fromLTWH(cardRect.left, cardRect.top, cardRect.width, 28 * scale);
      final headerRRect = RRect.fromRectAndCorners(headerRect, topLeft: const Radius.circular(7), topRight: const Radius.circular(7));
      canvas.drawRRect(headerRRect, Paint()..color = headerColor..style = PaintingStyle.fill);

      Note? linkedNote;
      bool noteDeleted = false;
      if (card.noteId != null) {
        linkedNote = noteMap[card.noteId];
        if (linkedNote == null) noteDeleted = true;
      }
      final displayTitle = linkedNote != null ? linkedNote.title : noteDeleted ? '${card.title} [deleted]' : (card.title.isEmpty ? card.type.label : card.title);
      final displayContent = linkedNote != null ? (linkedNote.content.length > 500 ? '${linkedNote.content.substring(0, 500)}...' : linkedNote.content) : card.content;

      final cardFontSize = card.effectiveFontSize(baseFontSize);
      final titleStyle = (bodySmallStyle ?? const TextStyle()).copyWith(fontWeight: FontWeight.w600, fontSize: cardFontSize, color: noteDeleted ? Colors.orange : null);
      final tp = TextPainter(text: TextSpan(text: displayTitle, style: titleStyle), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '...');
      tp.layout(maxWidth: cardRect.width - 40);
      tp.paint(canvas, Offset(cardRect.left + 24, cardRect.top + (28 * scale - tp.height) / 2));

      if (displayContent.isNotEmpty) {
        final contentStyle = (bodySmallStyle ?? const TextStyle()).copyWith(fontSize: cardFontSize * 1.06, color: displayContent == 'Empty note' ? hintColor : null);
        final cp = TextPainter(text: TextSpan(text: displayContent, style: contentStyle), textDirection: TextDirection.ltr, maxLines: 10, ellipsis: '...');
        cp.layout(maxWidth: cardRect.width - 16);
        cp.paint(canvas, Offset(cardRect.left + 8, cardRect.top + 28 * scale + 8));
      }

      if (displayContent.isEmpty && linkedNote == null) {
        final emptyTp = TextPainter(text: TextSpan(text: card.type == CanvasCardType.note ? 'Empty note' : 'Type something...', style: TextStyle(color: hintColor, fontSize: cardFontSize * 1.06)), textDirection: TextDirection.ltr);
        emptyTp.layout(maxWidth: cardRect.width - 16);
        emptyTp.paint(canvas, Offset(cardRect.left + 8, cardRect.top + 28 * scale + 8));
      }

      if (isSelected) {
        final resizeHandle = Rect.fromLTWH(cardRect.right - 12, cardRect.bottom - 12, 12, 12);
        canvas.drawRect(resizeHandle, Paint()..color = primaryColor.withValues(alpha: 0.3));
      }
    }
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
        selectedCardId != old.selectedCardId ||
        connectingFromCardId != old.connectingFromCardId ||
        !identical(searchMatchedIds, old.searchMatchedIds) ||
        searchActiveIndex != old.searchActiveIndex ||
        connectingPreviewEnd != old.connectingPreviewEnd ||
        primaryColor != old.primaryColor ||
        dividerColor != old.dividerColor ||
        scaffoldBg != old.scaffoldBg ||
        hintColor != old.hintColor ||
        isDark != old.isDark ||
        !identical(knowledgeState, old.knowledgeState) ||
        baseFontSize != old.baseFontSize;
  }
}

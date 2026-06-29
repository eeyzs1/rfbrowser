// ignore_for_file: unused_element
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../data/models/canvas_model.dart';
import '../../data/models/note.dart';
import '../../services/knowledge_service.dart';

part 'canvas_painter/painter_connections.dart';
part 'canvas_painter/painter_connection_paths.dart';
part 'canvas_painter/painter_cards.dart';
part 'canvas_painter/painter_cards_special.dart';
part 'canvas_painter/painter_overlays.dart';
part 'canvas_painter/painter_shapes.dart';
part 'canvas_painter/painter_swimlane.dart';
part 'canvas_painter/painter_special.dart';
part 'canvas_painter/painter_effects.dart';

abstract class _CanvasPainterBase extends CustomPainter {
  late final List<CanvasCard> cards;
  late final List<CanvasConnection> connections;
  late final List<CanvasConnection> autoConnections;
  late final double cameraX, cameraY, scale, viewW, viewH, gridSize;
  late final Rect visibleWorldRect;
  late final List<String> selectedCardIds;
  late final String? connectingFromCardId;
  late final ConnectionSide? connectingFromSide;
  late final double connectingFromSideOffset;
  late final List<String> searchMatchedIds;
  late final int searchActiveIndex;
  late final Offset? connectingPreviewEnd;
  late final String? hoveredCardId;
  late final ConnectionSide? hoveredConnectionSide;
  late final String? selectedConnectionId;
  late final Color primaryColor, dividerColor, scaffoldBg, hintColor;
  late final bool isDark;
  late final bool gridVisible;
  late final TextStyle? bodySmallStyle, bodyMediumStyle;
  late final KnowledgeState knowledgeState;
  late final double baseFontSize;
  late final String? inlineEditingCardId;
  late final List<CanvasGroup> groups;
  late final List<CanvasLayer> layers;
  late final Rect? selectionRect;
  late final List<AlignmentGuide> alignmentGuides;
  late final String? selectedLayerId;
  late final int? backgroundColorValue;
  late final bool rulersVisible;
  late final double animationValue;
  late final Map<String, ui.Image> cardImageCache;

  // Lazily-computed lookup maps. Built once per painter instance (the painter
  // is recreated when shouldRepaint detects a change). Avoids rebuilding these
  // maps on every paint() call within the same instance.
  late final Map<String, CanvasCard> _cardByIdMap = {
    for (final c in cards) c.id: c,
  };
  late final Map<String, Note> _noteMap = {
    for (final n in knowledgeState.notes) n.id: n,
  };

  _CanvasPainterBase({
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
    this.connectingFromSide,
    this.connectingFromSideOffset = 0.5,
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
    this.selectedLayerId,
    this.cardImageCache = const {},
  });

  bool _isCardInSelectedLayer(CanvasCard card) {
    if (selectedLayerId == null) return true;
    if (selectedLayerId == CanvasData.unassignedSentinel) {
      return card.layerId == null;
    }
    return card.layerId == selectedLayerId;
  }

  Offset _w2s(double wx, double wy) => Offset(
    (wx - cameraX) * scale + viewW / 2,
    (wy - cameraY) * scale + viewH / 2,
  );

  Offset _pathMidpoint(Path path) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return Offset.zero;
    double totalLength = 0;
    for (final m in metrics) {
      totalLength += m.length;
    }
    if (totalLength <= 0) return Offset.zero;
    final target = totalLength / 2;
    double accumulated = 0;
    for (final m in metrics) {
      if (accumulated + m.length >= target) {
        final t = m.getTangentForOffset(target - accumulated);
        return t?.position ?? Offset.zero;
      }
      accumulated += m.length;
    }
    final last = metrics.last;
    final t = last.getTangentForOffset(last.length);
    return t?.position ?? Offset.zero;
  }

  void _drawGrid(Canvas canvas);
  void _drawGroups(Canvas canvas);
  void _drawDashedRRect(
    Canvas canvas,
    RRect rrect,
    Paint paint,
    double dashWidth,
    double dashGap,
  );
  void _drawConnections(Canvas canvas);
  Path _buildOrthogonalPath(
    Offset fp,
    Offset tp,
    ConnectionSide fromSide,
    ConnectionSide toSide, [
    List<Offset> waypoints,
  ]);
  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap, [
    double offset,
  ]);
  void _drawArrowHead(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    ArrowStyle style, [
    double arrowSize = 8.0,
  ]);
  void _drawCards(Canvas canvas);
  void _drawContainerCard(
    Canvas canvas,
    CanvasCard card,
    Map<String, Note> noteMap,
  );
  void _drawImageCard(Canvas canvas, CanvasCard card);
  void _drawAlignmentGuides(Canvas canvas);
  void _drawSelectionRect(Canvas canvas);
  void _drawCardTypeIcon(
    Canvas canvas,
    CanvasCardType type,
    Offset pos,
    double size,
    Paint paint,
  );
  Path _buildGeometricPath(CanvasCard card, Rect cardRect);
  void _drawGeometricCard(Canvas canvas, CanvasCard card);
  void _drawSwimlaneCard(
    Canvas canvas,
    CanvasCard card,
    Map<String, Note> noteMap,
  );
  void _drawLineJumps(
    Canvas canvas,
    Path path,
    CanvasConnectionStyle style,
    String currentConnId,
  );
  void _drawTableCard(Canvas canvas, CanvasCard card);
  void _drawFreehandCard(Canvas canvas, CanvasCard card);
  void _drawConnectionPoints(Canvas canvas);
  void _drawFlowAnimation(
    Canvas canvas,
    Path path,
    CanvasConnectionStyle style,
  );
  void _drawRulers(Canvas canvas);
}

class CanvasPainter extends _CanvasPainterBase
    with
        _CanvasConnectionPainterMixin,
        _CanvasConnectionPathMixin,
        _CanvasCardPainterMixin,
        _CanvasCardPainterSpecialMixin,
        _CanvasOverlayPainterMixin,
        _CanvasShapePainterMixin,
        _CanvasSwimlanePainterMixin,
        _CanvasSpecialPainterMixin,
        _CanvasEffectsPainterMixin {
  CanvasPainter({
    required super.cards,
    required super.connections,
    required super.autoConnections,
    required super.cameraX,
    required super.cameraY,
    required super.scale,
    required super.viewW,
    required super.viewH,
    required super.gridSize,
    required super.visibleWorldRect,
    required super.selectedCardIds,
    super.connectingFromCardId,
    super.connectingFromSide,
    super.connectingFromSideOffset,
    required super.searchMatchedIds,
    required super.searchActiveIndex,
    super.connectingPreviewEnd,
    super.hoveredCardId,
    super.hoveredConnectionSide,
    super.selectedConnectionId,
    required super.primaryColor,
    required super.dividerColor,
    required super.scaffoldBg,
    required super.isDark,
    required super.hintColor,
    required super.gridVisible,
    super.bodySmallStyle,
    super.bodyMediumStyle,
    required super.knowledgeState,
    required super.baseFontSize,
    super.inlineEditingCardId,
    super.groups,
    super.layers,
    super.selectionRect,
    super.alignmentGuides,
    super.backgroundColorValue,
    super.rulersVisible,
    super.animationValue,
    super.selectedLayerId,
    super.cardImageCache,
  });

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
        connectingFromSide != old.connectingFromSide ||
        connectingFromSideOffset != old.connectingFromSideOffset ||
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
        selectedLayerId != old.selectedLayerId ||
        backgroundColorValue != old.backgroundColorValue ||
        rulersVisible != old.rulersVisible ||
        animationValue != old.animationValue;
  }
}

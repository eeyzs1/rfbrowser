import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/canvas_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/settings_service.dart';
import '../../data/models/canvas_model.dart';
import '../../data/models/note.dart';
import '../../data/stores/vault_store.dart';
import '../../core/link/link_resolver.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/canvas_painter.dart';

enum _ResizeEdge { none, right, bottom, corner }

class _CameraNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class CanvasView extends ConsumerStatefulWidget {
  const CanvasView({super.key});

  @override
  ConsumerState<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends ConsumerState<CanvasView> with TickerProviderStateMixin {
  late AnimationController _animController;
  final _CameraNotifier _cameraNotifier = _CameraNotifier();
  bool _isFreehandDrawing = false;
  String? _freehandCardId;
  List<Offset> _freehandPoints = [];
  double _cameraX = 0;
  double _cameraY = 0;
  double _scale = 1.0;

  List<String> get _selectedCardIds => ref.read(canvasProvider).selectedCardIds;
  String? get _inlineEditingCardId => ref.read(canvasProvider).inlineEditingCardId;
  String? _connectingFromCardId;
  String? _draggingCardId;
  _ResizeEdge _resizeEdge = _ResizeEdge.none;
  Offset? _connectingPreviewEnd;
  ConnectionSide? _connectingFromSide;
  double _connectingFromSideOffset = 0.5;
  ConnectionSide? _hoveredConnectionSide;
  bool _hoveringConnectionLine = false;
  bool _isDraggingFromPort = false;
  bool _isClickingConnection = false;
  String? _clickedConnectionId;

  String? _draggingWaypointConnId;
  int _draggingWaypointIndex = -1;

  _ResizeEdge _hoverResizeEdge = _ResizeEdge.none;
  String? _hoverCardId;

  CanvasCard? _resizeStartCard;
  Offset? _resizeStartLocalPoint;
  CanvasCard? _dragStartCard;
  Offset? _dragStartLocalPoint;

  bool _styleBrushMode = false;
  CanvasCardStyle? _copiedStyle;

  late TextEditingController _inlineTitleCtrl;
  late TextEditingController _inlineContentCtrl;
  FocusNode? _inlineTitleFocus;
  FocusNode? _inlineContentFocus;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _searchMatchedIds = [];
  int _searchActiveIndex = 0;
  Timer? _searchDebounceTimer;
  bool _searchVisible = false;

  Offset? _lastLocalFocalPoint;
  double? _lastScale;

  List<CanvasConnection> _cachedAutoConnections = [];
  List<CanvasCard>? _lastCards;
  List<Note>? _lastNotes;
  bool _lastAutoEnabled = false;
  LinkResolver? _lastLinkResolver;

  bool _isBoxSelecting = false;
  Offset? _boxSelectStart;
  Rect? _selectionRect;
  List<AlignmentGuide> _alignmentGuides = [];
  Map<String, (double, double)> _multiDragStarts = {};
  bool _altKeyPressed = false;

  final GlobalKey _canvasPaintKey = GlobalKey();

  static const double _gridSize = 20;
  static const double _minScale = 0.05;
  static const double _maxScale = 8.0;
  static const double _toolbarHeight = 36;
  static const double _resizeHandleSize = 20;
  static const double _edgeHitWidth = 14;
  static const double _alignmentThreshold = 5.0;

  double _canvasW = 800;
  double _canvasH = 600;
  double get _viewW => _canvasW;
  double get _viewH => _canvasH;

  static const List<Color> _cardColorPresets = [
    Color(0xFFFFFFFF),
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFFFF3E0),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFE0F7FA),
    Color(0xFFFFEBEE),
    Color(0xFFF1F8E9),
    Color(0xFFEDE7F6),
  ];

  @override
  void initState() {
    super.initState();
    _inlineTitleCtrl = TextEditingController();
    _inlineContentCtrl = TextEditingController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCanvas());
  }

  Future<void> _initCanvas() async {
    final notifier = ref.read(canvasProvider.notifier);
    await notifier.initialize();
    if (mounted) _centerOrFitView();
  }

  void _centerOrFitView() {
    final cards = ref.read(canvasProvider).cards;
    if (cards.isEmpty) {
      _cameraX = 0; _cameraY = 0; _scale = 1.0;
      _cameraNotifier.notify();
    } else {
      _fitToContent();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraNotifier.dispose();
    _inlineTitleCtrl.dispose();
    _inlineContentCtrl.dispose();
    _inlineTitleFocus?.dispose();
    _inlineContentFocus?.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _startInlineEditing(String cardId) {
    final card = ref.read(canvasProvider.notifier).cardById(cardId);
    if (card == null) return;
    _inlineTitleFocus?.dispose();
    _inlineContentFocus?.dispose();
    _inlineTitleFocus = FocusNode();
    _inlineContentFocus = FocusNode();
    _inlineTitleCtrl.text = card.title;
    _inlineContentCtrl.text = card.content;
    ref.read(canvasProvider.notifier).startInlineEditing(cardId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inlineTitleFocus?.requestFocus();
    });
  }

  void _finishInlineEditing() {
    final editingId = _inlineEditingCardId;
    if (editingId == null) return;
    final card = ref.read(canvasProvider.notifier).cardById(editingId);
    if (card != null) {
      final newTitle = _inlineTitleCtrl.text.trim();
      final newContent = _inlineContentCtrl.text.trim();
      if (newTitle != card.title || newContent != card.content) {
        ref.read(canvasProvider.notifier).updateCard(card.copyWith(
          title: newTitle,
          content: newContent,
        ));
      }
    }
    ref.read(canvasProvider.notifier).finishInlineEditing();
  }

  Offset _screenToWorld(Offset screenPos) {
    return Offset(
      (screenPos.dx - _viewW / 2) / _scale + _cameraX,
      (screenPos.dy - _viewH / 2) / _scale + _cameraY,
    );
  }

  double _snapToGrid(double value) {
    final settings = ref.read(canvasProvider).settings;
    if (!settings.snapToGrid) return value;
    return (value / _gridSize).round() * _gridSize;
  }

  _ResizeEdge _hitTestResizeHandle(Offset worldPos, CanvasCard card) {
    final edgeW = _edgeHitWidth / _scale;
    final cornerSize = _resizeHandleSize / _scale;

    final cornerRect = Rect.fromCenter(
      center: Offset(card.x + card.width, card.y + card.height),
      width: cornerSize * 2,
      height: cornerSize * 2,
    );
    if (cornerRect.contains(worldPos)) return _ResizeEdge.corner;

    final rightEdge = Rect.fromLTWH(
      card.x + card.width - edgeW,
      card.y,
      edgeW * 2,
      card.height,
    );
    if (rightEdge.contains(worldPos)) return _ResizeEdge.right;

    final bottomEdge = Rect.fromLTWH(
      card.x,
      card.y + card.height - edgeW,
      card.width,
      edgeW * 2,
    );
    if (bottomEdge.contains(worldPos)) return _ResizeEdge.bottom;

    return _ResizeEdge.none;
  }

  CanvasCard? _hitTestCardWithResize(Offset worldPos) {
    final cards = ref.read(canvasProvider).cards;
    final edgeW = _edgeHitWidth / _scale;
    final cornerSize = _resizeHandleSize / _scale;
    final expand = math.max(edgeW, cornerSize);
    for (final card in cards.reversed) {
      final expandedRect = Rect.fromLTWH(
        card.x - expand,
        card.y - expand,
        card.width + expand * 2,
        card.height + expand * 2,
      );
      if (expandedRect.contains(worldPos)) return card;
    }
    return null;
  }

  CanvasCard? _hitTestCard(Offset worldPos) {
    final cards = ref.read(canvasProvider).cards;
    for (final card in cards.reversed) {
      if (card.rect.contains(worldPos)) return card;
    }
    return null;
  }

  (String, int)? _hitTestWaypoint(Offset worldPos) {
    final canvasData = ref.read(canvasProvider);
    for (final conn in canvasData.connections) {
      if (conn.waypoints.isEmpty) continue;
      final connStyle = conn.style ?? CanvasConnectionStyle.defaults;
      final hitRadius = (connStyle.waypointSize + 4.0) / _scale;
      for (int i = 0; i < conn.waypoints.length; i++) {
        final wp = conn.waypoints[i];
        final dist = math.sqrt(math.pow(worldPos.dx - wp.dx, 2) + math.pow(worldPos.dy - wp.dy, 2));
        if (dist <= hitRadius) return (conn.id, i);
      }
    }
    return null;
  }

  (String, double)? _hitTestConnectionLine(Offset worldPos) {
    final canvasData = ref.read(canvasProvider);
    final hitRadius = 12.0 / _scale;
    final hits = <(String, double)>[];
    for (final conn in canvasData.connections) {
      final from = ref.read(canvasProvider.notifier).cardById(conn.fromCardId);
      final to = ref.read(canvasProvider.notifier).cardById(conn.toCardId);
      if (from == null || to == null) continue;
      final fromPoint = conn.fromSide.point(from.rect, conn.fromSideOffset);
      final toPoint = conn.toSide.point(to.rect, conn.toSideOffset);
      final points = [fromPoint, ...conn.waypoints, toPoint];
      for (int i = 0; i < points.length - 1; i++) {
        final dist = _pointToSegmentDist(worldPos, points[i], points[i + 1]);
        if (dist <= hitRadius) {
          hits.add((conn.id, dist));
          break;
        }
      }
    }
    if (hits.isEmpty) return null;
    hits.sort((a, b) => a.$2.compareTo(b.$2));
    final currentId = canvasData.selectedConnectionId;
    if (currentId != null) {
      final idx = hits.indexWhere((h) => h.$1 == currentId);
      if (idx >= 0 && idx < hits.length - 1) return hits[idx + 1];
    }
    return hits.first;
  }

  (String, ConnectionSide, double)? _hitTestConnectionPoint(Offset worldPos) {
    final hitRadius = 10.0 / _scale;
    final gap = 8.0 / _scale;
    final spacing = 16.0 / _scale;
    final cards = ref.read(canvasProvider).cards;
    for (final card in cards.reversed) {
      if (card.type == CanvasCardType.freehand) continue;
      final w = card.width;
      final h = card.height;
      final topY = card.y - gap;
      final bottomY = card.y + h + gap;
      final leftX = card.x - gap;
      final rightX = card.x + w + gap;

      final topCount = (w / spacing).floor().clamp(2, 20);
      for (int i = 0; i <= topCount; i++) {
        final x = card.x + w * i / topCount;
        final dist = math.sqrt(math.pow(worldPos.dx - x, 2) + math.pow(worldPos.dy - topY, 2));
        if (dist <= hitRadius) return (card.id, ConnectionSide.top, i / topCount);
      }

      final bottomCount = (w / spacing).floor().clamp(2, 20);
      for (int i = 0; i <= bottomCount; i++) {
        final x = card.x + w * i / bottomCount;
        final dist = math.sqrt(math.pow(worldPos.dx - x, 2) + math.pow(worldPos.dy - bottomY, 2));
        if (dist <= hitRadius) return (card.id, ConnectionSide.bottom, i / bottomCount);
      }

      final leftCount = (h / spacing).floor().clamp(2, 20);
      for (int i = 1; i < leftCount; i++) {
        final y = card.y + h * i / leftCount;
        final dist = math.sqrt(math.pow(worldPos.dx - leftX, 2) + math.pow(worldPos.dy - y, 2));
        if (dist <= hitRadius) return (card.id, ConnectionSide.left, i / leftCount);
      }

      final rightCount = (h / spacing).floor().clamp(2, 20);
      for (int i = 1; i < rightCount; i++) {
        final y = card.y + h * i / rightCount;
        final dist = math.sqrt(math.pow(worldPos.dx - rightX, 2) + math.pow(worldPos.dy - y, 2));
        if (dist <= hitRadius) return (card.id, ConnectionSide.right, i / rightCount);
      }
    }
    return null;
  }

  (Offset, int) _snapWaypointToConnection(String connId, Offset worldPos) {
    final canvasData = ref.read(canvasProvider);
    final conn = canvasData.connections.where((c) => c.id == connId).firstOrNull;
    if (conn == null) return (worldPos, 0);
    final from = ref.read(canvasProvider.notifier).cardById(conn.fromCardId);
    final to = ref.read(canvasProvider.notifier).cardById(conn.toCardId);
    if (from == null || to == null) return (worldPos, 0);
    final fromPoint = conn.fromSide.point(from.rect, conn.fromSideOffset);
    final toPoint = conn.toSide.point(to.rect, conn.toSideOffset);
    final points = [fromPoint, ...conn.waypoints, toPoint];
    Offset? closest;
    double closestDist = double.infinity;
    int insertIndex = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final proj = _projectPointOnSegment(worldPos, points[i], points[i + 1]);
      final dist = (worldPos - proj).distance;
      if (dist < closestDist) {
        closestDist = dist;
        closest = proj;
        insertIndex = i;
      }
    }
    return (closest ?? worldPos, insertIndex);
  }

  Offset _projectPointOnSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return a;
    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return Offset(a.dx + t * dx, a.dy + t * dy);
  }

  double _pointToSegmentDist(Offset p, Offset a, Offset b) {
    final proj = _projectPointOnSegment(p, a, b);
    return (p - proj).distance;
  }

  List<AlignmentGuide> _computeAlignmentGuides(CanvasCard draggedCard, List<CanvasCard> allCards) {
    if (_altKeyPressed) return [];
    final guides = <AlignmentGuide>[];
    final threshold = _alignmentThreshold;
    final vr = Rect.fromLTWH(
      _cameraX - _viewW / 2 / _scale,
      _cameraY - _viewH / 2 / _scale,
      _viewW / _scale,
      _viewH / _scale,
    );

    for (final other in allCards) {
      if (other.id == draggedCard.id) continue;
      if (!vr.overlaps(other.rect.inflate(50))) continue;

      final dCenterX = (draggedCard.center.dx - other.center.dx).abs();
      if (dCenterX < threshold) {
        final x = other.center.dx;
        guides.add(AlignmentGuide(
          start: Offset(x, vr.top),
          end: Offset(x, vr.bottom),
          type: AlignmentGuideType.centerVertical,
        ));
      }

      final dCenterY = (draggedCard.center.dy - other.center.dy).abs();
      if (dCenterY < threshold) {
        final y = other.center.dy;
        guides.add(AlignmentGuide(
          start: Offset(vr.left, y),
          end: Offset(vr.right, y),
          type: AlignmentGuideType.centerHorizontal,
        ));
      }

      final dLeft = (draggedCard.x - other.x).abs();
      if (dLeft < threshold) {
        final x = other.x;
        guides.add(AlignmentGuide(
          start: Offset(x, vr.top),
          end: Offset(x, vr.bottom),
          type: AlignmentGuideType.leftEdge,
        ));
      }

      final dRight = ((draggedCard.x + draggedCard.width) - (other.x + other.width)).abs();
      if (dRight < threshold) {
        final x = other.x + other.width;
        guides.add(AlignmentGuide(
          start: Offset(x, vr.top),
          end: Offset(x, vr.bottom),
          type: AlignmentGuideType.rightEdge,
        ));
      }

      final dTop = (draggedCard.y - other.y).abs();
      if (dTop < threshold) {
        final y = other.y;
        guides.add(AlignmentGuide(
          start: Offset(vr.left, y),
          end: Offset(vr.right, y),
          type: AlignmentGuideType.topEdge,
        ));
      }

      final dBottom = ((draggedCard.y + draggedCard.height) - (other.y + other.height)).abs();
      if (dBottom < threshold) {
        final y = other.y + other.height;
        guides.add(AlignmentGuide(
          start: Offset(vr.left, y),
          end: Offset(vr.right, y),
          type: AlignmentGuideType.bottomEdge,
        ));
      }
    }
    return guides;
  }

  double? _getSnapOffset(CanvasCard draggedCard, List<CanvasCard> allCards) {
    if (_altKeyPressed) return null;
    final threshold = _alignmentThreshold;
    for (final other in allCards) {
      if (other.id == draggedCard.id) continue;
      final dCenterX = (draggedCard.center.dx - other.center.dx).abs();
      if (dCenterX < threshold) return other.center.dx - draggedCard.width / 2 - draggedCard.x;
      final dLeft = (draggedCard.x - other.x).abs();
      if (dLeft < threshold) return other.x - draggedCard.x;
      final dRight = ((draggedCard.x + draggedCard.width) - (other.x + other.width)).abs();
      if (dRight < threshold) return (other.x + other.width - draggedCard.width) - draggedCard.x;
    }
    return null;
  }

  double? _getSnapOffsetY(CanvasCard draggedCard, List<CanvasCard> allCards) {
    if (_altKeyPressed) return null;
    final threshold = _alignmentThreshold;
    for (final other in allCards) {
      if (other.id == draggedCard.id) continue;
      final dCenterY = (draggedCard.center.dy - other.center.dy).abs();
      if (dCenterY < threshold) return other.center.dy - draggedCard.height / 2 - draggedCard.y;
      final dTop = (draggedCard.y - other.y).abs();
      if (dTop < threshold) return other.y - draggedCard.y;
      final dBottom = ((draggedCard.y + draggedCard.height) - (other.y + other.height)).abs();
      if (dBottom < threshold) return (other.y + other.height - draggedCard.height) - draggedCard.y;
    }
    return null;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_inlineEditingCardId != null) {
      _finishInlineEditing();
    }
    _lastLocalFocalPoint = details.localFocalPoint;
    _lastScale = _scale;
    final worldPos = _screenToWorld(details.localFocalPoint);

    final selectedIds = _selectedCardIds;
    if (selectedIds.length == 1) {
      final selectedCard = ref.read(canvasProvider.notifier).cardById(selectedIds.first);
      if (selectedCard != null) {
        final edge = _hitTestResizeHandle(worldPos, selectedCard);
        if (edge != _ResizeEdge.none) {
          setState(() {
            _resizeEdge = edge;
            _draggingCardId = null;
          });
          _resizeStartCard = selectedCard;
          _resizeStartLocalPoint = details.localFocalPoint;
          return;
        }
      }
    }

    final hitCard = _hitTestCardWithResize(worldPos);
    if (hitCard != null) {
      final edge = _hitTestResizeHandle(worldPos, hitCard);
      if (edge != _ResizeEdge.none) {
        if (ref.read(canvasProvider.notifier).isLayerLocked(hitCard.id)) return;
        ref.read(canvasProvider.notifier).selectCard(hitCard.id);
        setState(() {
          _resizeEdge = edge;
          _draggingCardId = null;
        });
        _resizeStartCard = hitCard;
        _resizeStartLocalPoint = details.localFocalPoint;
        return;
      }
    }

    final hit = _hitTestCard(worldPos);
    _resizeEdge = _ResizeEdge.none;
    if (hit != null) {
      if (ref.read(canvasProvider.notifier).isLayerLocked(hit.id)) {
        return;
      }
      final isShiftHeld = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
          HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
      if (isShiftHeld) {
        ref.read(canvasProvider.notifier).selectCard(hit.id, additive: true);
        _draggingCardId = hit.id;
        _dragStartCard = hit;
        _dragStartLocalPoint = details.localFocalPoint;
        _multiDragStarts = {};
        for (final id in _selectedCardIds) {
          final c = ref.read(canvasProvider.notifier).cardById(id);
          if (c != null) _multiDragStarts[id] = (c.x, c.y);
        }
      } else if (_selectedCardIds.contains(hit.id)) {
        _draggingCardId = hit.id;
        _dragStartCard = hit;
        _dragStartLocalPoint = details.localFocalPoint;
        _multiDragStarts = {};
        for (final id in _selectedCardIds) {
          final c = ref.read(canvasProvider.notifier).cardById(id);
          if (c != null) _multiDragStarts[id] = (c.x, c.y);
        }
      } else {
        ref.read(canvasProvider.notifier).selectCard(hit.id);
        _draggingCardId = hit.id;
        _dragStartCard = hit;
        _dragStartLocalPoint = details.localFocalPoint;
        _multiDragStarts = {hit.id: (hit.x, hit.y)};
      }
      return;
    }

    final portHit = _hitTestConnectionPoint(worldPos);
    if (portHit != null) {
      if (ref.read(canvasProvider.notifier).isLayerLocked(portHit.$1)) return;
      setState(() {
        _connectingFromCardId = portHit.$1;
        _connectingFromSide = portHit.$2;
        _connectingFromSideOffset = portHit.$3;
        _isDraggingFromPort = true;
        _connectingPreviewEnd = _w2s(worldPos.dx, worldPos.dy);
        ref.read(canvasProvider.notifier).selectConnection(null);
      });
      return;
    }
    final wpHit = _hitTestWaypoint(worldPos);
    if (wpHit != null) {
      _draggingWaypointConnId = wpHit.$1;
      _draggingWaypointIndex = wpHit.$2;
    } else {
      final connLineHit = _hitTestConnectionLine(worldPos);
      if (connLineHit != null) {
        _isClickingConnection = true;
        _clickedConnectionId = connLineHit.$1;
        return;
      }
      final isShiftHeld = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
          HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
      if (isShiftHeld) {
        _isBoxSelecting = true;
        _boxSelectStart = worldPos;
        _selectionRect = null;
      }
      _draggingCardId = null;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_resizeEdge != _ResizeEdge.none && _selectedCardIds.length == 1 && details.pointerCount == 1) {
      final startCard = _resizeStartCard;
      final startPoint = _resizeStartLocalPoint;
      if (startCard != null && startPoint != null) {
        final totalDx = (details.localFocalPoint.dx - startPoint.dx) / _scale;
        final totalDy = (details.localFocalPoint.dy - startPoint.dy) / _scale;
        double newWidth = startCard.width;
        double newHeight = startCard.height;

        if (_resizeEdge == _ResizeEdge.corner || _resizeEdge == _ResizeEdge.right) {
          newWidth = math.max(100.0, startCard.width + totalDx);
        }
        if (_resizeEdge == _ResizeEdge.corner || _resizeEdge == _ResizeEdge.bottom) {
          newHeight = math.max(80.0, startCard.height + totalDy);
        }

        ref.read(canvasProvider.notifier).updateCardInMemory(
          startCard.copyWith(
            width: _snapToGrid(newWidth),
            height: _snapToGrid(newHeight),
          ),
        );
      }
    } else if (_draggingCardId != null && details.pointerCount == 1) {
      final startCard = _dragStartCard;
      final startPoint = _dragStartLocalPoint;
      if (startCard != null && startPoint != null) {
        final totalDx = (details.localFocalPoint.dx - startPoint.dx) / _scale;
        final totalDy = (details.localFocalPoint.dy - startPoint.dy) / _scale;
        final newX = _snapToGrid(startCard.x + totalDx);
        final newY = _snapToGrid(startCard.y + totalDy);

        final tempCard = startCard.copyWith(x: newX, y: newY);
        final guides = _computeAlignmentGuides(tempCard, ref.read(canvasProvider).cards);
        var snapX = newX;
        var snapY = newY;
        final snapOffX = _getSnapOffset(tempCard, ref.read(canvasProvider).cards);
        final snapOffY = _getSnapOffsetY(tempCard, ref.read(canvasProvider).cards);
        if (snapOffX != null) snapX = newX + snapOffX;
        if (snapOffY != null) snapY = newY + snapOffY;

        if (_selectedCardIds.length > 1 && _multiDragStarts.isNotEmpty) {
          final baseDx = snapX - startCard.x;
          final baseDy = snapY - startCard.y;
          final moves = <String, (double, double)>{};
          for (final entry in _multiDragStarts.entries) {
            moves[entry.key] = (entry.value.$1 + baseDx, entry.value.$2 + baseDy);
          }
          ref.read(canvasProvider.notifier).batchMoveCards(moves);
        } else {
          ref.read(canvasProvider.notifier).updateCardInMemory(
            startCard.copyWith(x: snapX, y: snapY),
          );
        }
        setState(() => _alignmentGuides = guides);
      }
    } else if (_isFreehandDrawing && _freehandCardId != null && details.pointerCount == 1) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      _freehandPoints.add(worldPos);
      ref.read(canvasProvider.notifier).setFreehandPoints(_freehandCardId!, List.from(_freehandPoints));
    } else if (_isDraggingFromPort && _connectingFromCardId != null && details.pointerCount == 1) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      setState(() {
        _connectingPreviewEnd = _w2s(worldPos.dx, worldPos.dy);
        final portHit = _hitTestConnectionPoint(worldPos);
        _hoveredConnectionSide = (portHit != null && portHit.$1 != _connectingFromCardId) ? portHit.$2 : null;
        _hoverCardId = (portHit != null && portHit.$1 != _connectingFromCardId) ? portHit.$1 : null;
      });
    } else if (_draggingWaypointConnId != null && _draggingWaypointIndex >= 0 && details.pointerCount == 1) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      ref.read(canvasProvider.notifier).moveWaypoint(
        _draggingWaypointConnId!,
        _draggingWaypointIndex,
        Offset(_snapToGrid(worldPos.dx), _snapToGrid(worldPos.dy)),
      );
    } else if (_isBoxSelecting && _boxSelectStart != null && details.pointerCount == 1) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      final left = math.min(_boxSelectStart!.dx, worldPos.dx);
      final top = math.min(_boxSelectStart!.dy, worldPos.dy);
      final right = math.max(_boxSelectStart!.dx, worldPos.dx);
      final bottom = math.max(_boxSelectStart!.dy, worldPos.dy);
      setState(() {
        _selectionRect = Rect.fromLTRB(left, top, right, bottom);
      });
    } else if (details.pointerCount == 1 && !_isBoxSelecting && !_isClickingConnection) {
      final currentLocal = details.localFocalPoint;
      final lastLocal = _lastLocalFocalPoint ?? currentLocal;
      _cameraX -= (currentLocal.dx - lastLocal.dx) / _scale;
      _cameraY -= (currentLocal.dy - lastLocal.dy) / _scale;
      _cameraNotifier.notify();
    } else if (details.pointerCount == 2 && _lastScale != null) {
      final newScale = (_lastScale! * details.scale).clamp(_minScale, _maxScale);
      final focalWorld = _screenToWorld(details.localFocalPoint);
      _cameraX = focalWorld.dx - (details.localFocalPoint.dx - _viewW / 2) / newScale;
      _cameraY = focalWorld.dy - (details.localFocalPoint.dy - _viewH / 2) / newScale;
      _scale = newScale;
      _cameraNotifier.notify();
      _lastScale = _scale;
    }
    _lastLocalFocalPoint = details.localFocalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isBoxSelecting && _selectionRect != null) {
      final cards = ref.read(canvasProvider).cards;
      final matchedIds = <String>[];
      for (final card in cards) {
        if (_selectionRect!.overlaps(card.rect)) {
          matchedIds.add(card.id);
        }
      }
      ref.read(canvasProvider.notifier).selectCards(matchedIds);
      setState(() {
        _isBoxSelecting = false;
        _selectionRect = null;
        _boxSelectStart = null;
      });
    } else if (_draggingCardId != null) {
      ref.read(canvasProvider.notifier).persist();
      _draggingCardId = null;
      _dragStartCard = null;
      _dragStartLocalPoint = null;
      _multiDragStarts = {};
      setState(() => _alignmentGuides = []);
    }
    if (_resizeEdge != _ResizeEdge.none) {
      ref.read(canvasProvider.notifier).persist();
      _resizeEdge = _ResizeEdge.none;
      _resizeStartCard = null;
      _resizeStartLocalPoint = null;
    }
    if (_draggingWaypointConnId != null) {
      ref.read(canvasProvider.notifier).persist();
      _draggingWaypointConnId = null;
      _draggingWaypointIndex = -1;
    }
    if (_isDraggingFromPort && _connectingFromCardId != null) {
      if (_lastLocalFocalPoint != null) {
        final worldPos = _screenToWorld(_lastLocalFocalPoint!);
        final portHit = _hitTestConnectionPoint(worldPos);
        if (portHit != null && portHit.$1 != _connectingFromCardId) {
          _createConnectionWithSides(_connectingFromCardId!, portHit.$1, _connectingFromSide, portHit.$2, _connectingFromSideOffset, portHit.$3);
        }
      }
      setState(() {
        _isDraggingFromPort = false;
        _connectingFromCardId = null;
        _connectingFromSide = null;
        _connectingFromSideOffset = 0.5;
        _connectingPreviewEnd = null;
        _hoveredConnectionSide = null;
        _hoverCardId = null;
      });
    }
    if (_isClickingConnection && _clickedConnectionId != null) {
      ref.read(canvasProvider.notifier).selectConnection(_clickedConnectionId);
    }
    _isClickingConnection = false;
    _clickedConnectionId = null;
    _lastLocalFocalPoint = null;
    _lastScale = null;
  }

  void _onTapUp(TapUpDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final hit = _hitTestCard(worldPos);
    final wpHit = _hitTestWaypoint(worldPos);

    if (_isClickingConnection && _clickedConnectionId != null) {
      ref.read(canvasProvider.notifier).selectConnection(_clickedConnectionId);
      _isClickingConnection = false;
      _clickedConnectionId = null;
      return;
    }
    _isClickingConnection = false;
    _clickedConnectionId = null;

    final connHit = _hitTestConnectionLine(worldPos);

    final selectedIds = _selectedCardIds;
    if (selectedIds.length == 1) {
      final selectedCard = ref.read(canvasProvider.notifier).cardById(selectedIds.first);
      if (selectedCard != null) {
        final edge = _hitTestResizeHandle(worldPos, selectedCard);
        if (edge != _ResizeEdge.none) return;
      }
    }

    if (_styleBrushMode && hit != null && _copiedStyle != null) {
      ref.read(canvasProvider.notifier).updateCard(hit.copyWith(style: _copiedStyle));
      setState(() { _styleBrushMode = false; _copiedStyle = null; });
      return;
    }

    if (_connectingFromCardId != null && hit != null && hit.id != _connectingFromCardId) {
      _createConnection(_connectingFromCardId!, hit.id);
      setState(() => _connectingFromCardId = null);
    } else if (wpHit != null) {
      ref.read(canvasProvider.notifier).selectConnection(wpHit.$1);
    } else if (hit != null && connHit == null) {
      if (selectedIds.length == 1 && hit.id == selectedIds.first) {
        _startInlineEditing(hit.id);
      } else {
        _finishInlineEditing();
        ref.read(canvasProvider.notifier).selectCard(hit.id);
      }
    } else if (connHit != null) {
      if (hit != null) {
        final cardCenter = Offset(hit.x + hit.width / 2, hit.y + hit.height / 2);
        final distToCardCenter = (worldPos - cardCenter).distance;
        if (distToCardCenter < math.min(hit.width, hit.height) * 0.35) {
          if (selectedIds.length == 1 && hit.id == selectedIds.first) {
            _startInlineEditing(hit.id);
          } else {
            _finishInlineEditing();
            ref.read(canvasProvider.notifier).selectCard(hit.id);
          }
          return;
        }
      }
      ref.read(canvasProvider.notifier).selectConnection(connHit.$1);
    } else if (hit != null) {
      if (selectedIds.length == 1 && hit.id == selectedIds.first) {
        _startInlineEditing(hit.id);
      } else {
        _finishInlineEditing();
        ref.read(canvasProvider.notifier).selectCard(hit.id);
      }
    } else {
      ref.read(canvasProvider.notifier).selectConnection(null);
      _finishInlineEditing();
      ref.read(canvasProvider.notifier).selectCard(null);
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final hit = _hitTestCard(worldPos);
    if (hit != null) {
      _finishInlineEditing();
      _openCardContent(hit);
    } else {
      final connHit = _hitTestConnectionLine(worldPos);
      if (connHit != null) {
        final (snappedPos, insertIdx) = _snapWaypointToConnection(connHit.$1, worldPos);
        ref.read(canvasProvider.notifier).addWaypoint(connHit.$1, Offset(_snapToGrid(snappedPos.dx), _snapToGrid(snappedPos.dy)), insertIndex: insertIdx);
      }
    }
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final canvasData = ref.read(canvasProvider);

    if (canvasData.selectedConnectionId != null) {
      _showConnectionContextMenu(details.globalPosition, canvasData.selectedConnectionId!, worldPos);
      return;
    }
    if (canvasData.selectedCardIds.isNotEmpty) {
      final firstSelected = ref.read(canvasProvider.notifier).cardById(canvasData.selectedCardIds.first);
      if (firstSelected != null) {
        _showCardContextMenu(details.globalPosition, firstSelected);
        return;
      }
    }

    final wpHit = _hitTestWaypoint(worldPos);
    if (wpHit != null) {
      _showWaypointContextMenu(details.globalPosition, wpHit.$1, wpHit.$2);
      return;
    }
    final hit = _hitTestCard(worldPos);
    if (hit != null) {
      ref.read(canvasProvider.notifier).selectCard(hit.id);
      _showCardContextMenu(details.globalPosition, hit);
    } else {
      final connHit = _hitTestConnectionLine(worldPos);
      if (connHit != null) {
        ref.read(canvasProvider.notifier).selectConnection(connHit.$1);
        _showConnectionContextMenu(details.globalPosition, connHit.$1, worldPos);
      } else {
        _showContextMenu(context, details, canvasData, worldPos);
      }
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta.dy;
      final zoomFactor = scrollDelta < 0 ? 1.05 : 0.95;
      final newScale = (_scale * zoomFactor).clamp(_minScale, _maxScale);

      final screenPos = Offset(event.localPosition.dx, event.localPosition.dy);
      final worldBefore = _screenToWorld(screenPos);

      _scale = newScale;
      final worldAfter = _screenToWorld(screenPos);
      _cameraX += worldBefore.dx - worldAfter.dx;
      _cameraY += worldBefore.dy - worldAfter.dy;
      _cameraNotifier.notify();
    } else if (event is PointerDownEvent) {
      if (event.buttons & kSecondaryButton != 0) {
        _altKeyPressed = true;
      }
    }
  }

  void _onHover(PointerHoverEvent event) {
    final worldPos = _screenToWorld(event.localPosition);
    final hitCard = _hitTestCardWithResize(worldPos);
    _ResizeEdge edge = _ResizeEdge.none;
    String? hoverId;
    ConnectionSide? hoverSide;
    bool hoveringLine = false;
    if (hitCard != null) {
      edge = _hitTestResizeHandle(worldPos, hitCard);
      hoverId = hitCard.id;
    }
    final connLineHit = _hitTestConnectionLine(worldPos);
    if (connLineHit != null) {
      hoveringLine = true;
    }
    final portHit = _hitTestConnectionPoint(worldPos);
    if (portHit != null) {
      hoverId = portHit.$1;
      hoverSide = portHit.$2;
      hoveringLine = false;
    }
    if (edge != _hoverResizeEdge || hoverId != _hoverCardId || hoverSide != _hoveredConnectionSide || hoveringLine != _hoveringConnectionLine) {
      setState(() {
        _hoverResizeEdge = edge;
        _hoverCardId = hoverId;
        _hoveredConnectionSide = hoverSide;
        _hoveringConnectionLine = hoveringLine;
      });
    }
  }

  MouseCursor _getCursor() {
    if (_isDraggingFromPort) return SystemMouseCursors.precise;
    if (_hoveredConnectionSide != null) return SystemMouseCursors.precise;
    switch (_hoverResizeEdge) {
      case _ResizeEdge.corner:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case _ResizeEdge.right:
        return SystemMouseCursors.resizeLeftRight;
      case _ResizeEdge.bottom:
        return SystemMouseCursors.resizeUpDown;
      case _ResizeEdge.none:
        if (_hoveringConnectionLine) return SystemMouseCursors.click;
        if (_hoverCardId != null) return SystemMouseCursors.click;
        return SystemMouseCursors.basic;
    }
  }

  void _zoomIn() {
    final newScale = (_scale * 1.2).clamp(_minScale, _maxScale);
    _scale = newScale;
    _cameraNotifier.notify();
  }

  void _zoomOut() {
    final newScale = (_scale / 1.2).clamp(_minScale, _maxScale);
    _scale = newScale;
    _cameraNotifier.notify();
  }

  void _zoomReset() {
    _scale = 1.0;
    _cameraNotifier.notify();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      final notifier = ref.read(canvasProvider.notifier);
      final matched = notifier.searchCards(query);
      setState(() {
        _searchQuery = query;
        _searchMatchedIds = matched.map((c) => c.id).toList();
        _searchActiveIndex = 0;
      });
    });
  }

  void _onSearchSubmit(String query) {
    final notifier = ref.read(canvasProvider.notifier);
    final matched = notifier.searchCards(query);
    setState(() {
      _searchQuery = query;
      _searchMatchedIds = matched.map((c) => c.id).toList();
      _searchActiveIndex = 0;
    });
    _panToFirstMatch();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() { _searchQuery = ''; _searchMatchedIds = []; _searchActiveIndex = 0; });
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _clearSearch();
      }
    });
  }

  void _searchNext() {
    if (_searchMatchedIds.isEmpty) return;
    setState(() {
      _searchActiveIndex = (_searchActiveIndex + 1) % _searchMatchedIds.length;
    });
    _panToMatch(_searchActiveIndex);
  }

  void _searchPrev() {
    if (_searchMatchedIds.isEmpty) return;
    setState(() {
      _searchActiveIndex = (_searchActiveIndex - 1 + _searchMatchedIds.length) % _searchMatchedIds.length;
    });
    _panToMatch(_searchActiveIndex);
  }

  void _panToFirstMatch() => _panToMatch(0);

  void _panToMatch(int index) {
    if (index < 0 || index >= _searchMatchedIds.length) return;
    final cardId = _searchMatchedIds[index];
    final canvasData = ref.read(canvasProvider);
    final card = canvasData.cards.where((c) => c.id == cardId).firstOrNull;
    if (card == null) return;
    final targetScale = math.min(_viewW / (card.width + 200), _viewH / (card.height + 200)).clamp(0.1, 2.0);
    _cameraX = card.x + card.width / 2;
    _cameraY = card.y + card.height / 2;
    _scale = targetScale;
    _cameraNotifier.notify();
    ref.read(canvasProvider.notifier).selectCard(card.id);
  }

  void _deleteSelectedCards() {
    final selectedIds = _selectedCardIds;
    if (selectedIds.isEmpty) return;
    if (selectedIds.length == 1) {
      ref.read(canvasProvider.notifier).removeCard(selectedIds.first);
    } else {
      ref.read(canvasProvider.notifier).batchDeleteCards(selectedIds);
    }
    ref.read(canvasProvider.notifier).selectCard(null);
  }

  void _undo() => ref.read(canvasProvider.notifier).undo();
  void _redo() => ref.read(canvasProvider.notifier).redo();

  void _selectAll() => ref.read(canvasProvider.notifier).selectAll();

  void _groupSelected() {
    final ids = _selectedCardIds;
    if (ids.length < 2) return;
    ref.read(canvasProvider.notifier).groupCards(ids);
  }

  void _ungroupSelected() {
    final ids = _selectedCardIds;
    if (ids.isEmpty) return;
    final notifier = ref.read(canvasProvider.notifier);
    for (final id in ids) {
      final group = notifier.groupForCard(id);
      if (group != null) {
        notifier.ungroupCards(group.id);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasData = ref.watch(canvasProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final linkResolver = ref.watch(linkResolverProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(canvasProvider.notifier);
    final l = AppLocalizations.of(context)!;

    final autoEnabled = canvasData.settings.autoConnectionsEnabled;

    if (!identical(_lastCards, canvasData.cards) ||
        !identical(_lastNotes, knowledgeState.notes) ||
        _lastAutoEnabled != autoEnabled ||
        !identical(_lastLinkResolver, linkResolver)) {
      _lastCards = canvasData.cards;
      _lastNotes = knowledgeState.notes;
      _lastAutoEnabled = autoEnabled;
      _lastLinkResolver = linkResolver;
      _cachedAutoConnections = notifier.deriveAutoConnections(knowledgeState.notes, linkResolver);
    }
    final autoConns = _cachedAutoConnections;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f3): _searchNext,
        const SingleActivator(LogicalKeyboardKey.f3, shift: true): _searchPrev,
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelectedCards,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_styleBrushMode) { setState(() { _styleBrushMode = false; _copiedStyle = null; }); return; }
          if (_connectingFromCardId != null) {
            setState(() {
              _connectingFromCardId = null;
              _connectingFromSide = null;
              _isDraggingFromPort = false;
              _connectingPreviewEnd = null;
              _hoveredConnectionSide = null;
            });
            return;
          }
          if (ref.read(canvasProvider).selectedConnectionId != null) { ref.read(canvasProvider.notifier).selectConnection(null); return; }
          _finishInlineEditing();
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): _selectAll,
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): _groupSelected,
        const SingleActivator(LogicalKeyboardKey.keyG, control: true, shift: true): _ungroupSelected,
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            if (event is KeyDownEvent) {
              _altKeyPressed = true;
            } else if (event is KeyUpEvent) {
              _altKeyPressed = false;
              setState(() => _alignmentGuides = []);
            }
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              _buildToolbar(theme, canvasData, autoEnabled, notifier, l),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _canvasW = constraints.maxWidth;
                          _canvasH = constraints.maxHeight;

                          final visibleWorldRect = Rect.fromLTWH(
                            _cameraX - _viewW / 2 / _scale - _gridSize,
                            _cameraY - _viewH / 2 / _scale - _gridSize,
                            _viewW / _scale + _gridSize * 2,
                            _viewH / _scale + _gridSize * 2,
                          );

                          return Stack(
                            children: [
                              MouseRegion(
                                cursor: _getCursor(),
                                onHover: _onHover,
                                child: Listener(
                                  onPointerSignal: _onPointerSignal,
                                  child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onScaleStart: _onScaleStart,
                              onScaleUpdate: _onScaleUpdate,
                              onScaleEnd: _onScaleEnd,
                              onTapUp: _onTapUp,
                              onDoubleTapDown: _onDoubleTapDown,
                              onSecondaryTapUp: _onSecondaryTapUp,
                              child: ClipRect(
                                child: SizedBox.expand(
                                  child: RepaintBoundary(
                                    key: _canvasPaintKey,
                                    child: ListenableBuilder(
                                    listenable: Listenable.merge([_animController, _cameraNotifier]),
                                    builder: (context, _) => CustomPaint(
                                    painter: CanvasPainter(
                                      cards: canvasData.cards,
                                      connections: canvasData.connections,
                                      autoConnections: autoConns,
                                      cameraX: _cameraX,
                                      cameraY: _cameraY,
                                      scale: _scale,
                                      viewW: _viewW,
                                      viewH: _viewH,
                                      gridSize: _gridSize,
                                      visibleWorldRect: visibleWorldRect,
                                      selectedCardIds: canvasData.selectedCardIds,
                                      connectingFromCardId: _connectingFromCardId,
                                      searchMatchedIds: _searchMatchedIds,
                                      searchActiveIndex: _searchActiveIndex,
                                      connectingPreviewEnd: _connectingPreviewEnd,
                                      hoveredCardId: _hoverCardId,
                                      hoveredConnectionSide: _hoveredConnectionSide,
                                      selectedConnectionId: canvasData.selectedConnectionId,
                                      primaryColor: theme.colorScheme.primary,
                                      dividerColor: theme.dividerColor,
                                      scaffoldBg: theme.scaffoldBackgroundColor,
                                      isDark: theme.brightness == Brightness.dark,
                                      hintColor: theme.hintColor,
                                      bodySmallStyle: theme.textTheme.bodySmall,
                                      bodyMediumStyle: theme.textTheme.bodyMedium,
                                      knowledgeState: knowledgeState,
                                      baseFontSize: settings.editorFontSize,
                                      gridVisible: canvasData.settings.gridVisible,
                                      inlineEditingCardId: _inlineEditingCardId,
                                      groups: canvasData.groups,
                                      layers: canvasData.layers,
                                      selectionRect: _selectionRect,
                                      alignmentGuides: _alignmentGuides,
                                      backgroundColorValue: canvasData.settings.backgroundColorValue,
                                      rulersVisible: canvasData.settings.rulersVisible,
                                      animationValue: _animController.value,
                                    ),
                                  ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: _cameraNotifier,
                          builder: (context, _) => _buildMinimap(theme, canvasData),
                        ),
                        ListenableBuilder(
                          listenable: _cameraNotifier,
                          builder: (context, _) => _buildZoomControls(theme),
                        ),
                        _buildStatusBar(theme, canvasData, l),
                        if (_inlineEditingCardId != null)
                          _buildInlineEditor(theme, canvasData, settings),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),
);
}

  Widget _buildToolbar(ThemeData theme, CanvasData canvasData, bool autoEnabled, CanvasNotifier notifier, AppLocalizations l) {
    final hasMultiSelection = canvasData.selectedCardIds.length >= 2;
    return Container(
      height: _toolbarHeight,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.dashboard, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  _buildCanvasSwitcher(theme),
                  const SizedBox(width: 6),
                  _toolbarDivider(theme),
                  const SizedBox(width: 4),
                  _toolbarButton(theme, Icons.add, l.addCard, () {
                    final worldPos = Offset(_cameraX, _cameraY);
                    _addCardAt(worldPos);
                  }),
                  _toolbarButton(theme, autoEnabled ? Icons.auto_fix_high : Icons.auto_fix_off,
                    autoEnabled ? l.autoConnectOn : l.autoConnectOff,
                    () => ref.read(canvasProvider.notifier).toggleAutoConnections(),
                  ),
                  const SizedBox(width: 4),
                  _toolbarDivider(theme),
                  const SizedBox(width: 4),
                  _toolbarButton(theme, Icons.undo, l.undo, () => _undo(),
                    enabled: notifier.canUndo),
                  _toolbarButton(theme, Icons.redo, l.redo, () => _redo(),
                    enabled: notifier.canRedo),
                  const SizedBox(width: 4),
                  _toolbarDivider(theme),
                  const SizedBox(width: 4),
                  if (hasMultiSelection) ...[
                    PopupMenuButton<String>(
                      tooltip: l.align,
                      icon: Icon(Icons.align_horizontal_left, size: 14, color: theme.hintColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onSelected: (value) {
                        final notifier = ref.read(canvasProvider.notifier);
                        final ids = canvasData.selectedCardIds;
                        switch (value) {
                          case 'left': notifier.alignCards(ids, AlignmentType.left);
                          case 'centerH': notifier.alignCards(ids, AlignmentType.centerH);
                          case 'right': notifier.alignCards(ids, AlignmentType.right);
                          case 'top': notifier.alignCards(ids, AlignmentType.top);
                          case 'centerV': notifier.alignCards(ids, AlignmentType.centerV);
                          case 'bottom': notifier.alignCards(ids, AlignmentType.bottom);
                          case 'distH': notifier.distributeCards(ids, DistributeType.horizontal);
                          case 'distV': notifier.distributeCards(ids, DistributeType.vertical);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: 'left', child: Row(children: [Icon(Icons.align_horizontal_left, size: 14), SizedBox(width: 8), Text(l.alignLeft)])),
                        PopupMenuItem(value: 'centerH', child: Row(children: [Icon(Icons.align_horizontal_center, size: 14), SizedBox(width: 8), Text(l.alignCenterH)])),
                        PopupMenuItem(value: 'right', child: Row(children: [Icon(Icons.align_horizontal_right, size: 14), SizedBox(width: 8), Text(l.alignRight)])),
                        PopupMenuItem(value: 'top', child: Row(children: [Icon(Icons.align_vertical_top, size: 14), SizedBox(width: 8), Text(l.alignTop)])),
                        PopupMenuItem(value: 'centerV', child: Row(children: [Icon(Icons.align_vertical_center, size: 14), SizedBox(width: 8), Text(l.alignCenterV)])),
                        PopupMenuItem(value: 'bottom', child: Row(children: [Icon(Icons.align_vertical_bottom, size: 14), SizedBox(width: 8), Text(l.alignBottom)])),
                        if (canvasData.selectedCardIds.length >= 3) ...[
                          const PopupMenuDivider(),
                          PopupMenuItem(value: 'distH', child: Row(children: [Icon(Icons.space_bar, size: 14), SizedBox(width: 8), Text(l.distributeH)])),
                          PopupMenuItem(value: 'distV', child: Row(children: [Icon(Icons.view_headline, size: 14), SizedBox(width: 8), Text(l.distributeV)])),
                        ],
                      ],
                    ),
                    _toolbarButton(theme, Icons.group_work, l.group, _groupSelected),
                    _toolbarDivider(theme),
                    const SizedBox(width: 4),
                  ],
                  _toolbarButton(
                    theme,
                    canvasData.settings.gridVisible ? Icons.grid_on : Icons.grid_off,
                    canvasData.settings.gridVisible ? l.gridOn : l.gridOff,
                    () => ref.read(canvasProvider.notifier).toggleGridVisible(),
                  ),
                  _toolbarButton(
                    theme,
                    canvasData.settings.snapToGrid ? Icons.grid_on_outlined : Icons.grid_4x4,
                    canvasData.settings.snapToGrid ? l.snapOn : l.snapOff,
                    () => ref.read(canvasProvider.notifier).toggleSnapToGrid(),
                  ),
                  const SizedBox(width: 4),
                  _toolbarDivider(theme),
                  const SizedBox(width: 4),
                  _toolbarButton(theme, Icons.crop_square, l.container, () {
                    final worldPos = Offset(_cameraX, _cameraY);
                    _addContainerAt(worldPos);
                  }),
                  PopupMenuButton<CanvasCardType>(
                    tooltip: l.shapes,
                    icon: Icon(Icons.category, size: 14, color: theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onSelected: (type) {
                      final worldPos = Offset(_cameraX, _cameraY);
                      final card = ref.read(canvasProvider.notifier).createCard(type, worldPos);
                      ref.read(canvasProvider.notifier).addCard(card);
                      ref.read(canvasProvider.notifier).selectCard(card.id);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: CanvasCardType.rectangle, child: Row(children: [Icon(Icons.rectangle, size: 14), SizedBox(width: 8), Text(l.rectangle)])),
                      PopupMenuItem(value: CanvasCardType.roundedRect, child: Row(children: [Icon(Icons.rounded_corner, size: 14), SizedBox(width: 8), Text(l.roundedRect)])),
                      PopupMenuItem(value: CanvasCardType.ellipse, child: Row(children: [Icon(Icons.circle, size: 14), SizedBox(width: 8), Text(l.ellipse)])),
                      PopupMenuItem(value: CanvasCardType.diamond, child: Row(children: [Icon(Icons.diamond, size: 14), SizedBox(width: 8), Text(l.diamond)])),
                      PopupMenuItem(value: CanvasCardType.hexagon, child: Row(children: [Icon(Icons.hexagon, size: 14), SizedBox(width: 8), Text(l.hexagon)])),
                      PopupMenuItem(value: CanvasCardType.parallelogram, child: Row(children: [Icon(Icons.change_history, size: 14), SizedBox(width: 8), Text(l.parallelogram)])),
                      PopupMenuItem(value: CanvasCardType.triangle, child: Row(children: [Icon(Icons.details, size: 14), SizedBox(width: 8), Text(l.triangle)])),
                      PopupMenuItem(value: CanvasCardType.cylinder, child: Row(children: [Icon(Icons.view_column, size: 14), SizedBox(width: 8), Text(l.cylinder)])),
                      PopupMenuItem(value: CanvasCardType.star, child: Row(children: [Icon(Icons.star_outline, size: 14), SizedBox(width: 8), Text(l.star)])),
                      PopupMenuItem(value: CanvasCardType.swimlaneH, child: Row(children: [Icon(Icons.view_stream, size: 14), SizedBox(width: 8), Text(l.swimlaneH)])),
                      PopupMenuItem(value: CanvasCardType.swimlaneV, child: Row(children: [Icon(Icons.view_week, size: 14), SizedBox(width: 8), Text(l.swimlaneV)])),
                      PopupMenuItem(value: CanvasCardType.table, child: Row(children: [Icon(Icons.table_chart, size: 14), SizedBox(width: 8), Text(l.table)])),
                      PopupMenuItem(value: CanvasCardType.freehand, child: Row(children: [Icon(Icons.draw, size: 14), SizedBox(width: 8), Text(l.freehand)])),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: l.templates,
                    icon: Icon(Icons.dashboard_customize, size: 14, color: theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onSelected: (name) {
                      showDialog(context: context, builder: (ctx) => AlertDialog(
                        title: Text(l.loadTemplate),
                        content: Text(l.loadTemplateConfirm),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
                          FilledButton(onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(canvasProvider.notifier).loadTemplate(name);
                          }, child: Text(l.load)),
                        ],
                      ));
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: 'flowchart', child: Row(children: [Icon(Icons.account_tree, size: 14), SizedBox(width: 8), Text(l.flowchart)])),
                      PopupMenuItem(value: 'uml_class', child: Row(children: [Icon(Icons.class_, size: 14), SizedBox(width: 8), Text(l.umlClass)])),
                      PopupMenuItem(value: 'swimlane', child: Row(children: [Icon(Icons.view_stream, size: 14), SizedBox(width: 8), Text(l.swimlane)])),
                      PopupMenuItem(value: 'mindmap', child: Row(children: [Icon(Icons.psychology, size: 14), SizedBox(width: 8), Text(l.mindMap)])),
                      PopupMenuItem(value: 'network', child: Row(children: [Icon(Icons.cloud, size: 14), SizedBox(width: 8), Text(l.network)])),
                      PopupMenuItem(value: 'er_diagram', child: Row(children: [Icon(Icons.schema, size: 14), SizedBox(width: 8), Text(l.erDiagram)])),
                      PopupMenuItem(value: 'kanban', child: Row(children: [Icon(Icons.view_kanban, size: 14), SizedBox(width: 8), Text(l.kanban)])),
                      PopupMenuItem(value: 'org_chart', child: Row(children: [Icon(Icons.corporate_fare, size: 14), SizedBox(width: 8), Text(l.orgChart)])),
                      PopupMenuItem(value: 'state_machine', child: Row(children: [Icon(Icons.sync, size: 14), SizedBox(width: 8), Text(l.stateMachine)])),
                      PopupMenuItem(value: 'venn', child: Row(children: [Icon(Icons.circle, size: 14), SizedBox(width: 8), Text(l.vennDiagram)])),
                      PopupMenuItem(value: 'timeline', child: Row(children: [Icon(Icons.timeline, size: 14), SizedBox(width: 8), Text(l.timeline)])),
                      PopupMenuItem(value: 'gantt', child: Row(children: [Icon(Icons.view_timeline, size: 14), SizedBox(width: 8), Text(l.gantt)])),
                      PopupMenuItem(value: 'decision_tree', child: Row(children: [Icon(Icons.device_hub, size: 14), SizedBox(width: 8), Text(l.decisionTree)])),
                    ],
                  ),
                  _toolbarButton(theme, Icons.format_paint, l.styleBrush, () {
                    final ids = _selectedCardIds;
                    if (ids.length == 1) {
                      final card = ref.read(canvasProvider.notifier).cardById(ids.first);
                      if (card != null) {
                        setState(() {
                          _styleBrushMode = true;
                          _copiedStyle = card.style ?? CanvasCardStyle.defaults;
                        });
                      }
                    }
                  }, enabled: _selectedCardIds.length == 1),
                  _toolbarButton(theme, Icons.fit_screen, l.fit, _fitToContent),
                  PopupMenuButton<AutoLayoutType>(
                    tooltip: l.autoLayout,
                    icon: Icon(Icons.auto_awesome, size: 14, color: theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onSelected: (type) => ref.read(canvasProvider.notifier).autoLayout(type),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: AutoLayoutType.forceDirected, child: Row(children: [Icon(Icons.bubble_chart, size: 14), SizedBox(width: 8), Text(l.forceDirected)])),
                      PopupMenuItem(value: AutoLayoutType.hierarchical, child: Row(children: [Icon(Icons.account_tree, size: 14), SizedBox(width: 8), Text(l.hierarchical)])),
                      PopupMenuItem(value: AutoLayoutType.grid, child: Row(children: [Icon(Icons.grid_view, size: 14), SizedBox(width: 8), Text(l.grid)])),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: l.export,
                    icon: Icon(Icons.file_download, size: 14, color: theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onSelected: (value) => _handleExport(value),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: 'png', child: Row(children: [Icon(Icons.image, size: 14), SizedBox(width: 8), Text(l.exportPng)])),
                      PopupMenuItem(value: 'svg', child: Row(children: [Icon(Icons.code, size: 14), SizedBox(width: 8), Text(l.exportSvg)])),
                      PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 14), SizedBox(width: 8), Text(l.exportPdf)])),
                      PopupMenuItem(value: 'markdown', child: Row(children: [Icon(Icons.description, size: 14), SizedBox(width: 8), Text(l.exportMarkdown)])),
                      PopupMenuItem(value: 'html', child: Row(children: [Icon(Icons.web, size: 14), SizedBox(width: 8), Text(l.exportHtml)])),
                      PopupMenuItem(value: 'jpeg', child: Row(children: [Icon(Icons.photo, size: 14), SizedBox(width: 8), Text(l.exportJpeg)])),
                      PopupMenuItem(value: 'svgWithMeta', child: Row(children: [Icon(Icons.data_object, size: 14), SizedBox(width: 8), Text(l.exportSvgWithData)])),
                    ],
                  ),
                  _toolbarButton(theme, Icons.layers, l.layers, () => _showLayerPanel()),
                  _toolbarButton(theme, Icons.bookmark_border, l.scratchpad, () => _showScratchpad()),
                  _toolbarButton(theme, Icons.straighten, l.rulers, () => ref.read(canvasProvider.notifier).toggleRulers()),
                  _toolbarButton(theme, Icons.draw, l.freehand, () {
                    setState(() { _isFreehandDrawing = !_isFreehandDrawing; });
                    if (_isFreehandDrawing) {
                      final card = CanvasCard(
                        id: 'fh_${DateTime.now().millisecondsSinceEpoch}',
                        type: CanvasCardType.freehand,
                        x: _cameraX, y: _cameraY,
                        freehandPoints: [],
                      );
                      ref.read(canvasProvider.notifier).addCard(card);
                      _freehandCardId = card.id;
                      _freehandPoints = [];
                    } else {
                      _freehandCardId = null;
                      _freehandPoints = [];
                    }
                  }, highlight: _isFreehandDrawing),
                  PopupMenuButton<String>(
                    tooltip: l.canvasSettings,
                    icon: Icon(Icons.settings, size: 14, color: theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onSelected: (value) {
                      if (value == 'background') {
                        _showBackgroundColorPicker();
                      } else if (value == 'defaultCardStyle') {
                        _showDefaultStyleDialog();
                      } else if (value == 'clearBackground') {
                        ref.read(canvasProvider.notifier).setBackgroundColor(null);
                      } else if (value == 'enumerate') {
                        ref.read(canvasProvider.notifier).enumerateAllCards();
                      } else if (value == 'importCsv') {
                        _showImportDialog('csv');
                      } else if (value == 'importMermaid') {
                        _showImportDialog('mermaid');
                      } else if (value == 'importSvg') {
                        _showImportDialog('svg');
                      } else if (value == 'shareUrl') {
                        _shareViaUrl();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: 'background', child: Row(children: [Icon(Icons.palette, size: 14), SizedBox(width: 8), Text(l.backgroundColor)])),
                      PopupMenuItem(value: 'clearBackground', child: Row(children: [Icon(Icons.clear, size: 14), SizedBox(width: 8), Text(l.clearBackground)])),
                      PopupMenuItem(value: 'defaultCardStyle', child: Row(children: [Icon(Icons.style, size: 14), SizedBox(width: 8), Text(l.defaultCardStyle)])),
                      PopupMenuItem(value: 'enumerate', child: Row(children: [Icon(Icons.format_list_numbered, size: 14), SizedBox(width: 8), Text(l.enumerateShapes)])),
                      PopupMenuItem(value: 'importCsv', child: Row(children: [Icon(Icons.table_chart, size: 14), SizedBox(width: 8), Text(l.importCsv)])),
                      PopupMenuItem(value: 'importMermaid', child: Row(children: [Icon(Icons.code, size: 14), SizedBox(width: 8), Text(l.importMermaid)])),
                      PopupMenuItem(value: 'importSvg', child: Row(children: [Icon(Icons.draw, size: 14), SizedBox(width: 8), Text(l.importSvg)])),
                      PopupMenuItem(value: 'shareUrl', child: Row(children: [Icon(Icons.share, size: 14), SizedBox(width: 8), Text(l.shareViaUrl)])),
                    ],
                  ),
                  _toolbarButton(theme, Icons.delete_outline, l.clear, () {
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: Text(l.clearCanvas),
                      content: Text(l.clearCanvasConfirm),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
                        FilledButton(style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error), onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(canvasProvider.notifier).clearCanvas();
                          ref.read(canvasProvider.notifier).selectCard(null);
                          _connectingFromCardId = null;
                        }, child: Text(l.clear)),
                      ],
                    ));
                  }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toolbarDivider(theme),
                const SizedBox(width: 4),
                _toolbarButton(theme, Icons.search, l.searchCards, _toggleSearch),
                if (_searchVisible)
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l.searchCards,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(onTap: _clearSearch, child: Icon(Icons.close, size: 12, color: theme.hintColor))
                            : null,
                      ),
                      style: theme.textTheme.bodySmall,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmit,
                    ),
                  ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _searchPrev,
                    child: Icon(Icons.keyboard_arrow_up, size: 16, color: theme.hintColor),
                  ),
                  GestureDetector(
                    onTap: _searchNext,
                    child: Icon(Icons.keyboard_arrow_down, size: 16, color: theme.hintColor),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${_searchActiveIndex + 1}/${_searchMatchedIds.length}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarDivider(ThemeData theme) {
    return Container(width: 1, height: 16, color: theme.dividerColor);
  }

  Widget _buildZoomControls(ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    return Positioned(
      right: 12,
      bottom: 40,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              onPressed: _zoomIn,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l.zoomIn,
              color: theme.hintColor,
            ),
            Container(
              width: 32,
              height: 24,
              alignment: Alignment.center,
              child: Text(
                '${(_scale * 100).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove, size: 16),
              onPressed: _zoomOut,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l.zoomOut,
              color: theme.hintColor,
            ),
            Container(width: 24, height: 1, color: theme.dividerColor),
            IconButton(
              icon: const Icon(Icons.filter_center_focus, size: 16),
              onPressed: _zoomReset,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l.resetZoom,
              color: theme.hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimap(ThemeData theme, CanvasData canvasData) {
    if (canvasData.cards.isEmpty) return const SizedBox.shrink();

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final card in canvasData.cards) {
      minX = math.min(minX, card.x);
      minY = math.min(minY, card.y);
      maxX = math.max(maxX, card.x + card.width);
      maxY = math.max(maxY, card.y + card.height);
    }

    const minimapW = 160.0;
    const minimapH = 100.0;
    const padding = 20.0;

    final contentW = maxX - minX + padding * 2;
    final contentH = maxY - minY + padding * 2;
    final mmScale = math.min(minimapW / contentW, minimapH / contentH);

    final contentMinimapW = contentW * mmScale;
    final contentMinimapH = contentH * mmScale;
    final offsetX = (minimapW - contentMinimapW) / 2;
    final offsetY = (minimapH - contentMinimapH) / 2;

    return Positioned(
      left: 12,
      bottom: 40,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapUp: (details) {
            final tapLocal = details.localPosition;
            final worldX = minX - padding + (tapLocal.dx - offsetX) / mmScale;
            final worldY = minY - padding + (tapLocal.dy - offsetY) / mmScale;
            _cameraX = worldX;
            _cameraY = worldY;
            _cameraNotifier.notify();
          },
          child: Container(
            width: minimapW,
            height: minimapH,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                size: const Size(minimapW, minimapH),
                painter: _MinimapPainter(
                  cards: canvasData.cards,
                  connections: canvasData.connections,
                  minX: minX - padding,
                  minY: minY - padding,
                  mmScale: mmScale,
                  offsetX: offsetX,
                  offsetY: offsetY,
                  cameraX: _cameraX,
                  cameraY: _cameraY,
                  viewW: _viewW,
                  viewH: _viewH,
                  scale: _scale,
                  primaryColor: theme.colorScheme.primary,
                  dividerColor: theme.dividerColor,
                  cardColor: theme.hintColor,
                  scaffoldBg: theme.scaffoldBackgroundColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, CanvasData canvasData, AppLocalizations l) {
    final selectedCount = canvasData.selectedCardIds.length;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.85),
          border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            Text(
              l.canvasStatusCardsConnectionsGroups(canvasData.cards.length, canvasData.connections.length, canvasData.groups.length),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.hintColor),
            ),
            const Spacer(),
            if (selectedCount > 1)
              Text(
                l.selectedGroupHint(selectedCount),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary),
              ),
            if (selectedCount == 1 && _inlineEditingCardId == null)
              Text(
                l.selectedSingleHint,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.hintColor),
              ),
            if (_inlineEditingCardId != null)
              Text(
                l.editingHint,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary),
              ),
            if (_connectingFromCardId != null)
              Text(
                l.connectCardHint,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary),
              ),
            if (_styleBrushMode)
              Text(
                l.styleBrushHint,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.purple),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEditor(ThemeData theme, CanvasData canvasData, AppSettings settings) {
    final l = AppLocalizations.of(context)!;
    final card = ref.read(canvasProvider.notifier).cardById(_inlineEditingCardId!);
    if (card == null) return const SizedBox.shrink();

    final pos = _w2s(card.x, card.y);
    final cardScreenW = card.width * _scale;
    final cardScreenH = card.height * _scale;
    final headerH = 30.0 * _scale;
    final cardFontSize = card.effectiveFontSize(settings.editorFontSize);
    final scaledFont = cardFontSize * _scale;
    final accentW = 3.0 * _scale;
    final padH = 10.0 * _scale;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: cardScreenW,
      height: cardScreenH,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    Container(
                      height: headerH,
                      padding: EdgeInsets.only(left: accentW + padH, right: accentW + padH),
                      color: Colors.transparent,
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _inlineTitleCtrl,
                        focusNode: _inlineTitleFocus,
                        style: TextStyle(fontSize: scaledFont, fontWeight: FontWeight.w600, letterSpacing: 0.2 / _scale, height: 1.0),
                        strutStyle: StrutStyle(forceStrutHeight: true, height: 1.0),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: l.title,
                          hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5), fontSize: scaledFont),
                        ),
                        onSubmitted: (_) => _inlineContentFocus?.requestFocus(),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.transparent,
                        padding: EdgeInsets.only(left: accentW + padH, right: accentW + padH, top: 4 * _scale),
                        child: TextField(
                          controller: _inlineContentCtrl,
                          focusNode: _inlineContentFocus,
                          style: TextStyle(fontSize: scaledFont * 1.06, height: 1.4),
                          strutStyle: StrutStyle(forceStrutHeight: true, height: 1.4),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: card.type == CanvasCardType.note ? l.noteContent : l.typeSomething,
                            hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5), fontSize: scaledFont * 1.06, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: accentW,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _w2s(double wx, double wy) {
    return Offset((wx - _cameraX) * _scale + _viewW / 2, (wy - _cameraY) * _scale + _viewH / 2);
  }

  Widget _buildCanvasSwitcher(ThemeData theme) {
    final notifier = ref.read(canvasProvider.notifier);
    final active = notifier.activeCanvasName;
    return GestureDetector(
      onTap: () => _showCanvasSelector(context, theme),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(active, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 14, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  void _showCanvasSelector(BuildContext context, ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(canvasProvider.notifier);
    final names = notifier.canvasNames;
    final active = notifier.activeCanvasName;
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(40, 36, 200, 400),
      items: [
        ...names.map((name) => PopupMenuItem<String>(value: name, child: Row(children: [
          Icon(name == active ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: name == active ? FontWeight.w600 : FontWeight.w400), overflow: TextOverflow.ellipsis)),
          if (name != active) GestureDetector(onTap: () { Navigator.pop(context); _showRenameDialog(name); }, child: Icon(Icons.edit, size: 14, color: theme.hintColor)),
          if (name != active && names.length > 1) GestureDetector(onTap: () { Navigator.pop(context); _confirmDeleteCanvas(name); }, child: Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.delete, size: 14, color: theme.colorScheme.error))),
        ]))),
        const PopupMenuDivider(),
        PopupMenuItem<String>(value: '__new__', child: Row(children: [Icon(Icons.add, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.newCanvas, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary))])),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == '__new__') { _showCreateCanvasDialog(); }
      else if (value != active) {
        ref.read(canvasProvider.notifier).switchCanvas(value);
        ref.read(canvasProvider.notifier).selectCard(null);
        _connectingFromCardId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _centerOrFitView());
      }
    });
  }

  void _showCreateCanvasDialog() {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.newCanvas),
      content: TextField(controller: controller, decoration: InputDecoration(hintText: l.canvasName), autofocus: true,
        onSubmitted: (name) async {
          if (await ref.read(canvasProvider.notifier).createCanvas(name)) {
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            await ref.read(canvasProvider.notifier).switchCanvas(name);
            if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _centerOrFitView());
          }
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () async {
          final name = controller.text.trim();
          if (await ref.read(canvasProvider.notifier).createCanvas(name)) {
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            await ref.read(canvasProvider.notifier).switchCanvas(name);
            if (mounted) { ref.read(canvasProvider.notifier).selectCard(null); _connectingFromCardId = null; WidgetsBinding.instance.addPostFrameCallback((_) => _centerOrFitView()); }
          }
        }, child: Text(l.create)),
      ],
    ));
  }

  void _showRenameDialog(String oldName) {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: oldName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.renameCanvas),
      content: TextField(controller: controller, decoration: InputDecoration(hintText: l.newName), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () async {
          if (await ref.read(canvasProvider.notifier).renameCanvas(oldName, controller.text.trim())) {
            if (!ctx.mounted) return; Navigator.pop(ctx);
          }
        }, child: Text(l.rename)),
      ],
    ));
  }

  void _confirmDeleteCanvas(String name) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.deleteCanvas),
      content: Text(l.deleteCanvasConfirm(name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error), onPressed: () async {
          await ref.read(canvasProvider.notifier).deleteCanvas(name);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          if (mounted) _centerOrFitView();
        }, child: Text(l.delete)),
      ],
    ));
  }

  Widget _toolbarButton(ThemeData theme, IconData icon, String tooltip, VoidCallback onTap, {bool enabled = true, bool highlight = false}) {
    return IconButton(
      icon: Icon(icon, size: 14, color: highlight ? theme.colorScheme.primary : null),
      onPressed: enabled ? onTap : null,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      color: enabled ? theme.hintColor : theme.disabledColor,
    );
  }

  void _showWaypointContextMenu(Offset position, String connId, int waypointIndex) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(value: 'remove', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error), const SizedBox(width: 8), Text(l.removeWaypoint)])),
        PopupMenuItem(value: 'removeAll', child: Row(children: [Icon(Icons.clear, size: 16, color: theme.colorScheme.error), const SizedBox(width: 8), Text(l.removeAllWaypoints)])),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'remove':
          ref.read(canvasProvider.notifier).removeWaypoint(connId, waypointIndex);
        case 'removeAll':
          final conn = ref.read(canvasProvider).connections.where((c) => c.id == connId).firstOrNull;
          if (conn != null) {
            ref.read(canvasProvider.notifier).updateConnection(conn.copyWith(waypoints: []));
          }
      }
    });
  }

  void _showContextMenu(BuildContext context, TapUpDetails details, CanvasData canvasData, Offset worldPos) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx + 1, details.globalPosition.dy + 1),
      items: [
        PopupMenuItem(value: 'note', child: Row(children: [Icon(Icons.description, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.noteCard)])),
        PopupMenuItem(value: 'text', child: Row(children: [Icon(Icons.text_fields, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.textCard)])),
        PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.image, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.imageCard)])),
        PopupMenuItem(value: 'link', child: Row(children: [Icon(Icons.link, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.linkCard)])),
        PopupMenuItem(value: 'container', child: Row(children: [Icon(Icons.crop_square, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.container)])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'fromNote', child: Row(children: [Icon(Icons.library_books, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.fromKnowledgeNote)])),
        if (canvasData.selectedCardIds.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.editCard)])),
          PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.content_copy, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.duplicateCard)])),
          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: theme.colorScheme.error), const SizedBox(width: 8), Text(l.deleteCard)])),
        ],
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'note': _addCardAt(worldPos, type: CanvasCardType.note);
        case 'text': _addCardAt(worldPos, type: CanvasCardType.text);
        case 'image': _addCardAt(worldPos, type: CanvasCardType.image);
        case 'link': _addCardAt(worldPos, type: CanvasCardType.link);
        case 'container': _addContainerAt(worldPos);
        case 'fromNote': _addCardFromNote(worldPos);
        case 'edit': if (canvasData.selectedCardIds.isNotEmpty) _startInlineEditing(canvasData.selectedCardIds.first);
        case 'duplicate': if (canvasData.selectedCardIds.isNotEmpty) _duplicateCard(canvasData.selectedCardIds.first, worldPos);
        case 'delete': _deleteSelectedCards();
      }
    });
  }

  void _showConnectionContextMenu(Offset position, String connId, Offset worldPos) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final conn = ref.read(canvasProvider).connections.where((c) => c.id == connId).firstOrNull;
    if (conn == null) return;
    final style = conn.style ?? CanvasConnectionStyle.defaults;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(value: 'straightPath', child: Row(children: [Icon(Icons.show_chart, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.straight), if (style.pathType == ConnectionPath.straight) ...[const Spacer(), Icon(Icons.check, size: 14, color: theme.colorScheme.primary)]])),
        PopupMenuItem(value: 'curvedPath', child: Row(children: [Icon(Icons.waves, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.curved), if (style.pathType == ConnectionPath.curved) ...[const Spacer(), Icon(Icons.check, size: 14, color: theme.colorScheme.primary)]])),
        PopupMenuItem(value: 'orthoPath', child: Row(children: [Icon(Icons.turn_right, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.orthogonal), if (style.pathType == ConnectionPath.orthogonal) ...[const Spacer(), Icon(Icons.check, size: 14, color: theme.colorScheme.primary)]])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'addWaypoint', child: Row(children: [Icon(Icons.add_location_alt, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.addWaypoint)])),
        if (conn.waypoints.isNotEmpty)
          PopupMenuItem(value: 'clearWaypoints', child: Row(children: [Icon(Icons.clear_all, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.clearWaypoints)])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: theme.colorScheme.error), const SizedBox(width: 8), Text(l.deleteConnection)])),
      ],
    ).then((value) {
      if (value == null) return;
      final latestConn = ref.read(canvasProvider).connections.where((c) => c.id == connId).firstOrNull;
      if (latestConn == null) return;
      final currentStyle = latestConn.style ?? CanvasConnectionStyle.defaults;
      switch (value) {
        case 'straightPath':
          ref.read(canvasProvider.notifier).updateConnection(latestConn.copyWith(style: currentStyle.copyWith(pathType: ConnectionPath.straight), clearStyle: false));
        case 'curvedPath':
          ref.read(canvasProvider.notifier).updateConnection(latestConn.copyWith(style: currentStyle.copyWith(pathType: ConnectionPath.curved), clearStyle: false));
        case 'orthoPath':
          ref.read(canvasProvider.notifier).updateConnection(latestConn.copyWith(style: currentStyle.copyWith(pathType: ConnectionPath.orthogonal), clearStyle: false));
        case 'addWaypoint':
          final (snappedPos, insertIdx) = _snapWaypointToConnection(connId, worldPos);
          ref.read(canvasProvider.notifier).addWaypoint(connId, snappedPos, insertIndex: insertIdx);
        case 'clearWaypoints':
          ref.read(canvasProvider.notifier).updateConnection(latestConn.copyWith(waypoints: []));
        case 'delete':
          ref.read(canvasProvider.notifier).removeConnection(connId);
          ref.read(canvasProvider.notifier).selectConnection(null);
      }
    });
  }

  void _showCardContextMenu(Offset position, CanvasCard card) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canvasData = ref.read(canvasProvider);
    final connections = canvasData.connections.where((c) => c.fromCardId == card.id || c.toCardId == card.id).toList();
    final linkResolver = ref.read(linkResolverProvider);
    final knowledgeState = ref.read(knowledgeProvider);
    final autoConns = ref.read(canvasProvider.notifier).deriveAutoConnections(knowledgeState.notes, linkResolver);
    final autoConnections = autoConns.where((c) => c.fromCardId == card.id || c.toCardId == card.id).toList();
    final allConns = [...connections.map((c) => (conn: c, isAuto: c.isAuto)), ...autoConnections.map((c) => (conn: c, isAuto: true))];
    final isInGroup = ref.read(canvasProvider.notifier).groupForCard(card.id) != null;
    final selectedCount = canvasData.selectedCardIds.length;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.editCard)])),
        PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.content_copy, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.duplicateCard)])),
        PopupMenuItem(value: 'color', child: Row(children: [Icon(Icons.palette, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.changeColor)])),
        PopupMenuItem(value: 'copyStyle', child: Row(children: [Icon(Icons.format_paint, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.copyStyle)])),
        if (_copiedStyle != null)
          PopupMenuItem(value: 'pasteStyle', child: Row(children: [Icon(Icons.content_paste, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.pasteStyle)])),
        if (card.type == CanvasCardType.container)
          PopupMenuItem(value: 'toggleCollapse', child: Row(children: [Icon(card.collapsed ? Icons.unfold_more : Icons.unfold_less, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(card.collapsed ? l.expand : l.collapse)])),
        PopupMenuItem(value: 'saveToScratchpad', child: Row(children: [Icon(Icons.bookmark_border, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.saveToScratchpad)])),
        PopupMenuItem(value: 'addTag', child: Row(children: [Icon(Icons.label, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.addTag)])),
        if (card.tags.isNotEmpty)
          PopupMenuItem(value: 'removeTag', child: Row(children: [Icon(Icons.label_off, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.removeTag)])),
        if (canvasData.layers.isNotEmpty)
          PopupMenuItem(value: 'moveToLayer', child: Row(children: [Icon(Icons.layers, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.moveToLayer)])),
        const PopupMenuDivider(),
        if (selectedCount >= 2)
          PopupMenuItem(value: 'group', child: Row(children: [Icon(Icons.group_work, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.groupSelection)])),
        if (isInGroup)
          PopupMenuItem(value: 'ungroup', child: Row(children: [Icon(Icons.group_remove, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.ungroup)])),
        if (selectedCount >= 2) ...[
          const PopupMenuDivider(),
          PopupMenuItem(value: 'alignLeft', child: Row(children: [Icon(Icons.align_horizontal_left, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.alignLeft)])),
          PopupMenuItem(value: 'alignCenterH', child: Row(children: [Icon(Icons.align_horizontal_center, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.alignCenterH)])),
          PopupMenuItem(value: 'alignRight', child: Row(children: [Icon(Icons.align_horizontal_right, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.alignRight)])),
          PopupMenuItem(value: 'alignTop', child: Row(children: [Icon(Icons.align_vertical_top, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.alignTop)])),
          PopupMenuItem(value: 'alignCenterV', child: Row(children: [Icon(Icons.align_vertical_center, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.alignCenterV)])),
          PopupMenuItem(value: 'alignBottom', child: Row(children: [Icon(Icons.align_vertical_bottom, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.alignBottom)])),
          if (selectedCount >= 3) ...[
            PopupMenuItem(value: 'distributeH', child: Row(children: [Icon(Icons.space_bar, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.distributeH)])),
            PopupMenuItem(value: 'distributeV', child: Row(children: [Icon(Icons.view_headline, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.distributeV)])),
          ],
        ],
        if (allConns.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(value: 'manageConns', child: Row(children: [Icon(Icons.settings_ethernet, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.manageConnections)])),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: theme.colorScheme.error), const SizedBox(width: 8), Text(l.deleteCard)])),
      ],
    ).then((value) {
      if (value == null) return;
      final notifier = ref.read(canvasProvider.notifier);
      final ids = canvasData.selectedCardIds;
      switch (value) {
        case 'edit': _editCard(card.id);
        case 'duplicate': _duplicateCard(card.id, Offset(card.x + 40, card.y + 40));
        case 'color': _showColorPicker(card);
        case 'copyStyle': setState(() { _copiedStyle = card.style ?? CanvasCardStyle.defaults; });
        case 'pasteStyle': if (_copiedStyle != null) { notifier.updateCard(card.copyWith(style: _copiedStyle)); }
        case 'toggleCollapse': _toggleContainerCollapse(card.id);
        case 'saveToScratchpad': _saveCardToScratchpad(card);
        case 'moveToLayer': _showMoveToLayerDialog(card);
        case 'addTag': _showAddTagDialog(card);
        case 'removeTag': _showRemoveTagDialog(card);
        case 'manageConns': _showConnectionListDialog(card, allConns);
        case 'group': notifier.groupCards(ids);
        case 'ungroup': _ungroupSelected();
        case 'alignLeft': notifier.alignCards(ids, AlignmentType.left);
        case 'alignCenterH': notifier.alignCards(ids, AlignmentType.centerH);
        case 'alignRight': notifier.alignCards(ids, AlignmentType.right);
        case 'alignTop': notifier.alignCards(ids, AlignmentType.top);
        case 'alignCenterV': notifier.alignCards(ids, AlignmentType.centerV);
        case 'alignBottom': notifier.alignCards(ids, AlignmentType.bottom);
        case 'distributeH': notifier.distributeCards(ids, DistributeType.horizontal);
        case 'distributeV': notifier.distributeCards(ids, DistributeType.vertical);
        case 'delete': _deleteSelectedCards();
      }
    });
  }

  void _showColorPicker(CanvasCard card) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final selectedIds = _selectedCardIds;
    final isMulti = selectedIds.length > 1;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(isMulti ? 'Change Color (${selectedIds.length} cards)' : l.changeColor),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cardColorPresets.map((color) => GestureDetector(
            onTap: () {
              if (isMulti) {
                ref.read(canvasProvider.notifier).batchUpdateCardColor(selectedIds, color.toARGB32());
              } else {
                ref.read(canvasProvider.notifier).updateCard(card.copyWith(colorValue: color.toARGB32()));
              }
              Navigator.pop(ctx);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: card.colorValue == color.toARGB32() ? theme.colorScheme.primary : theme.dividerColor,
                  width: card.colorValue == color.toARGB32() ? 2.5 : 1,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)],
              ),
              child: card.colorValue == color.toARGB32()
                  ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                  : null,
            ),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
      ],
    ));
  }

  void _showConnectionListDialog(CanvasCard card, List<({CanvasConnection conn, bool isAuto})> allConns) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.manageConnections),
      content: SizedBox(
        width: 320,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: allConns.length,
          itemBuilder: (ctx, i) {
            final e = allConns[i];
            final otherCardId = e.conn.fromCardId == card.id ? e.conn.toCardId : e.conn.fromCardId;
            final otherCard = ref.read(canvasProvider.notifier).cardById(otherCardId);
            final connStyle = e.conn.style ?? CanvasConnectionStyle.defaults;
            return ListTile(
              dense: true,
              leading: Icon(e.isAuto ? Icons.auto_fix_high : Icons.link, size: 16, color: e.isAuto ? theme.hintColor : theme.colorScheme.primary),
              title: Text(otherCard?.title ?? otherCardId, overflow: TextOverflow.ellipsis),
              subtitle: Text(e.conn.label.isNotEmpty ? e.conn.label : (e.isAuto ? l.autoConnection : '${connStyle.pathType.name} · ${connStyle.arrowStyle.name}')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!e.isAuto) IconButton(
                  icon: Icon(Icons.tune, size: 14, color: theme.hintColor),
                  tooltip: l.editStyle,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showConnectionStyleDialog(e.conn);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                  onPressed: () {
                    if (e.isAuto) {
                      ref.read(canvasProvider.notifier).addConnection(e.conn.copyWith(isAuto: false));
                    } else {
                      ref.read(canvasProvider.notifier).removeConnection(e.conn.id);
                    }
                    Navigator.pop(ctx);
                  },
                ),
              ]),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            for (final e in allConns) {
              try { ref.read(canvasProvider.notifier).removeConnection(e.conn.id); } catch (_) {}
            }
            Navigator.pop(ctx);
          },
          child: Text(l.deleteAll, style: TextStyle(color: theme.colorScheme.error)),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
      ],
    ));
  }

  void _showConnectionStyleDialog(CanvasConnection conn) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final currentStyle = conn.style ?? CanvasConnectionStyle.defaults;
    ConnectionPath pathType = currentStyle.pathType;
    ArrowStyle arrowStyle = currentStyle.arrowStyle;
    double strokeWidth = currentStyle.strokeWidth;
    int colorValue = currentStyle.colorValue;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Text(l.connectionStyle),
      content: SizedBox(
        width: 280,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<ConnectionPath>(
            // ignore: deprecated_member_use
            value: pathType,
            key: ValueKey(pathType),
            decoration: InputDecoration(labelText: l.pathType, isDense: true),
            items: ConnectionPath.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
            onChanged: (v) { if (v != null) setDialogState(() => pathType = v); },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ArrowStyle>(
            // ignore: deprecated_member_use
            value: arrowStyle,
            key: ValueKey(arrowStyle),
            decoration: InputDecoration(labelText: l.arrowStyle, isDense: true),
            items: ArrowStyle.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
            onChanged: (v) { if (v != null) setDialogState(() => arrowStyle = v); },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text(l.width, style: theme.textTheme.bodySmall),
            Expanded(child: Slider(value: strokeWidth, min: 0.5, max: 6, divisions: 11, label: strokeWidth.toStringAsFixed(1), onChanged: (v) => setDialogState(() => strokeWidth = v))),
            SizedBox(width: 28, child: Text(strokeWidth.toStringAsFixed(1), style: theme.textTheme.bodySmall, textAlign: TextAlign.end)),
          ]),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            // ignore: deprecated_member_use
            value: colorValue,
            key: ValueKey(colorValue),
            decoration: InputDecoration(labelText: l.color, isDense: true),
            items: [0xFF000000, 0xFF1565C0, 0xFF2E7D32, 0xFFE65100, 0xFFC62828, 0xFF6A1B9A, 0xFF00838F, 0xFF4E342E].map((v) => DropdownMenuItem(value: v, child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(v), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), Text('#${v.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}')]))).toList(),
            onChanged: (v) { if (v != null) setDialogState(() => colorValue = v); },
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () {
          ref.read(canvasProvider.notifier).addConnection(conn.copyWith(
            style: CanvasConnectionStyle(pathType: pathType, arrowStyle: arrowStyle, strokeWidth: strokeWidth, colorValue: colorValue),
            clearStyle: false,
          ));
          ref.read(canvasProvider.notifier).removeConnection(conn.id);
          Navigator.pop(ctx);
        }, child: Text(l.save)),
      ],
    )));
  }

  void _duplicateCard(String cardId, Offset pos) {
    final card = ref.read(canvasProvider.notifier).cardById(cardId);
    if (card == null) return;
    final newCard = CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: card.type,
      x: pos.dx,
      y: pos.dy,
      width: card.width,
      height: card.height,
      title: card.title,
      content: card.content,
      colorValue: card.colorValue,
      fontSize: card.fontSize,
    );
    ref.read(canvasProvider.notifier).addCard(newCard);
    ref.read(canvasProvider.notifier).selectCard(newCard.id);
  }

  void _addCardAt(Offset pos, {CanvasCardType type = CanvasCardType.note}) {
    final snappedX = _snapToGrid(pos.dx - 120);
    final snappedY = _snapToGrid(pos.dy - 80);
    final card = CanvasCard(id: 'card_${DateTime.now().millisecondsSinceEpoch}', type: type, x: snappedX, y: snappedY, width: 240, height: 160, title: '', content: '');
    ref.read(canvasProvider.notifier).addCard(card);
    _startInlineEditing(card.id);
  }

  void _addContainerAt(Offset pos) {
    final l = AppLocalizations.of(context)!;
    final snappedX = _snapToGrid(pos.dx - 200);
    final snappedY = _snapToGrid(pos.dy - 100);
    final container = CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: CanvasCardType.container,
      x: snappedX, y: snappedY,
      width: 400, height: 300,
      title: l.container,
      childIds: const [],
      collapsed: false,
    );
    ref.read(canvasProvider.notifier).addCard(container);
    ref.read(canvasProvider.notifier).selectCard(container.id);
  }

  void _toggleContainerCollapse(String cardId) {
    final card = ref.read(canvasProvider.notifier).cardById(cardId);
    if (card == null || card.type != CanvasCardType.container) return;
    ref.read(canvasProvider.notifier).updateCard(card.copyWith(collapsed: !card.collapsed));
  }

  void _saveCardToScratchpad(CanvasCard card) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: card.title.isEmpty ? card.type.label : card.title);
    final categoryCtrl = TextEditingController(text: l.general);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.saveToScratchpad),
      content: SizedBox(
        width: 280,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: InputDecoration(labelText: l.templateName), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: categoryCtrl, decoration: InputDecoration(labelText: l.category, hintText: l.general),),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () async {
          final item = ScratchpadItem(
            id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
            name: nameCtrl.text.trim().isEmpty ? card.type.label : nameCtrl.text.trim(),
            type: card.type,
            width: card.width,
            height: card.height,
            colorValue: card.colorValue,
            style: card.style,
            category: categoryCtrl.text.trim().isEmpty ? l.general : categoryCtrl.text.trim(),
          );
          await ref.read(canvasProvider.notifier).saveScratchpadItem(item);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.savedToScratchpad(item.name)), duration: const Duration(seconds: 2)),
            );
          }
        }, child: Text(l.save)),
      ],
    ));
  }

  void _showMoveToLayerDialog(CanvasCard card) {
    final l = AppLocalizations.of(context)!;
    final canvasData = ref.read(canvasProvider);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.moveToLayer),
      content: SizedBox(
        width: 240,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            dense: true,
            title: Text(l.noLayerDefault),
            leading: Radio<String?>(
              // ignore: deprecated_member_use
              value: null,
              // ignore: deprecated_member_use
              groupValue: card.layerId,
              // ignore: deprecated_member_use
              onChanged: (_) {
                ref.read(canvasProvider.notifier).moveCardToLayer(card.id, null);
                Navigator.pop(ctx);
              },
            ),
          ),
          ...canvasData.layers.map((layer) => ListTile(
            dense: true,
            title: Text(layer.name),
            leading: Radio<String?>(
              // ignore: deprecated_member_use
              value: layer.id,
              // ignore: deprecated_member_use
              groupValue: card.layerId,
              // ignore: deprecated_member_use
              onChanged: (_) {
                ref.read(canvasProvider.notifier).moveCardToLayer(card.id, layer.id);
                Navigator.pop(ctx);
              },
            ),
          )),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
      ],
    ));
  }

  void _showBackgroundColorPicker() {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(canvasProvider.notifier);
    final canvasData = ref.read(canvasProvider);
    final current = canvasData.settings.backgroundColorValue;
    showDialog(context: context, builder: (ctx) {
      final ctxTheme = Theme.of(ctx);
      return AlertDialog(
      title: Text(l.backgroundColor),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          Colors.white, Colors.grey[100]!, Colors.grey[200]!, Colors.blue[50]!, Colors.green[50]!, Colors.orange[50]!, Colors.purple[50]!, Colors.red[50]!,
          Colors.grey[800]!, Colors.grey[900]!, Colors.blue[900]!, Colors.green[900]!,
        ].map((c) => GestureDetector(
          onTap: () {
            notifier.setBackgroundColor(c.toARGB32());
            Navigator.pop(ctx);
          },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: current == c.toARGB32() ? ctxTheme.colorScheme.primary : ctxTheme.dividerColor, width: current == c.toARGB32() ? 2 : 1),
            ),
          ),
        )).toList()),
      ]),
      actions: [
        TextButton(onPressed: () { notifier.setBackgroundColor(null); Navigator.pop(ctx); }, child: Text(l.clear)),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
      ],
    );});
  }

  void _showDefaultStyleDialog() {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(canvasProvider.notifier);
    final canvasData = ref.read(canvasProvider);
    final currentCardStyle = canvasData.settings.defaultCardStyle ?? CanvasCardStyle.defaults;
    showDialog(context: context, builder: (ctx) {
      final ctxTheme = Theme.of(ctx);
      return AlertDialog(
      title: Text(l.defaultCardStyle),
      content: SizedBox(
        width: 280,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.fillColor, style: ctxTheme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            0xFFFFFFFF, 0xFFF5F5F5, 0xFFE3F2FD, 0xFFE8F5E9, 0xFFFFF3E0, 0xFFFCE4EC, 0xFFF3E5F5, 0xFFE0E0E0,
          ].map((v) => GestureDetector(
            onTap: () => notifier.setDefaultCardStyle(currentCardStyle.copyWith(fillColor: v)),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Color(v),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: currentCardStyle.fillColor == v ? ctxTheme.colorScheme.primary : ctxTheme.dividerColor, width: currentCardStyle.fillColor == v ? 2 : 1),
              ),
            ),
          )).toList()),
          const SizedBox(height: 12),
          Text(l.borderRadius, style: ctxTheme.textTheme.bodySmall),
          Slider(
            value: currentCardStyle.borderRadius,
            min: 0, max: 24,
            divisions: 12,
            label: currentCardStyle.borderRadius.round().toString(),
            onChanged: (v) => notifier.setDefaultCardStyle(currentCardStyle.copyWith(borderRadius: v)),
          ),
          const SizedBox(height: 8),
          Text(l.borderWidth, style: ctxTheme.textTheme.bodySmall),
          Slider(
            value: currentCardStyle.borderWidth,
            min: 0, max: 4,
            divisions: 8,
            label: currentCardStyle.borderWidth.toStringAsFixed(1),
            onChanged: (v) => notifier.setDefaultCardStyle(currentCardStyle.copyWith(borderWidth: v)),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () { notifier.setDefaultCardStyle(null); Navigator.pop(ctx); }, child: Text(l.reset)),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
      ],
    );});
  }

  void _showAddTagDialog(CanvasCard card) {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.addTag),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: l.tagName), onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(l.add)),
      ],
    )).then((tag) {
      if (tag != null && tag.isNotEmpty) {
        ref.read(canvasProvider.notifier).addTag(card.id, tag);
      }
    });
  }

  void _showRemoveTagDialog(CanvasCard card) {
    final l = AppLocalizations.of(context)!;
    showDialog(context: context, builder: (ctx) {
      final ctxTheme = Theme.of(ctx);
      return SimpleDialog(
      title: Text(l.removeTag),
      children: card.tags.map((tag) => SimpleDialogOption(
        onPressed: () {
          ref.read(canvasProvider.notifier).removeTag(card.id, tag);
          Navigator.pop(ctx);
        },
        child: Row(children: [Icon(Icons.label, size: 14, color: ctxTheme.hintColor), const SizedBox(width: 8), Text(tag)]),
      )).toList(),
    );});
  }

  void _showImportDialog(String format) {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.importFormat(format.toUpperCase())),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: format == 'csv' ? 'Name,Relation\nAlice,Bob\nBob,Charlie'
              : format == 'mermaid' ? 'graph TD\n    A-->B\n    B-->C'
              : '<svg>...</svg>',
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () {
          final data = switch (format) {
            'csv' => CanvasNotifier.importFromCsv(ctrl.text),
            'mermaid' => CanvasNotifier.importFromMermaid(ctrl.text),
            'svg' => CanvasNotifier.importFromSvg(ctrl.text),
            _ => null,
          };
          Navigator.pop(ctx);
          if (data != null) {
            ref.read(canvasProvider.notifier).loadFromData(data);
          }
        }, child: Text(l.import)),
      ],
    ));
  }

  void _shareViaUrl() {
    final l = AppLocalizations.of(context)!;
    final url = ref.read(canvasProvider.notifier).encodeToUrl();
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.shareUrlCopied), duration: const Duration(seconds: 3)),
    );
  }

  void _addCardFromNote(Offset pos) {
    final l = AppLocalizations.of(context)!;
    final notes = ref.read(knowledgeProvider).notes;
    if (notes.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.noNotesInKnowledgeBase))); return; }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.selectNote),
      content: SizedBox(width: 300, child: ListView.builder(shrinkWrap: true, itemCount: notes.length, itemBuilder: (ctx, i) => ListTile(dense: true, title: Text(notes[i].title, overflow: TextOverflow.ellipsis), onTap: () {
        final note = notes[i];
        final snappedX = _snapToGrid(pos.dx - 120);
        final snappedY = _snapToGrid(pos.dy - 80);
        final card = CanvasCard(id: 'card_${DateTime.now().millisecondsSinceEpoch}', type: CanvasCardType.note, x: snappedX, y: snappedY, width: 280, height: 200, title: note.title, content: note.content.length > 500 ? '${note.content.substring(0, 500)}...' : note.content, noteId: note.id);
        ref.read(canvasProvider.notifier).addCard(card);
        ref.read(canvasProvider.notifier).selectCard(card.id);
        Navigator.pop(ctx);
      }))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel))],
    ));
  }

  void _openCardContent(CanvasCard card) {
    if (card.type == CanvasCardType.container) { _toggleContainerCollapse(card.id); return; }
    if (card.type == CanvasCardType.link && card.content.isNotEmpty) { ref.read(browserProvider.notifier).createTab(url: card.content); return; }
    if (card.noteId != null) { ref.read(knowledgeProvider.notifier).openNote(card.noteId!); return; }
    _startInlineEditing(card.id);
  }

  void _editCard(String cardId) {
    final card = ref.read(canvasProvider.notifier).cardById(cardId);
    if (card == null) return;
    final settings = ref.read(settingsProvider);
    final l = AppLocalizations.of(context)!;
    final dialogTheme = Theme.of(context);
    final titleCtrl = TextEditingController(text: card.title);
    final titleFocus = FocusNode();
    final contentCtrl = TextEditingController(text: card.content);
    double cardFontSize = card.fontSize > 0 ? card.fontSize : settings.editorFontSize * 0.85;
    int selectedColorValue = card.colorValue;
    int selectedTextColorValue = card.textColorValue;
    String selectedFontFamily = card.fontFamily;
    TextAlignH selectedAlignH = card.textAlignH;
    TextAlignV selectedAlignV = card.textAlignV;
    List<RichTextSegment> richSegments = List.from(card.richContent);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Text(l.editCardType(card.type.label)),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtrl, focusNode: titleFocus, decoration: InputDecoration(labelText: l.noteTitle), autofocus: true),
        const SizedBox(height: 12),
        TextField(controller: contentCtrl, decoration: InputDecoration(labelText: switch (card.type) {
          CanvasCardType.note => l.contentPreview, CanvasCardType.text => l.note, CanvasCardType.image => l.imagePath, CanvasCardType.link => l.url, CanvasCardType.container => l.contentPreview,
          _ => l.contentPreview,
        }),
          maxLines: card.type == CanvasCardType.note || card.type == CanvasCardType.text ? 5 : 1),
        const SizedBox(height: 12),
        Text(l.richText, style: dialogTheme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Row(children: [
          IconButton(icon: const Icon(Icons.format_bold, size: 18), tooltip: l.bold,
            onPressed: () { richSegments.add(const RichTextSegment(text: 'bold text', type: RichTextSegmentType.bold)); setDialogState(() {}); }),
          IconButton(icon: const Icon(Icons.format_italic, size: 18), tooltip: l.italic,
            onPressed: () { richSegments.add(const RichTextSegment(text: 'italic text', type: RichTextSegmentType.italic)); setDialogState(() {}); }),
          IconButton(icon: const Icon(Icons.format_underlined, size: 18), tooltip: l.underline,
            onPressed: () { richSegments.add(const RichTextSegment(text: 'underlined', type: RichTextSegmentType.underline)); setDialogState(() {}); }),
          IconButton(icon: const Icon(Icons.code, size: 18), tooltip: l.code,
            onPressed: () { richSegments.add(const RichTextSegment(text: 'code', type: RichTextSegmentType.code)); setDialogState(() {}); }),
          IconButton(icon: const Icon(Icons.strikethrough_s, size: 18), tooltip: l.strikethrough,
            onPressed: () { richSegments.add(const RichTextSegment(text: 'deleted', type: RichTextSegmentType.strikethrough)); setDialogState(() {}); }),
          IconButton(icon: const Icon(Icons.add, size: 18), tooltip: l.text,
            onPressed: () { richSegments.add(const RichTextSegment(text: 'text')); setDialogState(() {}); }),
          const Spacer(),
          if (richSegments.isNotEmpty) IconButton(icon: const Icon(Icons.clear, size: 18), tooltip: l.clear,
            onPressed: () { richSegments.clear(); setDialogState(() {}); }),
        ]),
        if (richSegments.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: dialogTheme.dividerColor), borderRadius: BorderRadius.circular(4)),
            child: Wrap(spacing: 2, runSpacing: 2, children: richSegments.asMap().entries.map((e) {
              final idx = e.key;
              final seg = e.value;
              final style = switch (seg.type) {
                RichTextSegmentType.bold => const TextStyle(fontWeight: FontWeight.bold),
                RichTextSegmentType.italic => const TextStyle(fontStyle: FontStyle.italic),
                RichTextSegmentType.underline => const TextStyle(decoration: TextDecoration.underline),
                RichTextSegmentType.code => const TextStyle(fontFamily: 'monospace', backgroundColor: Colors.black12),
                RichTextSegmentType.strikethrough => const TextStyle(decoration: TextDecoration.lineThrough),
                RichTextSegmentType.text => const TextStyle(),
              };
              return GestureDetector(
                onDoubleTap: () {
                  final ctrl = TextEditingController(text: seg.text);
                  showDialog(context: ctx, builder: (dctx) => AlertDialog(
                    title: Text(l.editSegment(seg.type.name)),
                    content: TextField(controller: ctrl, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx), child: Text(l.cancel)),
                      FilledButton(onPressed: () {
                        richSegments[idx] = RichTextSegment(text: ctrl.text, type: seg.type);
                        Navigator.pop(dctx);
                        setDialogState(() {});
                      }, child: Text(l.ok)),
                    ],
                  ));
                },
                child: Chip(
                  label: Text(seg.text, style: style.copyWith(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 12),
                  onDeleted: () { richSegments.removeAt(idx); setDialogState(() {}); },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }).toList()),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Text(l.alignH, style: dialogTheme.textTheme.bodySmall),
          const SizedBox(width: 4),
          SegmentedButton<TextAlignH>(
            segments: const [ButtonSegment(value: TextAlignH.left, icon: Icon(Icons.format_align_left, size: 16)), ButtonSegment(value: TextAlignH.center, icon: Icon(Icons.format_align_center, size: 16)), ButtonSegment(value: TextAlignH.right, icon: Icon(Icons.format_align_right, size: 16))],
            selected: {selectedAlignH},
            onSelectionChanged: (v) => setDialogState(() => selectedAlignH = v.first),
            style: ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(l.alignV, style: dialogTheme.textTheme.bodySmall),
          const SizedBox(width: 4),
          SegmentedButton<TextAlignV>(
            segments: const [ButtonSegment(value: TextAlignV.top, icon: Icon(Icons.vertical_align_top, size: 16)), ButtonSegment(value: TextAlignV.middle, icon: Icon(Icons.vertical_align_center, size: 16)), ButtonSegment(value: TextAlignV.bottom, icon: Icon(Icons.vertical_align_bottom, size: 16))],
            selected: {selectedAlignV},
            onSelectionChanged: (v) => setDialogState(() => selectedAlignV = v.first),
            style: ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text(l.font, style: dialogTheme.textTheme.bodySmall),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: selectedFontFamily.isEmpty ? 'default' : selectedFontFamily,
            items: ['default', 'monospace', 'serif', 'sans-serif'].map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontFamily: f == 'default' ? null : f)))).toList(),
            onChanged: (v) => setDialogState(() => selectedFontFamily = v == 'default' ? '' : v!),
            isDense: true,
            underline: const SizedBox.shrink(),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(l.fontSize, style: dialogTheme.textTheme.bodySmall),
          Expanded(child: Slider(
            value: cardFontSize,
            min: 8, max: 32, divisions: 24,
            label: cardFontSize.round().toString(),
            onChanged: (v) => setDialogState(() => cardFontSize = v),
          )),
          SizedBox(width: 40, child: Text(cardFontSize.round().toString(), style: dialogTheme.textTheme.bodySmall, textAlign: TextAlign.end)),
        ]),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: Text(l.textColor, style: dialogTheme.textTheme.bodySmall)),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: [0xFF000000, 0xFF444444, 0xFF1565C0, 0xFF2E7D32, 0xFFE65100, 0xFFC62828, 0xFF6A1B9A, 0xFFFFFFFF].map((v) => GestureDetector(
          onTap: () => setDialogState(() => selectedTextColorValue = v),
          child: Container(width: 24, height: 24, decoration: BoxDecoration(
            color: Color(v), borderRadius: BorderRadius.circular(3),
            border: Border.all(color: selectedTextColorValue == v ? dialogTheme.colorScheme.primary : dialogTheme.dividerColor, width: selectedTextColorValue == v ? 2 : 0.5),
          )),
        )).toList()),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: Text(l.cardColor, style: dialogTheme.textTheme.bodySmall)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _cardColorPresets.map((color) => GestureDetector(
            onTap: () => setDialogState(() => selectedColorValue = color.toARGB32()),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selectedColorValue == color.toARGB32() ? dialogTheme.colorScheme.primary : dialogTheme.dividerColor,
                  width: selectedColorValue == color.toARGB32() ? 2.5 : 1,
                ),
              ),
              child: selectedColorValue == color.toARGB32()
                  ? Icon(Icons.check, size: 14, color: dialogTheme.colorScheme.primary)
                  : null,
            ),
          )).toList(),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () {
          final defaultSize = settings.editorFontSize * 0.85;
          ref.read(canvasProvider.notifier).updateCard(card.copyWith(
            title: titleCtrl.text.trim(),
            content: contentCtrl.text.trim(),
            fontSize: (cardFontSize - defaultSize).abs() < 0.5 ? 0 : cardFontSize,
            colorValue: selectedColorValue,
            textColorValue: selectedTextColorValue,
            fontFamily: selectedFontFamily,
            textAlignH: selectedAlignH,
            textAlignV: selectedAlignV,
            richContent: richSegments,
          ));
          Navigator.pop(ctx);
        }, child: Text(l.save)),
      ],
    ))).then((_) => titleFocus.dispose());
  }

  void _createConnection(String fromId, String toId) {
    final fromCard = ref.read(canvasProvider.notifier).cardById(fromId);
    final toCard = ref.read(canvasProvider.notifier).cardById(toId);
    if (fromCard == null || toCard == null) return;
    final (fromSide, toSide) = CanvasConnection.computeSides(fromCard, toCard);
    final conn = CanvasConnection(id: 'conn_${DateTime.now().millisecondsSinceEpoch}', fromCardId: fromId, toCardId: toId, fromSide: fromSide, toSide: toSide, fromSideOffset: 0.5, toSideOffset: 0.5, isAuto: false);
    ref.read(canvasProvider.notifier).addConnection(conn);
  }

  void _createConnectionWithSides(String fromId, String toId, ConnectionSide? fromSide, ConnectionSide? toSide, [double fromSideOffset = 0.5, double toSideOffset = 0.5]) {
    final fromCard = ref.read(canvasProvider.notifier).cardById(fromId);
    final toCard = ref.read(canvasProvider.notifier).cardById(toId);
    if (fromCard == null || toCard == null) return;
    final (computedFrom, computedTo) = CanvasConnection.computeSides(fromCard, toCard);
    final conn = CanvasConnection(
      id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
      fromCardId: fromId,
      toCardId: toId,
      fromSide: fromSide ?? computedFrom,
      toSide: toSide ?? computedTo,
      fromSideOffset: fromSideOffset,
      toSideOffset: toSideOffset,
      isAuto: false,
    );
    ref.read(canvasProvider.notifier).addConnection(conn);
    ref.read(canvasProvider.notifier).selectConnection(conn.id);
  }

  void _fitToContent() {
    final cards = ref.read(canvasProvider).cards;
    if (cards.isEmpty) { _cameraX = 0; _cameraY = 0; _scale = 1.0; _cameraNotifier.notify(); return; }
    double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final card in cards) { minX = math.min(minX, card.x); minY = math.min(minY, card.y); maxX = math.max(maxX, card.x + card.width); maxY = math.max(maxY, card.y + card.height); }
    final contentW = maxX - minX + 100;
    final contentH = maxY - minY + 100;
    final fitScale = math.min(_viewW / contentW, _viewH / contentH).clamp(0.05, 2.0);
    _cameraX = (minX + maxX) / 2;
    _cameraY = (minY + maxY) / 2;
    _scale = fitScale;
    _cameraNotifier.notify();
  }

  void _handleExport(String format) {
    final notifier = ref.read(canvasProvider.notifier);
    switch (format) {
      case 'svg':
        final svg = notifier.exportToSvg();
        _saveExportFile('canvas_${notifier.activeCanvasName}.svg', svg);
      case 'markdown':
        final md = notifier.exportToMarkdown();
        _saveExportFile('canvas_${notifier.activeCanvasName}.md', md);
      case 'png':
        _exportToPng();
      case 'pdf':
        final pdf = notifier.exportToPdf();
        _saveExportFile('canvas_${notifier.activeCanvasName}.svg', pdf);
      case 'html':
        final html = notifier.exportToHtml();
        _saveExportFile('canvas_${notifier.activeCanvasName}.html', html);
      case 'jpeg':
        _exportToPng();
      case 'svgWithMeta':
        final (svg, _) = notifier.exportWithEmbeddedData();
        _saveExportFile('canvas_${notifier.activeCanvasName}.svg', svg);
    }
  }

  Future<void> _exportToPng() async {
    final l = AppLocalizations.of(context)!;
    try {
      final boundary = _canvasPaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.exportFailedNotRendered)),
          );
        }
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.exportFailedPng)),
          );
        }
        return;
      }
      final notifier = ref.read(canvasProvider.notifier);
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
      final dir = Directory('$vaultPath/attachments');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/canvas_${notifier.activeCanvasName}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      image.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.exportedPngTo(file.path)), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.pngExportFailed('$e'))),
        );
      }
    }
  }

  void _saveExportFile(String filename, String content) async {
    final l = AppLocalizations.of(context)!;
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
      final dir = Directory('$vaultPath/attachments');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.exportedTo(file.path)), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.exportFailed('$e'))),
        );
      }
    }
  }

  void _showLayerPanel() {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notifier = ref.read(canvasProvider.notifier);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      final canvasData = ref.read(canvasProvider);
      final sortedLayers = List<CanvasLayer>.from(canvasData.layers)
        ..sort((a, b) => a.order.compareTo(b.order));
      return AlertDialog(
        title: Row(children: [
          const Icon(Icons.layers, size: 18),
          const SizedBox(width: 8),
          Text(l.layers),
          const Spacer(),
          Text('${canvasData.layers.length}', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        ]),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (sortedLayers.isEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Icon(Icons.layers_outlined, size: 40, color: theme.hintColor.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text(l.noLayersYet, style: TextStyle(color: theme.hintColor)),
                const SizedBox(height: 4),
                Text(l.addLayersToOrganize, style: TextStyle(color: theme.hintColor, fontSize: 11)),
              ])),
            ...sortedLayers.map((layer) {
              final cardCount = notifier.cardCountForLayer(layer.id);
              return ListTile(
                dense: true,
                leading: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(layer.visible ? Icons.visibility : Icons.visibility_off, size: 16, color: layer.visible ? theme.colorScheme.primary : theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      notifier.toggleLayerVisibility(layer.id);
                      setDialogState(() {});
                    },
                  ),
                ]),
                title: GestureDetector(
                  onDoubleTap: () {
                    final ctrl = TextEditingController(text: layer.name);
                    showDialog(context: ctx, builder: (dctx) => AlertDialog(
                      title: Text(l.renameLayerTitle),
                      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: l.layerName)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dctx), child: Text(l.cancel)),
                          FilledButton(onPressed: () {
                            notifier.renameLayer(layer.id, ctrl.text.trim());
                            Navigator.pop(dctx);
                            setDialogState(() {});
                          }, child: Text(l.renameLayer)),
                      ],
                    ));
                  },
                  child: Row(children: [
                    Expanded(child: Text(layer.name, style: TextStyle(
                      color: layer.locked ? theme.hintColor : null,
                      decoration: layer.visible ? null : TextDecoration.lineThrough,
                    ), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                      child: Text('$cardCount', style: theme.textTheme.bodySmall?.copyWith(fontSize: 9, color: theme.hintColor)),
                    ),
                  ]),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(Icons.arrow_upward, size: 14, color: theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: l.moveUp,
                    onPressed: () { notifier.moveLayerUp(layer.id); setDialogState(() {}); },
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_downward, size: 14, color: theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: l.moveDown,
                    onPressed: () { notifier.moveLayerDown(layer.id); setDialogState(() {}); },
                  ),
                  IconButton(
                    icon: Icon(layer.locked ? Icons.lock : Icons.lock_open, size: 16, color: layer.locked ? Colors.orange : theme.hintColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: layer.locked ? l.unlock : l.lock,
                    onPressed: () { notifier.toggleLayerLock(layer.id); setDialogState(() {}); },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: l.deleteLayer,
                    onPressed: () { notifier.removeLayer(layer.id); setDialogState(() {}); },
                  ),
                ]),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
          FilledButton.icon(
            onPressed: () {
              final name = 'Layer ${canvasData.layers.length + 1}';
              notifier.addLayer(name);
              setDialogState(() {});
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text(l.addLayer),
          ),
        ],
      );
    }));
  }

  void _showScratchpad() async {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notifier = ref.read(canvasProvider.notifier);
    final items = await notifier.loadScratchpad();
    if (!mounted) return;
    const kAllCategory = '__all__';
    String filterCategory = kAllCategory;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      final categories = [kAllCategory, ...items.map((i) => i.category).toSet()];
      final filtered = filterCategory == kAllCategory ? items : items.where((i) => i.category == filterCategory).toList();
      return AlertDialog(
        title: Row(children: [
          const Icon(Icons.bookmark_border, size: 18),
          const SizedBox(width: 8),
          Text(l.scratchpad),
          const Spacer(),
          Text('${items.length}', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        ]),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (categories.length > 2)
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(cat == kAllCategory ? l.all : cat, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                      selected: cat == filterCategory,
                      onSelected: (_) => setDialogState(() => filterCategory = cat),
                      visualDensity: VisualDensity.compact,
                    ),
                  )).toList(),
                ),
              ),
            if (categories.length > 2) const SizedBox(height: 8),
            ...filtered.map((item) {
              final previewColor = Color(item.colorValue);
              return ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 24,
                  decoration: BoxDecoration(
                    color: previewColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: previewColor.withValues(alpha: 0.3)),
                  ),
                  child: Center(child: Icon(item.type.icon, size: 12, color: previewColor)),
                ),
                title: Text(item.name, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                subtitle: Text('${item.category} · ${item.width.round()}×${item.height.round()}', style: theme.textTheme.bodySmall?.copyWith(fontSize: 9, color: theme.hintColor)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, size: 16, color: theme.colorScheme.primary),
                    tooltip: l.addToCanvas,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      final card = notifier.createCardFromScratchpad(item, Offset(_cameraX, _cameraY));
                      notifier.addCard(card);
                      notifier.selectCard(card.id);
                      Navigator.pop(ctx);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      notifier.removeScratchpadItem(item.id);
                      items.removeWhere((i) => i.id == item.id);
                      setDialogState(() {});
                    },
                  ),
                ]),
              );
            }),
            if (items.isEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Icon(Icons.bookmark_outline, size: 40, color: theme.hintColor.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text(l.noTemplatesYet, style: TextStyle(color: theme.hintColor)),
                const SizedBox(height: 4),
                Text(l.scratchpadEmptyHint, style: TextStyle(color: theme.hintColor, fontSize: 11)),
              ])),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
        ],
      );
    }));
  }
}

class _MinimapPainter extends CustomPainter {
  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final double minX, minY, mmScale;
  final double offsetX, offsetY;
  final double cameraX, cameraY, viewW, viewH, scale;
  final Color primaryColor, dividerColor, cardColor, scaffoldBg;

  _MinimapPainter({
    required this.cards,
    required this.connections,
    required this.minX,
    required this.minY,
    required this.mmScale,
    required this.offsetX,
    required this.offsetY,
    required this.cameraX,
    required this.cameraY,
    required this.viewW,
    required this.viewH,
    required this.scale,
    required this.primaryColor,
    required this.dividerColor,
    required this.cardColor,
    required this.scaffoldBg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = scaffoldBg.withValues(alpha: 0.3));

    for (final conn in connections) {
      final fromCard = cards.where((c) => c.id == conn.fromCardId).firstOrNull;
      final toCard = cards.where((c) => c.id == conn.toCardId).firstOrNull;
      if (fromCard == null || toCard == null) continue;
      final fx = (fromCard.center.dx - minX) * mmScale + offsetX;
      final fy = (fromCard.center.dy - minY) * mmScale + offsetY;
      final tx = (toCard.center.dx - minX) * mmScale + offsetX;
      final ty = (toCard.center.dy - minY) * mmScale + offsetY;
      canvas.drawLine(Offset(fx, fy), Offset(tx, ty), Paint()..color = dividerColor..strokeWidth = 0.5);
    }

    for (final card in cards) {
      final x = (card.x - minX) * mmScale + offsetX;
      final y = (card.y - minY) * mmScale + offsetY;
      final w = card.width * mmScale;
      final h = card.height * mmScale;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = cardColor.withValues(alpha: 0.4));
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = cardColor.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 0.5);
    }

    final vpLeft = (cameraX - viewW / 2 / scale - minX) * mmScale + offsetX;
    final vpTop = (cameraY - viewH / 2 / scale - minY) * mmScale + offsetY;
    final vpW = (viewW / scale) * mmScale;
    final vpH = (viewH / scale) * mmScale;

    final vpRect = Rect.fromLTWH(vpLeft, vpTop, vpW, vpH);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final outsidePath = Path()..addRect(fullRect);
    final vpPath = Path()..addRect(vpRect);
    final dimPath = Path.combine(PathOperation.difference, outsidePath, vpPath);
    canvas.drawPath(dimPath, Paint()..color = Colors.black.withValues(alpha: 0.25));

    canvas.drawRect(vpRect, Paint()
      ..color = primaryColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill);
    canvas.drawRect(vpRect, Paint()
      ..color = primaryColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter old) {
    return !identical(cards, old.cards) ||
        !identical(connections, old.connections) ||
        cameraX != old.cameraX ||
        cameraY != old.cameraY ||
        scale != old.scale ||
        viewW != old.viewW ||
        viewH != old.viewH ||
        offsetX != old.offsetX ||
        offsetY != old.offsetY;
  }
}

class CanvasPage extends ConsumerWidget {
  const CanvasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CanvasView();
  }
}

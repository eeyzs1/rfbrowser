import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/canvas_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/settings_service.dart';
import '../../data/models/canvas_model.dart';
import '../../data/models/note.dart';
import '../../core/link/link_resolver.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/canvas_painter.dart';

class CanvasView extends ConsumerStatefulWidget {
  const CanvasView({super.key});

  @override
  ConsumerState<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends ConsumerState<CanvasView> {
  double _cameraX = 0;
  double _cameraY = 0;
  double _scale = 1.0;

  String? _selectedCardId;
  String? _connectingFromCardId;
  String? _draggingCardId;
  bool _isResizing = false;
  Offset? _connectingPreviewEnd;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _searchMatchedIds = [];
  int _searchActiveIndex = 0;
  Timer? _searchDebounceTimer;

  Offset? _lastFocalPoint;
  double? _lastScale;

  List<CanvasConnection> _cachedAutoConnections = [];
  List<CanvasCard>? _lastCards;
  List<Note>? _lastNotes;
  bool _lastAutoEnabled = false;
  LinkResolver? _lastLinkResolver;

  static const double _gridSize = 20;
  static const double _minScale = 0.05;
  static const double _maxScale = 8.0;
  static const double _toolbarHeight = 36;
  static const double _resizeHandleSize = 12;

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

  double get _viewW => MediaQuery.of(context).size.width;
  double get _viewH => MediaQuery.of(context).size.height - _toolbarHeight;

  @override
  void initState() {
    super.initState();
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
      setState(() { _cameraX = 0; _cameraY = 0; _scale = 1.0; });
    } else {
      _fitToContent();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
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

  bool _hitTestResizeHandle(Offset worldPos, CanvasCard card) {
    final handleCenter = Offset(card.x + card.width, card.y + card.height);
    final handleSize = _resizeHandleSize / _scale;
    final handleRect = Rect.fromCenter(center: handleCenter, width: handleSize * 2, height: handleSize * 2);
    return handleRect.contains(worldPos);
  }

  CanvasCard? _hitTestCard(Offset worldPos) {
    final cards = ref.read(canvasProvider).cards;
    for (final card in cards.reversed) {
      if (card.rect.contains(worldPos)) return card;
    }
    return null;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _lastScale = _scale;
    final worldPos = _screenToWorld(details.localFocalPoint);

    if (_selectedCardId != null) {
      final selectedCard = ref.read(canvasProvider.notifier).cardById(_selectedCardId!);
      if (selectedCard != null && _hitTestResizeHandle(worldPos, selectedCard)) {
        _isResizing = true;
        _draggingCardId = null;
        return;
      }
    }

    final hit = _hitTestCard(worldPos);
    _draggingCardId = hit?.id;
    _isResizing = false;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isResizing && _selectedCardId != null && details.pointerCount == 1) {
      final card = ref.read(canvasProvider.notifier).cardById(_selectedCardId!);
      if (card != null) {
        final delta = details.focalPoint - (_lastFocalPoint ?? details.focalPoint);
        final newWidth = math.max(80.0, card.width + delta.dx / _scale);
        final newHeight = math.max(60.0, card.height + delta.dy / _scale);
        ref.read(canvasProvider.notifier).updateCardInMemory(
          card.copyWith(
            width: _snapToGrid(newWidth),
            height: _snapToGrid(newHeight),
          ),
        );
      }
    } else if (_draggingCardId != null && details.pointerCount == 1) {
      final card = ref.read(canvasProvider.notifier).cardById(_draggingCardId!);
      if (card != null) {
        final delta = details.focalPoint - (_lastFocalPoint ?? details.focalPoint);
        final newX = card.x + delta.dx / _scale;
        final newY = card.y + delta.dy / _scale;
        ref.read(canvasProvider.notifier).updateCardInMemory(
          card.copyWith(
            x: _snapToGrid(newX),
            y: _snapToGrid(newY),
          ),
        );
      }
    } else if (details.pointerCount == 1) {
      final delta = details.focalPoint - (_lastFocalPoint ?? details.focalPoint);
      setState(() {
        _cameraX -= delta.dx / _scale;
        _cameraY -= delta.dy / _scale;
      });
    } else if (details.pointerCount == 2 && _lastScale != null) {
      final newScale = (_lastScale! * details.scale).clamp(_minScale, _maxScale);
      final focalWorld = _screenToWorld(details.localFocalPoint);
      setState(() {
        _cameraX = focalWorld.dx - (details.localFocalPoint.dx - _viewW / 2) / newScale;
        _cameraY = focalWorld.dy - (details.localFocalPoint.dy - _viewH / 2) / newScale;
        _scale = newScale;
      });
      _lastScale = _scale;
    }
    _lastFocalPoint = details.focalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_draggingCardId != null) {
      setState(() => _selectedCardId = _draggingCardId);
      ref.read(canvasProvider.notifier).persist();
      _draggingCardId = null;
    }
    if (_isResizing) {
      ref.read(canvasProvider.notifier).persist();
      _isResizing = false;
    }
    _lastFocalPoint = null;
    _lastScale = null;
  }

  void _onTapUp(TapUpDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final hit = _hitTestCard(worldPos);
    if (_connectingFromCardId != null && hit != null && hit.id != _connectingFromCardId) {
      _createConnection(_connectingFromCardId!, hit.id);
      setState(() => _connectingFromCardId = null);
    } else {
      setState(() => _selectedCardId = hit?.id);
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final hit = _hitTestCard(worldPos);
    if (hit != null) _openCardContent(hit);
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final hit = _hitTestCard(worldPos);
    final canvasData = ref.read(canvasProvider);
    if (hit != null) {
      setState(() => _selectedCardId = hit.id);
      _showCardContextMenu(details.globalPosition, hit);
    } else {
      _showContextMenu(context, details, canvasData, worldPos);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta.dy;
      final zoomFactor = scrollDelta < 0 ? 1.05 : 0.95;
      final newScale = (_scale * zoomFactor).clamp(_minScale, _maxScale);

      final screenPos = Offset(event.localPosition.dx, event.localPosition.dy - _toolbarHeight);
      final worldBefore = _screenToWorld(screenPos);

      setState(() {
        _scale = newScale;
        final worldAfter = _screenToWorld(screenPos);
        _cameraX += worldBefore.dx - worldAfter.dx;
        _cameraY += worldBefore.dy - worldAfter.dy;
      });
    }
  }

  void _zoomIn() {
    final newScale = (_scale * 1.2).clamp(_minScale, _maxScale);
    setState(() => _scale = newScale);
  }

  void _zoomOut() {
    final newScale = (_scale / 1.2).clamp(_minScale, _maxScale);
    setState(() => _scale = newScale);
  }

  void _zoomReset() {
    setState(() => _scale = 1.0);
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
    setState(() {
      _cameraX = card.x + card.width / 2;
      _cameraY = card.y + card.height / 2;
      _scale = targetScale;
      _selectedCardId = card.id;
    });
  }

  void _deleteSelectedCard() {
    if (_selectedCardId == null) return;
    ref.read(canvasProvider.notifier).removeCard(_selectedCardId!);
    setState(() => _selectedCardId = null);
  }

  void _undo() => ref.read(canvasProvider.notifier).undo();
  void _redo() => ref.read(canvasProvider.notifier).redo();

  @override
  Widget build(BuildContext context) {
    final canvasData = ref.watch(canvasProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final linkResolver = ref.watch(linkResolverProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(canvasProvider.notifier);

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

    final visibleWorldRect = Rect.fromLTWH(
      _cameraX - _viewW / 2 / _scale - _gridSize,
      _cameraY - _viewH / 2 / _scale - _gridSize,
      _viewW / _scale + _gridSize * 2,
      _viewH / _scale + _gridSize * 2,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f3): _searchNext,
        const SingleActivator(LogicalKeyboardKey.f3, shift: true): _searchPrev,
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelectedCard,
        const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelectedCard,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              _buildToolbar(theme, canvasData, autoEnabled, notifier),
              Expanded(
                child: Stack(
                  children: [
                    Listener(
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
                            child: CustomPaint(
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
                              selectedCardId: _selectedCardId,
                              connectingFromCardId: _connectingFromCardId,
                              searchMatchedIds: _searchMatchedIds,
                              searchActiveIndex: _searchActiveIndex,
                              connectingPreviewEnd: _connectingPreviewEnd,
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
                            ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildMinimap(theme, canvasData),
                    _buildZoomControls(theme),
                    _buildStatusBar(theme, canvasData),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme, CanvasData canvasData, bool autoEnabled, CanvasNotifier notifier) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: _toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          _buildCanvasSwitcher(theme),
          const SizedBox(width: 8),
          _toolbarDivider(theme),
          const SizedBox(width: 4),
          _toolbarButton(theme, Icons.add, l.addCard, () {
            final worldPos = Offset(_cameraX, _cameraY);
            _addCardAt(worldPos);
          }),
          _toolbarButton(theme, Icons.link, l.connect, () {
            if (_selectedCardId != null) {
              setState(() => _connectingFromCardId = _selectedCardId);
            }
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
          _toolbarButton(
            theme,
            canvasData.settings.gridVisible ? Icons.grid_on : Icons.grid_off,
            canvasData.settings.gridVisible ? 'Grid: On' : 'Grid: Off',
            () => ref.read(canvasProvider.notifier).toggleGridVisible(),
          ),
          _toolbarButton(
            theme,
            canvasData.settings.snapToGrid ? Icons.grid_on_outlined : Icons.grid_4x4,
            canvasData.settings.snapToGrid ? 'Snap: On' : 'Snap: Off',
            () => ref.read(canvasProvider.notifier).toggleSnapToGrid(),
          ),
          const SizedBox(width: 4),
          _toolbarDivider(theme),
          const SizedBox(width: 4),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.search,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(onTap: _clearSearch, child: const Icon(Icons.close, size: 14))
                    : null,
              ),
              style: theme.textTheme.bodySmall,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmit,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              '${_searchActiveIndex + 1}/${_searchMatchedIds.length}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ],
          const Spacer(),
          _toolbarButton(theme, Icons.fit_screen, 'Fit', _fitToContent),
          _toolbarButton(theme, Icons.delete_outline, 'Clear', () {
            showDialog(context: context, builder: (ctx) => AlertDialog(
              title: Text(l.clearCanvas),
              content: Text(l.clearCanvasConfirm),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error), onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(canvasProvider.notifier).clearCanvas();
                  setState(() { _selectedCardId = null; _connectingFromCardId = null; });
                }, child: Text(l.clear)),
              ],
            ));
          }),
        ],
      ),
    );
  }

  Widget _toolbarDivider(ThemeData theme) {
    return Container(width: 1, height: 16, color: theme.dividerColor);
  }

  Widget _buildZoomControls(ThemeData theme) {
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
              tooltip: 'Zoom In',
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
              tooltip: 'Zoom Out',
              color: theme.hintColor,
            ),
            Container(width: 24, height: 1, color: theme.dividerColor),
            IconButton(
              icon: const Icon(Icons.filter_center_focus, size: 16),
              onPressed: _zoomReset,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Reset Zoom',
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

    return Positioned(
      left: 12,
      bottom: 40,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapUp: (details) {
            final tapLocal = details.localPosition;
            final worldX = minX - padding + (tapLocal.dx) / mmScale;
            final worldY = minY - padding + (tapLocal.dy) / mmScale;
            setState(() {
              _cameraX = worldX;
              _cameraY = worldY;
            });
          },
          child: Container(
            width: minimapW,
            height: minimapH,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
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
                  cameraX: _cameraX,
                  cameraY: _cameraY,
                  viewW: _viewW,
                  viewH: _viewH,
                  scale: _scale,
                  primaryColor: theme.colorScheme.primary,
                  dividerColor: theme.dividerColor,
                  cardColor: theme.hintColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, CanvasData canvasData) {
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
              '${canvasData.cards.length} cards · ${canvasData.connections.length} connections',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.hintColor),
            ),
            const Spacer(),
            if (_selectedCardId != null)
              Text(
                'Selected · Del to delete · Drag corner to resize',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.hintColor),
              ),
            if (_connectingFromCardId != null)
              Text(
                'Click a card to connect · Esc to cancel',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary),
              ),
          ],
        ),
      ),
    );
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
        PopupMenuItem<String>(value: '__new__', child: Row(children: [Icon(Icons.add, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text('New Canvas', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary))])),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == '__new__') { _showCreateCanvasDialog(); }
      else if (value != active) {
        ref.read(canvasProvider.notifier).switchCanvas(value);
        setState(() { _selectedCardId = null; _connectingFromCardId = null; });
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
            if (mounted) { setState(() { _selectedCardId = null; _connectingFromCardId = null; }); WidgetsBinding.instance.addPostFrameCallback((_) => _centerOrFitView()); }
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

  Widget _toolbarButton(ThemeData theme, IconData icon, String tooltip, VoidCallback onTap, {bool enabled = true}) {
    return IconButton(
      icon: Icon(icon, size: 14),
      onPressed: enabled ? onTap : null,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      color: enabled ? theme.hintColor : theme.disabledColor,
    );
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
        const PopupMenuDivider(),
        PopupMenuItem(value: 'fromNote', child: Row(children: [Icon(Icons.library_books, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.fromKnowledgeNote)])),
        if (_selectedCardId != null) ...[
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
        case 'fromNote': _addCardFromNote(worldPos);
        case 'edit': if (_selectedCardId != null) _editCard(_selectedCardId!);
        case 'duplicate': if (_selectedCardId != null) _duplicateCard(_selectedCardId!, worldPos);
        case 'delete': _deleteSelectedCard();
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

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.editCard)])),
        PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.content_copy, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.duplicateCard)])),
        PopupMenuItem(value: 'color', child: Row(children: [Icon(Icons.palette, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.changeColor)])),
        PopupMenuItem(value: 'connect', child: Row(children: [Icon(Icons.add_link, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l.connectFrom)])),
        if (allConns.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(value: 'manageConns', child: Row(children: [Icon(Icons.settings_ethernet, size: 16, color: theme.hintColor), const SizedBox(width: 8), Text(l.manageConnections)])),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: theme.colorScheme.error), const SizedBox(width: 8), Text(l.deleteCard)])),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'edit': _editCard(card.id);
        case 'duplicate': _duplicateCard(card.id, Offset(card.x + 40, card.y + 40));
        case 'color': _showColorPicker(card);
        case 'connect': setState(() => _connectingFromCardId = card.id);
        case 'manageConns': _showConnectionListDialog(card, allConns);
        case 'delete': _deleteSelectedCard();
      }
    });
  }

  void _showColorPicker(CanvasCard card) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.changeColor),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cardColorPresets.map((color) => GestureDetector(
            onTap: () {
              ref.read(canvasProvider.notifier).updateCard(card.copyWith(colorValue: color.toARGB32()));
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
            return ListTile(
              dense: true,
              leading: Icon(e.isAuto ? Icons.auto_fix_high : Icons.link, size: 16, color: e.isAuto ? theme.hintColor : theme.colorScheme.primary),
              title: Text(otherCard?.title ?? otherCardId, overflow: TextOverflow.ellipsis),
              subtitle: Text(e.conn.label.isNotEmpty ? e.conn.label : (e.isAuto ? l.autoConnection : l.manualConnection)),
              trailing: IconButton(
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
    setState(() => _selectedCardId = newCard.id);
  }

  void _addCardAt(Offset pos, {CanvasCardType type = CanvasCardType.note}) {
    final snappedX = _snapToGrid(pos.dx - 120);
    final snappedY = _snapToGrid(pos.dy - 80);
    final card = CanvasCard(id: 'card_${DateTime.now().millisecondsSinceEpoch}', type: type, x: snappedX, y: snappedY, width: 240, height: 160, title: '', content: '');
    ref.read(canvasProvider.notifier).addCard(card);
    setState(() => _selectedCardId = card.id);
    _editCard(card.id);
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
        setState(() => _selectedCardId = card.id);
        Navigator.pop(ctx);
      }))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel))],
    ));
  }

  void _openCardContent(CanvasCard card) {
    if (card.type == CanvasCardType.link && card.content.isNotEmpty) { ref.read(browserProvider.notifier).createTab(url: card.content); return; }
    if (card.noteId != null) { ref.read(knowledgeProvider.notifier).openNote(card.noteId!); return; }
    _editCard(card.id);
  }

  void _editCard(String cardId) {
    final card = ref.read(canvasProvider.notifier).cardById(cardId);
    if (card == null) return;
    final settings = ref.read(settingsProvider);
    final l = AppLocalizations.of(context)!;
    final dialogTheme = Theme.of(context);
    final titleCtrl = TextEditingController(text: card.title);
    final contentCtrl = TextEditingController(text: card.content);
    double cardFontSize = card.fontSize > 0 ? card.fontSize : settings.editorFontSize * 0.85;
    int selectedColorValue = card.colorValue;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Text(l.editCardType(card.type.label)),
      content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtrl, decoration: InputDecoration(labelText: l.noteTitle)),
        const SizedBox(height: 12),
        TextField(controller: contentCtrl, decoration: InputDecoration(labelText: switch (card.type) {
          CanvasCardType.note => l.contentPreview, CanvasCardType.text => l.note, CanvasCardType.image => l.imagePath, CanvasCardType.link => l.url
        }),
          maxLines: card.type == CanvasCardType.note || card.type == CanvasCardType.text ? 5 : 1),
        const SizedBox(height: 12),
        Row(children: [
          Text(l.fontSize, style: dialogTheme.textTheme.bodySmall),
          Expanded(child: Slider(
            value: cardFontSize,
            min: 8,
            max: 32,
            divisions: 24,
            label: cardFontSize.round().toString(),
            onChanged: (v) => setDialogState(() => cardFontSize = v),
          )),
          SizedBox(width: 40, child: Text(cardFontSize.round().toString(), style: dialogTheme.textTheme.bodySmall, textAlign: TextAlign.end)),
        ]),
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
          ));
          Navigator.pop(ctx);
        }, child: Text(l.save)),
      ],
    )));
  }

  void _createConnection(String fromId, String toId) {
    final fromCard = ref.read(canvasProvider.notifier).cardById(fromId);
    final toCard = ref.read(canvasProvider.notifier).cardById(toId);
    if (fromCard == null || toCard == null) return;
    final (fromSide, toSide) = CanvasConnection.computeSides(fromCard, toCard);
    final conn = CanvasConnection(id: 'conn_${DateTime.now().millisecondsSinceEpoch}', fromCardId: fromId, toCardId: toId, fromSide: fromSide, toSide: toSide, isAuto: false);
    ref.read(canvasProvider.notifier).addConnection(conn);
  }

  void _fitToContent() {
    final cards = ref.read(canvasProvider).cards;
    if (cards.isEmpty) { setState(() { _cameraX = 0; _cameraY = 0; _scale = 1.0; }); return; }
    double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final card in cards) { minX = math.min(minX, card.x); minY = math.min(minY, card.y); maxX = math.max(maxX, card.x + card.width); maxY = math.max(maxY, card.y + card.height); }
    final contentW = maxX - minX + 100;
    final contentH = maxY - minY + 100;
    final fitScale = math.min(_viewW / contentW, _viewH / contentH).clamp(0.05, 2.0);
    setState(() {
      _cameraX = (minX + maxX) / 2;
      _cameraY = (minY + maxY) / 2;
      _scale = fitScale;
    });
  }
}

class _MinimapPainter extends CustomPainter {
  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final double minX, minY, mmScale;
  final double cameraX, cameraY, viewW, viewH, scale;
  final Color primaryColor, dividerColor, cardColor;

  _MinimapPainter({
    required this.cards,
    required this.connections,
    required this.minX,
    required this.minY,
    required this.mmScale,
    required this.cameraX,
    required this.cameraY,
    required this.viewW,
    required this.viewH,
    required this.scale,
    required this.primaryColor,
    required this.dividerColor,
    required this.cardColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connections) {
      final fromCard = cards.where((c) => c.id == conn.fromCardId).firstOrNull;
      final toCard = cards.where((c) => c.id == conn.toCardId).firstOrNull;
      if (fromCard == null || toCard == null) continue;
      final fx = (fromCard.center.dx - minX) * mmScale;
      final fy = (fromCard.center.dy - minY) * mmScale;
      final tx = (toCard.center.dx - minX) * mmScale;
      final ty = (toCard.center.dy - minY) * mmScale;
      canvas.drawLine(Offset(fx, fy), Offset(tx, ty), Paint()..color = dividerColor..strokeWidth = 0.5);
    }

    for (final card in cards) {
      final x = (card.x - minX) * mmScale;
      final y = (card.y - minY) * mmScale;
      final w = card.width * mmScale;
      final h = card.height * mmScale;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = cardColor.withValues(alpha: 0.4));
    }

    final vpLeft = (cameraX - viewW / 2 / scale - minX) * mmScale;
    final vpTop = (cameraY - viewH / 2 / scale - minY) * mmScale;
    final vpW = (viewW / scale) * mmScale;
    final vpH = (viewH / scale) * mmScale;
    canvas.drawRect(Rect.fromLTWH(vpLeft, vpTop, vpW, vpH), Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(vpLeft, vpTop, vpW, vpH), Paint()
      ..color = primaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter old) {
    return !identical(cards, old.cards) ||
        !identical(connections, old.connections) ||
        cameraX != old.cameraX ||
        cameraY != old.cameraY ||
        scale != old.scale;
  }
}

class CanvasPage extends ConsumerWidget {
  const CanvasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CanvasView();
  }
}

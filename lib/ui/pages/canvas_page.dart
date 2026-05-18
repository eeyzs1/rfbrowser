// ignore_for_file: unused_element, unused_element_parameter
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
import '../../services/shortcut_service.dart';
import '../../data/models/canvas_model.dart';
import '../../data/models/note.dart';
import '../../data/stores/vault_store.dart';
import '../../core/link/link_resolver.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/canvas_painter.dart';
import '../layout/keyboard_util.dart';
import '../widgets/canvas/hover_popup_menu.dart';
import '../widgets/canvas/minimap_painter.dart';

part 'canvas/canvas_input_handlers.dart';
part 'canvas/canvas_toolbar.dart';
part 'canvas/canvas_panels.dart';
part 'canvas/canvas_canvas_mgmt.dart';
part 'canvas/canvas_context_menus.dart';
part 'canvas/canvas_dialogs.dart';
part 'canvas/canvas_export_panels.dart';

enum _ResizeEdge { none, right, bottom, corner }

class _CameraNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}


class CanvasView extends ConsumerStatefulWidget {
  const CanvasView({super.key});

  @override
  ConsumerState<CanvasView> createState() => _CanvasViewState();
}

abstract class _CanvasViewStateBase extends ConsumerState<CanvasView>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  final _CameraNotifier _cameraNotifier = _CameraNotifier();
  bool _isFreehandDrawing = false;
  String? _freehandCardId;
  List<Offset> _freehandPoints = [];
  double _cameraX = 0;
  double _cameraY = 0;
  double _scale = 1.0;

  List<String> get _selectedCardIds => ref.read(canvasProvider).selectedCardIds;
  String? get _inlineEditingCardId =>
      ref.read(canvasProvider).inlineEditingCardId;
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


  void _initCanvas();
  void _centerOrFitView();
  void _startInlineEditing(String cardId);
  void _finishInlineEditing();
  Offset _screenToWorld(Offset screenPos);
  double _snapToGrid(double value);
  _ResizeEdge _hitTestResizeHandle(Offset worldPos, CanvasCard card);
  CanvasCard? _hitTestCardWithResize(Offset worldPos);
  CanvasCard? _hitTestCard(Offset worldPos);
  (String, int)? _hitTestWaypoint(Offset worldPos);
  (String, double)? _hitTestConnectionLine(Offset worldPos);
  List<Offset> _connectionPathPoints(Offset fromPoint, Offset toPoint, List<Offset> waypoints, ConnectionPath pathType);
  Offset _cubicBezierPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t);
  (String, ConnectionSide, double)? _hitTestConnectionPoint(Offset worldPos);
  (Offset, int) _snapWaypointToConnection(String connId, Offset worldPos);
  Offset _projectPointOnSegment(Offset p, Offset a, Offset b);
  double _pointToSegmentDist(Offset p, Offset a, Offset b);
  List<AlignmentGuide> _computeAlignmentGuides(CanvasCard draggedCard, List<CanvasCard> allCards);
  double? _getSnapOffset(CanvasCard draggedCard, List<CanvasCard> allCards);
  double? _getSnapOffsetY(CanvasCard draggedCard, List<CanvasCard> allCards);
  void _onScaleStart(ScaleStartDetails details);
  void _onScaleUpdate(ScaleUpdateDetails details);
  void _onScaleEnd(ScaleEndDetails details);
  void _onTapUp(TapUpDetails details);
  void _onDoubleTapDown(TapDownDetails details);
  void _onSecondaryTapUp(TapUpDetails details);
  void _onPointerSignal(PointerSignalEvent event);
  void _onHover(PointerHoverEvent event);
  MouseCursor _getCursor();
  void _zoomIn();
  void _zoomOut();
  void _zoomReset();
  void _onSearchChanged(String query);
  void _onSearchSubmit(String query);
  void _clearSearch();
  void _toggleSearch();
  void _searchNext();
  void _searchPrev();
  void _panToFirstMatch();
  void _panToMatch(int index);
  void _deleteSelectedCards();
  void _undo();
  void _redo();
  void _selectAll();
  void _groupSelected();
  void _ungroupSelected();
  Widget _buildToolbar(ThemeData theme, CanvasData canvasData, bool autoEnabled, CanvasNotifier notifier, AppLocalizations l);
  Widget _toolbarDivider(ThemeData theme);
  Widget _popupRow(IconData icon, String text, {String? tooltip});
  Widget _toolbarButton(ThemeData theme, IconData icon, String tooltip, VoidCallback onTap, {bool enabled = true, bool highlight = false});
  Widget _buildZoomControls(ThemeData theme);
  Widget _buildMinimap(ThemeData theme, CanvasData canvasData);
  Widget _buildInlineEditor(ThemeData theme, CanvasData canvasData, AppSettings settings);
  Offset _w2s(double wx, double wy);
  Widget _buildCanvasSwitcher(ThemeData theme);
  void _showCanvasSelector(BuildContext context, ThemeData theme);
  void _showCreateCanvasDialog();
  void _showRenameDialog(String oldName);
  void _confirmDeleteCanvas(String name);
  void _showWaypointContextMenu(Offset position, String connId, int waypointIndex);
  void _showContextMenu(BuildContext context, TapUpDetails details, CanvasData canvasData, Offset worldPos);
  void _showConnectionContextMenu(Offset position, String connId, Offset worldPos);
  void _showCardContextMenu(Offset position, CanvasCard card);
  void _showColorPicker(CanvasCard card);
  void _showConnectionListDialog(CanvasCard card, List<({CanvasConnection conn, bool isAuto})> allConns);
  void _showConnectionStyleDialog(CanvasConnection conn);
  void _duplicateCard(String cardId, Offset pos);
  void _addCardAt(Offset pos, {CanvasCardType type = CanvasCardType.note});
  void _addContainerAt(Offset pos);
  void _toggleContainerCollapse(String cardId);
  void _saveCardToScratchpad(CanvasCard card);
  void _promoteCardToNote(CanvasCard card);
  void _showMoveToLayerDialog(CanvasCard card);
  void _showBackgroundColorPicker();
  void _showDefaultStyleDialog();
  void _showAddTagDialog(CanvasCard card);
  void _showRemoveTagDialog(CanvasCard card);
  void _showImportDialog(String format);
  void _shareViaUrl();
  void _addCardFromNote(Offset pos);
  void _openCardContent(CanvasCard card);
  void _editCard(String cardId);
  void _createConnection(String fromId, String toId);
  void _createConnectionWithSides(String fromId, String toId, ConnectionSide? fromSide, ConnectionSide? toSide, [double fromSideOffset, double toSideOffset]);
  void _fitToContent();
  void _handleExport(String format);
  Future<void> _exportToPng();
  void _saveExportFile(String filename, String content);
  void _showLayerPanel();
  void _showScratchpad();
}


class _CanvasViewState extends _CanvasViewStateBase
    with _CanvasInputHandlersMixin, _CanvasToolbarMixin, _CanvasPanelsMixin, _CanvasCanvasMgmtMixin, _CanvasContextMenusMixin, _CanvasDialogsMixin, _CanvasExportPanelsMixin {
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
  @override
  Future<void> _initCanvas() async {
    final notifier = ref.read(canvasProvider.notifier);
    await notifier.initialize();
    if (mounted) _centerOrFitView();
  }
  @override
  void _centerOrFitView() {
    final cards = ref.read(canvasProvider).cards;
    if (cards.isEmpty) {
      _cameraX = 0;
      _cameraY = 0;
      _scale = 1.0;
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
  @override
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
  @override
  void _finishInlineEditing() {
    final editingId = _inlineEditingCardId;
    if (editingId == null) return;
    final card = ref.read(canvasProvider.notifier).cardById(editingId);
    if (card != null) {
      final newTitle = _inlineTitleCtrl.text.trim();
      final newContent = _inlineContentCtrl.text.trim();
      if (newTitle != card.title || newContent != card.content) {
        ref
            .read(canvasProvider.notifier)
            .updateCard(card.copyWith(title: newTitle, content: newContent));
      }
    }
    ref.read(canvasProvider.notifier).finishInlineEditing();
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
      _cachedAutoConnections = notifier.deriveAutoConnections(
        knowledgeState.notes,
        linkResolver,
      );
    }
    final autoConns = _cachedAutoConnections;

    final shortcutSvc = ref.read(shortcutServiceProvider);
    final undoActivator = parseShortcut(shortcutSvc.getShortcut('canvas_undo') ?? 'Ctrl+Z');
    final redoActivator = parseShortcut(shortcutSvc.getShortcut('canvas_redo') ?? 'Ctrl+Y');
    final deleteActivator = parseShortcut(shortcutSvc.getShortcut('canvas_delete') ?? 'Delete');
    final selectAllActivator = parseShortcut(shortcutSvc.getShortcut('canvas_select_all') ?? 'Ctrl+A');
    final groupActivator = parseShortcut(shortcutSvc.getShortcut('canvas_group') ?? 'Ctrl+G');
    final ungroupActivator = parseShortcut(shortcutSvc.getShortcut('canvas_ungroup') ?? 'Ctrl+Shift+G');

    final Map<ShortcutActivator, VoidCallback> canvasBindings = {};
    canvasBindings[const SingleActivator(LogicalKeyboardKey.f3)] = _searchNext;
    canvasBindings[const SingleActivator(LogicalKeyboardKey.f3, shift: true)] = _searchPrev;
    if (undoActivator != null) canvasBindings[undoActivator] = _undo;
    if (redoActivator != null) canvasBindings[redoActivator] = _redo;
    canvasBindings[const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true)] = _redo;
    canvasBindings[const SingleActivator(LogicalKeyboardKey.escape)] = () {
      if (_styleBrushMode) {
        setState(() {
          _styleBrushMode = false;
          _copiedStyle = null;
        });
        return;
      }
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
      if (ref.read(canvasProvider).selectedConnectionId != null) {
        ref.read(canvasProvider.notifier).selectConnection(null);
        return;
      }
      _finishInlineEditing();
    };
    if (deleteActivator != null) canvasBindings[deleteActivator] = _deleteSelectedCards;
    if (selectAllActivator != null) canvasBindings[selectAllActivator] = _selectAll;
    if (groupActivator != null) canvasBindings[groupActivator] = _groupSelected;
    if (ungroupActivator != null) canvasBindings[ungroupActivator] = _ungroupSelected;

    return CallbackShortcuts(
      bindings: canvasBindings,
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
                            _cameraX - _viewW / 2 / _scale - _CanvasViewStateBase._gridSize,
                            _cameraY - _viewH / 2 / _scale - _CanvasViewStateBase._gridSize,
                            _viewW / _scale + _CanvasViewStateBase._gridSize * 2,
                            _viewH / _scale + _CanvasViewStateBase._gridSize * 2,
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
                                            listenable: Listenable.merge([
                                              _animController,
                                              _cameraNotifier,
                                            ]),
                                            builder: (context, _) => CustomPaint(
                                              painter: CanvasPainter(
                                                cards: canvasData.cards,
                                                connections:
                                                    canvasData.connections,
                                                autoConnections: autoConns,
                                                cameraX: _cameraX,
                                                cameraY: _cameraY,
                                                scale: _scale,
                                                viewW: _viewW,
                                                viewH: _viewH,
                                                gridSize: _CanvasViewStateBase._gridSize,
                                                visibleWorldRect:
                                                    visibleWorldRect,
                                                selectedCardIds:
                                                    canvasData.selectedCardIds,
                                                connectingFromCardId:
                                                    _connectingFromCardId,
                                                searchMatchedIds:
                                                    _searchMatchedIds,
                                                searchActiveIndex:
                                                    _searchActiveIndex,
                                                connectingPreviewEnd:
                                                    _connectingPreviewEnd,
                                                hoveredCardId: _hoverCardId,
                                                hoveredConnectionSide:
                                                    _hoveredConnectionSide,
                                                selectedConnectionId: canvasData
                                                    .selectedConnectionId,
                                                primaryColor:
                                                    theme.colorScheme.primary,
                                                dividerColor:
                                                    theme.dividerColor,
                                                scaffoldBg: theme
                                                    .scaffoldBackgroundColor,
                                                isDark:
                                                    theme.brightness ==
                                                    Brightness.dark,
                                                hintColor: theme.hintColor,
                                                bodySmallStyle:
                                                    theme.textTheme.bodySmall,
                                                bodyMediumStyle:
                                                    theme.textTheme.bodyMedium,
                                                knowledgeState: knowledgeState,
                                                baseFontSize:
                                                    settings.editorFontSize,
                                                gridVisible: canvasData
                                                    .settings
                                                    .gridVisible,
                                                inlineEditingCardId:
                                                    _inlineEditingCardId,
                                                groups: canvasData.groups,
                                                layers: canvasData.layers,
                                                selectionRect: _selectionRect,
                                                alignmentGuides:
                                                    _alignmentGuides,
                                                backgroundColorValue: canvasData
                                                    .settings
                                                    .backgroundColorValue,
                                                rulersVisible: canvasData
                                                    .settings
                                                    .rulersVisible,
                                                animationValue:
                                                    _animController.value,
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
                                builder: (context, _) =>
                                    _buildMinimap(theme, canvasData),
                              ),
                              ListenableBuilder(
                                listenable: _cameraNotifier,
                                builder: (context, _) =>
                                    _buildZoomControls(theme),
                              ),
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

}

class CanvasPage extends ConsumerWidget {
  const CanvasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CanvasView();
  }
}

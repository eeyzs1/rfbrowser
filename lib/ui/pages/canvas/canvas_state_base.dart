// ignore_for_file: unused_element, unused_element_parameter
part of '../canvas_page.dart';

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
  bool _hadFlowAnimation = false;

  /// 是否显示首次打开画布的交互引导浮层。
  bool _showCanvasGuide = false;

  final Map<String, ui.Image> _imageCache = {};

  Future<void> _loadImageCards(List<CanvasCard> cards) async {
    final imageCards = cards.where(
      (c) => c.type == CanvasCardType.image && c.imagePath != null,
    );
    for (final card in imageCards) {
      final path = card.imagePath!;
      if (_imageCache.containsKey(path)) continue;
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _imageCache[path] = frame.image;
      } catch (_) {
        // Ignore load errors for invalid/missing images
      }
    }
    if (mounted) setState(() {});
  }

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

  // Abstract method declarations - implemented by mixins on this base class

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
  List<Offset> _connectionPathPoints(
    Offset fromPoint,
    Offset toPoint,
    List<Offset> waypoints,
    ConnectionPath pathType,
  );
  Offset _cubicBezierPoint(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  );
  (String, ConnectionSide, double)? _hitTestConnectionPoint(Offset worldPos);
  (Offset, int) _snapWaypointToConnection(String connId, Offset worldPos);
  Offset _projectPointOnSegment(Offset p, Offset a, Offset b);
  double _pointToSegmentDist(Offset p, Offset a, Offset b);
  List<AlignmentGuide> _computeAlignmentGuides(
    CanvasCard draggedCard,
    List<CanvasCard> allCards,
  );
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
  Widget _buildToolbar(
    ThemeData theme,
    CanvasData canvasData,
    bool autoEnabled,
    CanvasNotifier notifier,
    AppLocalizations l,
  );
  Widget _toolbarDivider(ThemeData theme);
  Widget _popupRow(IconData icon, String text, {Widget? trailing, String? tooltip});
  List<Widget> _buildAlignPopupSection(
    ThemeData theme,
    CanvasData canvasData,
    AppLocalizations l,
  );
  Widget _buildViewPopup(ThemeData theme, CanvasData canvasData, AppLocalizations l);
  Widget _buildCreatePopup(ThemeData theme, AppLocalizations l);
  Widget _buildShapesPopup(ThemeData theme, AppLocalizations l);
  Widget _buildTemplatesPopup(ThemeData theme, AppLocalizations l);
  Widget _buildAutoLayoutPopup(ThemeData theme, AppLocalizations l);
  Widget _buildExportPopup(ThemeData theme, AppLocalizations l);
  Widget _buildOrganizePopup(ThemeData theme, AppLocalizations l);
  Widget _buildSettingsPopup(ThemeData theme, CanvasData canvasData, AppLocalizations l);
  Widget _toolbarButton(
    ThemeData theme,
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool enabled = true,
    bool highlight = false,
  });
  Widget _buildZoomControls(ThemeData theme);
  Widget _buildMinimap(ThemeData theme, CanvasData canvasData);
  Widget _buildInlineEditor(
    ThemeData theme,
    CanvasData canvasData,
    AppSettings settings,
  );
  Offset _w2s(double wx, double wy);
  Widget _buildCanvasSwitcher(ThemeData theme);
  void _showCanvasSelector(BuildContext context, ThemeData theme);
  void _showCreateCanvasDialog();
  void _showRenameDialog(String oldName);
  void _confirmDeleteCanvas(String name);
  void _showWaypointContextMenu(
    Offset position,
    String connId,
    int waypointIndex,
  );
  void _showContextMenu(
    BuildContext context,
    TapUpDetails details,
    CanvasData canvasData,
    Offset worldPos,
  );
  void _showConnectionContextMenu(
    Offset position,
    String connId,
    Offset worldPos,
  );
  void _showCardContextMenu(Offset position, CanvasCard card);
  void _showColorPicker(CanvasCard card);
  void _showConnectionListDialog(
    CanvasCard card,
    List<({CanvasConnection conn, bool isAuto})> allConns,
  );
  void _showConnectionStyleDialog(CanvasConnection conn);
  void _duplicateCard(String cardId, Offset pos);
  Future<void> _addCardAt(
    Offset pos, {
    CanvasCardType type = CanvasCardType.note,
  });
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
  void _createConnectionWithSides(
    String fromId,
    String toId,
    ConnectionSide? fromSide,
    ConnectionSide? toSide, [
    double fromSideOffset,
    double toSideOffset,
  ]);
  void _fitToContent();
  void _handleExport(String format);
  Future<void> _exportToPng();
  void _saveExportFile(String filename, String content);
  void _showLayerPanel();
  void _showScratchpad();
  Widget _buildActiveFilterBanner(ThemeData theme, CanvasData canvasData);
}

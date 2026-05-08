import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/canvas_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../data/models/canvas_model.dart';
import '../../data/models/note.dart';
import '../../core/link/link_resolver.dart';
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
    final hit = _hitTestCard(worldPos);
    _draggingCardId = hit?.id;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_draggingCardId != null && details.pointerCount == 1) {
      final card = ref.read(canvasProvider.notifier).cardById(_draggingCardId!);
      if (card != null) {
        final delta = details.focalPoint - (_lastFocalPoint ?? details.focalPoint);
        ref.read(canvasProvider.notifier).updateCardInMemory(
          card.copyWith(
            x: card.x + delta.dx / _scale,
            y: card.y + delta.dy / _scale,
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
      _showConnectionContextMenu(details.globalPosition, hit);
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

  @override
  Widget build(BuildContext context) {
    final canvasData = ref.watch(canvasProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final linkResolver = ref.watch(linkResolverProvider);
    final theme = Theme.of(context);

    final autoEnabled = canvasData.settings.autoConnectionsEnabled;

    if (!identical(_lastCards, canvasData.cards) ||
        !identical(_lastNotes, knowledgeState.notes) ||
        _lastAutoEnabled != autoEnabled ||
        !identical(_lastLinkResolver, linkResolver)) {
      _lastCards = canvasData.cards;
      _lastNotes = knowledgeState.notes;
      _lastAutoEnabled = autoEnabled;
      _lastLinkResolver = linkResolver;
      _cachedAutoConnections = ref.read(canvasProvider.notifier)
          .deriveAutoConnections(knowledgeState.notes, linkResolver);
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
      },
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            _buildToolbar(theme, canvasData, autoEnabled),
            Expanded(
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
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme, CanvasData canvasData, bool autoEnabled) {
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
          const SizedBox(width: 12),
          _toolbarButton(theme, Icons.add, '添加卡片', () {
            final worldPos = Offset(_cameraX, _cameraY);
            _addCardAt(worldPos);
          }),
          _toolbarButton(theme, Icons.link, '连接', () {
            if (_selectedCardId != null) {
              setState(() => _connectingFromCardId = _selectedCardId);
            }
          }),
          _toolbarButton(theme, autoEnabled ? Icons.auto_fix_high : Icons.auto_fix_off,
            autoEnabled ? '自动连接: 开' : '自动连接: 关',
            () => ref.read(canvasProvider.notifier).toggleAutoConnections(),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search cards...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(onTap: _clearSearch, child: const Icon(Icons.close, size: 14))
                    : null,
              ),
              style: TextStyle(fontSize: 12),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmit,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              '${_searchActiveIndex + 1}/${_searchMatchedIds.length}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ],
          const Spacer(),
          Text('${canvasData.cards.length} cards', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: 11)),
          const SizedBox(width: 8),
          _toolbarButton(theme, Icons.fit_screen, 'Fit', _fitToContent),
          _toolbarButton(theme, Icons.delete_outline, 'Clear', () {
            showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('清除画布'),
              content: const Text('移除所有卡片和连接？此操作无法撤销。'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(canvasProvider.notifier).clearCanvas();
                  setState(() { _selectedCardId = null; _connectingFromCardId = null; });
                }, child: const Text('清除')),
              ],
            ));
          }),
        ],
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
          Expanded(child: Text(name, style: TextStyle(fontWeight: name == active ? FontWeight.w600 : FontWeight.w400, fontSize: 13), overflow: TextOverflow.ellipsis)),
          if (name != active) GestureDetector(onTap: () { Navigator.pop(context); _showRenameDialog(name); }, child: Icon(Icons.edit, size: 14, color: theme.hintColor)),
          if (name != active && names.length > 1) GestureDetector(onTap: () { Navigator.pop(context); _confirmDeleteCanvas(name); }, child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.delete, size: 14, color: Colors.red))),
        ]))),
        const PopupMenuDivider(),
        PopupMenuItem<String>(value: '__new__', child: Row(children: [Icon(Icons.add, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text('New Canvas', style: TextStyle(fontSize: 13, color: theme.colorScheme.primary))])),
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
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('New Canvas'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Canvas name'), autofocus: true,
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
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final name = controller.text.trim();
          if (await ref.read(canvasProvider.notifier).createCanvas(name)) {
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            await ref.read(canvasProvider.notifier).switchCanvas(name);
            if (mounted) { setState(() { _selectedCardId = null; _connectingFromCardId = null; }); WidgetsBinding.instance.addPostFrameCallback((_) => _centerOrFitView()); }
          }
        }, child: const Text('Create')),
      ],
    ));
  }

  void _showRenameDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Rename Canvas'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'New name'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (await ref.read(canvasProvider.notifier).renameCanvas(oldName, controller.text.trim())) {
            if (!ctx.mounted) return; Navigator.pop(ctx);
          }
        }, child: const Text('Rename')),
      ],
    ));
  }

  void _confirmDeleteCanvas(String name) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Canvas'),
      content: Text('Delete "$name"? This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
          await ref.read(canvasProvider.notifier).deleteCanvas(name);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          if (mounted) _centerOrFitView();
        }, child: const Text('Delete')),
      ],
    ));
  }

  Widget _toolbarButton(ThemeData theme, IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, size: 14), onPressed: onTap, tooltip: tooltip, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28), color: theme.hintColor);
  }

  void _showContextMenu(BuildContext context, TapUpDetails details, CanvasData canvasData, Offset worldPos) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx + 1, details.globalPosition.dy + 1),
      items: [
        PopupMenuItem(value: 'note', child: Row(children: [Icon(Icons.description, size: 16), const SizedBox(width: 8), const Text('Note Card')])),
        PopupMenuItem(value: 'text', child: Row(children: [Icon(Icons.text_fields, size: 16), const SizedBox(width: 8), const Text('Text Card')])),
        PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.image, size: 16), const SizedBox(width: 8), const Text('Image Card')])),
        PopupMenuItem(value: 'link', child: Row(children: [Icon(Icons.link, size: 16), const SizedBox(width: 8), const Text('Link Card')])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'fromNote', child: Row(children: [Icon(Icons.library_books, size: 16), const SizedBox(width: 8), const Text('From Knowledge Note')])),
        if (_selectedCardId != null) ...[const PopupMenuDivider(), PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), const SizedBox(width: 8), const Text('Edit Card')])), PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), const SizedBox(width: 8), const Text('Delete Card')]))],
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
        case 'delete': if (_selectedCardId != null) { ref.read(canvasProvider.notifier).removeCard(_selectedCardId!); setState(() => _selectedCardId = null); }
      }
    });
  }

  void _showConnectionContextMenu(Offset position, CanvasCard card) {
    final canvasData = ref.read(canvasProvider);
    final connections = canvasData.connections.where((c) => c.fromCardId == card.id || c.toCardId == card.id).toList();
    final linkResolver = ref.read(linkResolverProvider);
    final knowledgeState = ref.read(knowledgeProvider);
    final autoConns = ref.read(canvasProvider.notifier).deriveAutoConnections(knowledgeState.notes, linkResolver);
    final autoConnections = autoConns.where((c) => c.fromCardId == card.id || c.toCardId == card.id).toList();
    final allConns = [...connections.map((c) => (conn: c, isAuto: c.isAuto)), ...autoConnections.map((c) => (conn: c, isAuto: true))];
    if (allConns.isEmpty) return;
    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        for (int i = 0; i < allConns.length; i++)
          PopupMenuItem(value: i, child: Row(children: [Icon(allConns[i].isAuto ? Icons.auto_fix_high : Icons.link, size: 16), const SizedBox(width: 8), Text(allConns[i].isAuto ? 'Auto: ${allConns[i].conn.fromCardId} -> ${allConns[i].conn.toCardId}' : 'Manual: ${allConns[i].conn.fromCardId} -> ${allConns[i].conn.toCardId}', style: const TextStyle(fontSize: 12))])),
        const PopupMenuDivider(),
        PopupMenuItem(value: -1, child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), const SizedBox(width: 8), const Text('Delete All Connections')])),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == -1) { for (final e in allConns) { try { ref.read(canvasProvider.notifier).removeConnection(e.conn.id); } catch (_) { debugPrint('Canvas: failed to remove connection ${e.conn.id}'); } } return; }
      final selected = allConns[value];
      if (selected.isAuto) { ref.read(canvasProvider.notifier).addConnection(selected.conn.copyWith(isAuto: false)); }
      else { ref.read(canvasProvider.notifier).removeConnection(selected.conn.id); }
    });
  }

  void _addCardAt(Offset pos, {CanvasCardType type = CanvasCardType.note}) {
    final card = CanvasCard(id: 'card_${DateTime.now().millisecondsSinceEpoch}', type: type, x: pos.dx - 120, y: pos.dy - 80, width: 240, height: 160, title: '', content: '');
    ref.read(canvasProvider.notifier).addCard(card);
    setState(() => _selectedCardId = card.id);
    _editCard(card.id);
  }

  void _addCardFromNote(Offset pos) {
    final notes = ref.read(knowledgeProvider).notes;
    if (notes.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No notes in knowledge base'))); return; }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Select Note'),
      content: SizedBox(width: 300, child: ListView.builder(shrinkWrap: true, itemCount: notes.length, itemBuilder: (ctx, i) => ListTile(dense: true, title: Text(notes[i].title, overflow: TextOverflow.ellipsis), onTap: () {
        final note = notes[i];
        final card = CanvasCard(id: 'card_${DateTime.now().millisecondsSinceEpoch}', type: CanvasCardType.note, x: pos.dx - 120, y: pos.dy - 80, width: 280, height: 200, title: note.title, content: note.content.length > 500 ? '${note.content.substring(0, 500)}...' : note.content, noteId: note.id);
        ref.read(canvasProvider.notifier).addCard(card);
        setState(() => _selectedCardId = card.id);
        Navigator.pop(ctx);
      }))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
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
    final titleCtrl = TextEditingController(text: card.title);
    final contentCtrl = TextEditingController(text: card.content);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Edit ${card.type.label}'),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 12),
        TextField(controller: contentCtrl, decoration: InputDecoration(labelText: switch (card.type) {
          CanvasCardType.note => 'Content', CanvasCardType.text => 'Text', CanvasCardType.image => 'Image path', CanvasCardType.link => 'URL' }),
          maxLines: card.type == CanvasCardType.note || card.type == CanvasCardType.text ? 5 : 1),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          ref.read(canvasProvider.notifier).updateCard(card.copyWith(title: titleCtrl.text.trim(), content: contentCtrl.text.trim()));
          Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    ));
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

class CanvasPage extends ConsumerWidget {
  const CanvasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CanvasView();
  }
}

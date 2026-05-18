import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/canvas_model.dart';
import '../data/models/note.dart';
import '../data/stores/vault_store.dart';
import '../core/link/link_resolver.dart';
import 'canvas/canvas_layout_service.dart';
import 'canvas/canvas_export_service.dart';
import 'canvas/canvas_layers_service.dart';
import 'canvas/canvas_scratchpad_service.dart';
import 'canvas/canvas_templates_service.dart';

class CanvasNotifier extends Notifier<CanvasData> {
  final CanvasLayoutService _layoutService;
  final CanvasExportService _exportService;
  final CanvasLayersService _layersService;
  final CanvasScratchpadService _scratchpadService;

  Timer? _debounceTimer;
  SharedPreferences? _prefs;
  List<String> _canvasNames = ['default'];
  String _activeCanvasName = 'default';
  final List<CanvasData> _undoStack = [];
  final List<CanvasData> _redoStack = [];
  static const int _maxHistory = 50;

  CanvasNotifier({
    CanvasLayoutService? layoutService,
    CanvasExportService? exportService,
    CanvasLayersService? layersService,
    CanvasScratchpadService? scratchpadService,
  })  : _layoutService = layoutService ?? const CanvasLayoutService(),
        _exportService = exportService ?? const CanvasExportService(),
        _layersService = layersService ?? const CanvasLayersService(),
        _scratchpadService = scratchpadService ?? const CanvasScratchpadService();

  String get activeCanvasName => _activeCanvasName;
  List<String> get canvasNames => List.unmodifiable(_canvasNames);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<SharedPreferences> get _ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  CanvasData build() => CanvasData();

  void _pushUndo() {
    _undoStack.add(state);
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(state);
    state = _undoStack.removeLast();
    _debouncedSave();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(state);
    state = _redoStack.removeLast();
    _debouncedSave();
  }

  Future<void> initialize() async {
    await _loadCanvasList();
    await _loadFromFile();
  }

  Future<void> _loadCanvasList() async {
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
      final listFile = File(
        p.join(vaultPath, '.rf', 'canvases', '_canvas_list.json'),
      );
      if (await listFile.exists()) {
        final json =
            jsonDecode(await listFile.readAsString()) as Map<String, dynamic>;
        _canvasNames =
            (json['canvases'] as List?)?.cast<String>() ?? ['default'];
        _activeCanvasName = json['active'] as String? ?? 'default';
        if (!_canvasNames.contains(_activeCanvasName)) {
          _activeCanvasName = _canvasNames.isNotEmpty
              ? _canvasNames.first
              : 'default';
        }
        if (_canvasNames.isEmpty) _canvasNames = ['default'];
      }
    } catch (_) {
      _canvasNames = ['default'];
      _activeCanvasName = 'default';
    }
  }

  Future<void> _saveCanvasList() async {
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
      final dir = Directory(p.join(vaultPath, '.rf', 'canvases'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final listFile = File(p.join(dir.path, '_canvas_list.json'));
      await listFile.writeAsString(
        jsonEncode({'canvases': _canvasNames, 'active': _activeCanvasName}),
      );
    } catch (_) {
      debugPrint('Canvas: failed to save canvas list');
    }
  }

  bool get autoConnectionsEnabled => state.settings.autoConnectionsEnabled;

  void toggleAutoConnections() {
    final newSettings = state.settings.copyWith(
      autoConnectionsEnabled: !state.settings.autoConnectionsEnabled,
    );
    state = state.copyWith(settings: newSettings);
    _debouncedSave();
  }

  void toggleSnapToGrid() {
    final newSettings = state.settings.copyWith(
      snapToGrid: !state.settings.snapToGrid,
    );
    state = state.copyWith(settings: newSettings);
    _debouncedSave();
  }

  void toggleGridVisible() {
    final newSettings = state.settings.copyWith(
      gridVisible: !state.settings.gridVisible,
    );
    state = state.copyWith(settings: newSettings);
    _debouncedSave();
  }

  void selectCard(String? cardId, {bool additive = false}) {
    if (cardId == null) {
      state = state.copyWith(clearSelectedCardIds: true);
    } else if (additive) {
      final ids = List<String>.from(state.selectedCardIds);
      if (ids.contains(cardId)) {
        ids.remove(cardId);
      } else {
        ids.add(cardId);
      }
      state = state.copyWith(
        selectedCardIds: ids,
        clearSelectedConnectionId: true,
      );
    } else {
      state = state.copyWith(
        selectedCardIds: [cardId],
        clearSelectedConnectionId: true,
      );
    }
  }

  void selectCards(List<String> cardIds) {
    state = state.copyWith(
      selectedCardIds: cardIds,
      clearSelectedConnectionId: true,
    );
  }

  void addToSelection(String cardId) {
    final ids = List<String>.from(state.selectedCardIds);
    if (!ids.contains(cardId)) ids.add(cardId);
    state = state.copyWith(selectedCardIds: ids);
  }

  void removeFromSelection(String cardId) {
    final ids = List<String>.from(state.selectedCardIds);
    ids.remove(cardId);
    state = state.copyWith(selectedCardIds: ids);
  }

  void selectAll() {
    state = state.copyWith(
      selectedCardIds: state.cards.map((c) => c.id).toList(),
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedCardIds: true,
      clearSelectedConnectionId: true,
    );
  }

  void selectConnection(String? connId) {
    if (connId == null) {
      state = state.copyWith(clearSelectedConnectionId: true);
    } else {
      state = state.copyWith(
        selectedConnectionId: connId,
        clearSelectedCardIds: true,
      );
    }
  }

  void startInlineEditing(String cardId) {
    state = state.copyWith(
      selectedCardIds: [cardId],
      inlineEditingCardId: cardId,
    );
  }

  void finishInlineEditing() {
    state = state.copyWith(clearInlineEditingCardId: true);
  }

  Future<void> batchDeleteCards(List<String> cardIds) async {
    if (cardIds.isEmpty) return;
    _pushUndo();
    final cardIdSet = cardIds.toSet();
    state = state.copyWith(
      cards: state.cards.where((c) => !cardIdSet.contains(c.id)).toList(),
      connections: state.connections
          .where(
            (c) =>
                !cardIdSet.contains(c.fromCardId) &&
                !cardIdSet.contains(c.toCardId),
          )
          .toList(),
      groups: state.groups
          .map((g) {
            final remaining = g.cardIds
                .where((id) => !cardIdSet.contains(id))
                .toList();
            return g.copyWith(cardIds: remaining);
          })
          .where((g) => g.cardIds.isNotEmpty)
          .toList(),
      clearSelectedCardIds: true,
    );
    await _save();
  }

  void batchUpdateCardColor(List<String> cardIds, int colorValue) {
    _pushUndo();
    final cardIdSet = cardIds.toSet();
    final newCards = state.cards.map((c) {
      if (cardIdSet.contains(c.id)) {
        return c.copyWith(colorValue: colorValue);
      }
      return c;
    }).toList();
    state = state.copyWith(cards: newCards);
    _debouncedSave();
  }

  void batchMoveCards(Map<String, (double, double)> moves) {
    final newCards = state.cards.map((c) {
      final move = moves[c.id];
      if (move != null) {
        return c.copyWith(x: move.$1, y: move.$2);
      }
      return c;
    }).toList();
    state = state.copyWith(cards: newCards);
    _debouncedSave();
  }

  Future<void> groupCards(List<String> cardIds, {String? name}) async {
    if (cardIds.length < 2) return;
    _pushUndo();
    final group = CanvasGroup(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Group ${state.groups.length + 1}',
      cardIds: cardIds,
    );
    state = state.copyWith(groups: [...state.groups, group]);
    await _save();
  }

  Future<void> ungroupCards(String groupId) async {
    _pushUndo();
    state = state.copyWith(
      groups: state.groups.where((g) => g.id != groupId).toList(),
    );
    await _save();
  }

  Future<void> renameGroup(String groupId, String name) async {
    final groups = state.groups.map((g) {
      if (g.id == groupId) return g.copyWith(name: name);
      return g;
    }).toList();
    state = state.copyWith(groups: groups);
    _debouncedSave();
  }

  void alignCards(List<String> cardIds, AlignmentType type) {
    if (cardIds.length < 2) return;
    _pushUndo();
    final selectedCards = state.cards
        .where((c) => cardIds.contains(c.id))
        .toList();
    if (selectedCards.isEmpty) return;

    final newCards = List<CanvasCard>.from(state.cards);
    switch (type) {
      case AlignmentType.left:
        final minX = selectedCards
            .map((c) => c.x)
            .reduce((a, b) => a < b ? a : b);
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(x: minX);
          }
        }
      case AlignmentType.centerH:
        final avgCenterX =
            selectedCards.map((c) => c.center.dx).reduce((a, b) => a + b) /
            selectedCards.length;
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(
              x: avgCenterX - newCards[i].width / 2,
            );
          }
        }
      case AlignmentType.right:
        final maxRight = selectedCards
            .map((c) => c.x + c.width)
            .reduce((a, b) => a > b ? a : b);
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(x: maxRight - newCards[i].width);
          }
        }
      case AlignmentType.top:
        final minY = selectedCards
            .map((c) => c.y)
            .reduce((a, b) => a < b ? a : b);
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(y: minY);
          }
        }
      case AlignmentType.centerV:
        final avgCenterY =
            selectedCards.map((c) => c.center.dy).reduce((a, b) => a + b) /
            selectedCards.length;
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(
              y: avgCenterY - newCards[i].height / 2,
            );
          }
        }
      case AlignmentType.bottom:
        final maxBottom = selectedCards
            .map((c) => c.y + c.height)
            .reduce((a, b) => a > b ? a : b);
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(
              y: maxBottom - newCards[i].height,
            );
          }
        }
    }
    state = state.copyWith(cards: newCards);
    _debouncedSave();
  }

  void distributeCards(List<String> cardIds, DistributeType type) {
    if (cardIds.length < 3) return;
    _pushUndo();
    final selectedCards = state.cards
        .where((c) => cardIds.contains(c.id))
        .toList();
    if (selectedCards.length < 3) return;

    final newCards = List<CanvasCard>.from(state.cards);
    switch (type) {
      case DistributeType.horizontal:
        final sorted = List<CanvasCard>.from(selectedCards)
          ..sort((a, b) => a.x.compareTo(b.x));
        final minX = sorted.first.x;
        final maxX = sorted.last.x;
        final totalWidth = sorted.fold(0.0, (sum, c) => sum + c.width);
        final totalGap = maxX - minX - totalWidth;
        final gapCount = sorted.length - 1;
        final gap = gapCount > 0 ? totalGap / gapCount : 0.0;
        double currentX = minX;
        for (final card in sorted) {
          final idx = newCards.indexWhere((c) => c.id == card.id);
          if (idx >= 0) {
            newCards[idx] = newCards[idx].copyWith(x: currentX);
            currentX += newCards[idx].width + gap;
          }
        }
      case DistributeType.vertical:
        final sorted = List<CanvasCard>.from(selectedCards)
          ..sort((a, b) => a.y.compareTo(b.y));
        final minY = sorted.first.y;
        final maxY = sorted.last.y;
        final totalHeight = sorted.fold(0.0, (sum, c) => sum + c.height);
        final totalGap = maxY - minY - totalHeight;
        final gapCount = sorted.length - 1;
        final gap = gapCount > 0 ? totalGap / gapCount : 0.0;
        double currentY = minY;
        for (final card in sorted) {
          final idx = newCards.indexWhere((c) => c.id == card.id);
          if (idx >= 0) {
            newCards[idx] = newCards[idx].copyWith(y: currentY);
            currentY += newCards[idx].height + gap;
          }
        }
    }
    state = state.copyWith(cards: newCards);
    _debouncedSave();
  }

  List<CanvasConnection> deriveAutoConnections(
    List<Note> notes,
    LinkResolver? linkResolver,
  ) {
    if (!autoConnectionsEnabled) return [];
    if (linkResolver == null) return [];

    final cardsWithNoteIds = state.cards
        .where((c) => c.noteId != null)
        .toList();
    if (cardsWithNoteIds.length < 2) return [];

    final noteMap = <String, Note>{};
    for (final note in notes) {
      noteMap[note.id] = note;
    }

    final autoConns = <CanvasConnection>[];

    for (int i = 0; i < cardsWithNoteIds.length; i++) {
      for (int j = 0; j < cardsWithNoteIds.length; j++) {
        if (i == j) continue;
        final cardA = cardsWithNoteIds[i];
        final cardB = cardsWithNoteIds[j];
        final noteA = noteMap[cardA.noteId];
        final noteB = noteMap[cardB.noteId];
        if (noteA == null || noteB == null) continue;

        final extractedLinks = linkResolver.extractLinksFromContent(
          noteA.content,
        );
        final hasLink = extractedLinks.any((link) {
          final resolvedPath = linkResolver.resolveTitleToPath(link.target);
          if (resolvedPath == null) return false;
          final targetId = resolvedPath
              .replaceAll(RegExp(r'[/\\]'), '_')
              .replaceAll('.md', '');
          return targetId == noteB.id;
        });

        if (hasLink) {
          final (fromSide, toSide) = CanvasConnection.computeSides(
            cardA,
            cardB,
          );

          autoConns.add(
            CanvasConnection(
              id: 'auto_${cardA.id}_${cardB.id}',
              fromCardId: cardA.id,
              toCardId: cardB.id,
              fromSide: fromSide,
              toSide: toSide,
              isAuto: true,
            ),
          );
        }
      }
    }

    final manualPairs = <String>{};
    for (final conn in state.connections) {
      if (!conn.isAuto) {
        manualPairs.add('${conn.fromCardId}->${conn.toCardId}');
      }
    }

    return autoConns.where((c) {
      final key = '${c.fromCardId}->${c.toCardId}';
      return !manualPairs.contains(key);
    }).toList();
  }

  List<CanvasCard> searchCards(String query) {
    if (query.isEmpty) return state.cards.toList();
    final lower = query.toLowerCase();
    return state.cards
        .where(
          (c) =>
              c.title.toLowerCase().contains(lower) ||
              c.content.toLowerCase().contains(lower),
        )
        .toList();
  }

  Future<String> _canvasFilePath() async {
    final vaultPath = ref.read(vaultProvider).currentVault?.path;
    if (vaultPath == null) throw StateError('No vault open');
    final dir = Directory(p.join(vaultPath, '.rf', 'canvases'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return p.join(dir.path, '$_activeCanvasName.canvas.json');
  }

  Future<void> _save() async {
    try {
      await _saveToFile();
    } on StateError {
      await _saveToSharedPrefs();
    }
  }

  Future<void> _saveToFile() async {
    try {
      final path = await _canvasFilePath();
      await File(path).writeAsString(state.toJsonString());
    } catch (e) {
      debugPrint('Canvas save failed: $e');
    }
  }

  Future<void> _saveToSharedPrefs() async {
    final prefs = await _ensurePrefs;
    await prefs.setString('canvas_data', state.toJsonString());
  }

  void _debouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _save();
    });
  }

  Future<void> _loadFromFile() async {
    try {
      final path = await _canvasFilePath();
      if (await File(path).exists()) {
        final json = await File(path).readAsString();
        state = CanvasData.fromJsonString(json);
        return;
      }
    } catch (_) {
      debugPrint('Canvas: failed to load canvas from file');
    }
    await _migrateFromSharedPrefs();
  }

  Future<void> _migrateFromSharedPrefs() async {
    final prefs = await _ensurePrefs;
    final json = prefs.getString('canvas_data');
    if (json != null) {
      state = CanvasData.fromJsonString(json);
      try {
        await prefs.remove('canvas_data');
        await _saveToFile();
      } catch (_) {
        debugPrint('Canvas: migration from SharedPrefs failed');
      }
    }
  }

  void updateCardInMemory(CanvasCard card) {
    final cards = state.cards.map((c) => c.id == card.id ? card : c).toList();
    state = state.copyWith(cards: cards);
    _debouncedSave();
  }

  Future<void> persist() async {
    _debounceTimer?.cancel();
    await _save();
  }

  Future<void> addCard(CanvasCard card) async {
    _pushUndo();
    state = state.copyWith(cards: [...state.cards, card]);
    await _save();
  }

  Future<void> updateCard(CanvasCard card) async {
    _pushUndo();
    final cards = state.cards.map((c) => c.id == card.id ? card : c).toList();
    state = state.copyWith(cards: cards);
    await _save();
  }

  Future<void> removeCard(String cardId) async {
    _pushUndo();
    state = state.copyWith(
      cards: state.cards.where((c) => c.id != cardId).toList(),
      connections: state.connections
          .where((c) => c.fromCardId != cardId && c.toCardId != cardId)
          .toList(),
      groups: state.groups
          .map((g) {
            final remaining = g.cardIds.where((id) => id != cardId).toList();
            return g.copyWith(cardIds: remaining);
          })
          .where((g) => g.cardIds.isNotEmpty)
          .toList(),
    );
    await _save();
  }

  Future<void> addConnection(CanvasConnection conn) async {
    _pushUndo();
    state = state.copyWith(connections: [...state.connections, conn]);
    await _save();
  }

  Future<void> removeConnection(String connId) async {
    _pushUndo();
    state = state.copyWith(
      connections: state.connections.where((c) => c.id != connId).toList(),
    );
    await _save();
  }

  void updateConnection(CanvasConnection conn) {
    final conns = state.connections
        .map((c) => c.id == conn.id ? conn : c)
        .toList();
    state = state.copyWith(connections: conns);
    _debouncedSave();
  }

  void addWaypoint(String connId, Offset position, {int? insertIndex}) {
    final conns = state.connections.map((c) {
      if (c.id == connId) {
        if (insertIndex != null &&
            insertIndex >= 0 &&
            insertIndex <= c.waypoints.length) {
          final newWaypoints = List<Offset>.from(c.waypoints)
            ..insert(insertIndex, position);
          return c.copyWith(waypoints: newWaypoints);
        }
        return c.copyWith(waypoints: [...c.waypoints, position]);
      }
      return c;
    }).toList();
    state = state.copyWith(connections: conns);
    _debouncedSave();
  }

  void removeWaypoint(String connId, int index) {
    final conns = state.connections.map((c) {
      if (c.id == connId && index >= 0 && index < c.waypoints.length) {
        final newWaypoints = List<Offset>.from(c.waypoints)..removeAt(index);
        return c.copyWith(waypoints: newWaypoints);
      }
      return c;
    }).toList();
    state = state.copyWith(connections: conns);
    _debouncedSave();
  }

  void moveWaypoint(String connId, int index, Offset newPosition) {
    final conns = state.connections.map((c) {
      if (c.id == connId && index >= 0 && index < c.waypoints.length) {
        final newWaypoints = List<Offset>.from(c.waypoints);
        newWaypoints[index] = newPosition;
        return c.copyWith(waypoints: newWaypoints);
      }
      return c;
    }).toList();
    state = state.copyWith(connections: conns);
    _debouncedSave();
  }

  Future<void> clearCanvas() async {
    _pushUndo();
    state = CanvasData();
    await _save();
  }

  void addTag(String cardId, String tag) {
    final card = cardById(cardId);
    if (card == null) return;
    if (card.tags.contains(tag)) return;
    updateCardInMemory(card.copyWith(tags: [...card.tags, tag]));
    _debouncedSave();
  }

  void removeTag(String cardId, String tag) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(
      card.copyWith(tags: card.tags.where((t) => t != tag).toList()),
    );
    _debouncedSave();
  }

  void setDefaultCardStyle(CanvasCardStyle? style) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        defaultCardStyle: style,
        clearDefaultCardStyle: style == null,
      ),
    );
    _debouncedSave();
  }

  void setDefaultConnectionStyle(CanvasConnectionStyle? style) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        defaultConnectionStyle: style,
        clearDefaultConnectionStyle: style == null,
      ),
    );
    _debouncedSave();
  }

  void setBackgroundColor(int? colorValue) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        backgroundColorValue: colorValue,
        clearBackgroundColor: colorValue == null,
      ),
    );
    _debouncedSave();
  }

  void toggleRulers() {
    state = state.copyWith(
      settings: state.settings.copyWith(
        rulersVisible: !state.settings.rulersVisible,
      ),
    );
    _debouncedSave();
  }

  CanvasCard createCard(
    CanvasCardType type,
    Offset position, {
    String? title,
    String? noteId,
  }) {
    final defaultStyle = state.settings.defaultCardStyle;
    return CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      x: position.dx,
      y: position.dy,
      width: type.defaultWidth,
      height: type.defaultHeight,
      title: title ?? type.label,
      noteId: noteId,
      style: defaultStyle,
    );
  }

  CanvasConnection createConnection(
    String fromId,
    String toId, {
    String? label,
  }) {
    final from = cardById(fromId);
    final to = cardById(toId);
    if (from == null || to == null) {
      return CanvasConnection(id: '', fromCardId: fromId, toCardId: toId);
    }
    final (fromSide, toSide) = CanvasConnection.computeSides(from, to);
    final defaultStyle = state.settings.defaultConnectionStyle;
    return CanvasConnection(
      id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
      fromCardId: fromId,
      toCardId: toId,
      fromSide: fromSide,
      toSide: toSide,
      label: label ?? '',
      style: defaultStyle,
    );
  }

  void setMetadata(String cardId, CanvasCardMetadata metadata) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(metadata: metadata));
    _debouncedSave();
  }

  void setHyperlink(String cardId, String? url) {
    final card = cardById(cardId);
    if (card == null) return;
    final meta = card.metadata ?? const CanvasCardMetadata();
    updateCardInMemory(
      card.copyWith(
        metadata: meta.copyWith(hyperlink: url, clearHyperlink: url == null),
      ),
    );
    _debouncedSave();
  }

  void setTextAlign(String cardId, {TextAlignH? h, TextAlignV? v}) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(
      card.copyWith(
        textAlignH: h ?? card.textAlignH,
        textAlignV: v ?? card.textAlignV,
      ),
    );
    _debouncedSave();
  }

  void setRichContent(String cardId, List<RichTextSegment> segments) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(richContent: segments));
    _debouncedSave();
  }

  void toggleAutoNumber(String cardId) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(autoNumber: !card.autoNumber));
    _debouncedSave();
  }

  void setFreehandPoints(String cardId, List<Offset> points) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(freehandPoints: points));
    _debouncedSave();
  }

  void setTableSize(String cardId, int rows, int cols) {
    final card = cardById(cardId);
    if (card == null) return;
    final cells = List<CanvasTableCell>.generate(rows * cols, (i) {
      if (i < card.tableCells.length) return card.tableCells[i];
      return const CanvasTableCell();
    });
    updateCardInMemory(
      card.copyWith(tableRows: rows, tableCols: cols, tableCells: cells),
    );
    _debouncedSave();
  }

  void setTableCell(String cardId, int row, int col, String text) {
    final card = cardById(cardId);
    if (card == null) return;
    final idx = row * card.tableCols + col;
    if (idx < 0 || idx >= card.tableCells.length) return;
    final cells = List<CanvasTableCell>.from(card.tableCells);
    cells[idx] = CanvasTableCell(text: text);
    updateCardInMemory(card.copyWith(tableCells: cells));
    _debouncedSave();
  }

  void toggleVerticalText(String cardId) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(verticalText: !card.verticalText));
    _debouncedSave();
  }

  void enumerateAllCards() {
    int counter = 1;
    final updatedCards = state.cards.map((card) {
      if (card.autoNumber) {
        return card.copyWith(
          title:
              '${counter++}. ${card.title.replaceAll(RegExp(r'^\d+\.\s*'), '')}',
        );
      }
      return card;
    }).toList();
    state = state.copyWith(cards: updatedCards);
    _debouncedSave();
  }

  CanvasCard? cardById(String id) {
    try {
      return state.cards.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  CanvasGroup? groupForCard(String cardId) {
    for (final g in state.groups) {
      if (g.cardIds.contains(cardId)) return g;
    }
    return null;
  }

  List<String> groupCardIds(String groupId) {
    final group = state.groups.where((g) => g.id == groupId).firstOrNull;
    return group?.cardIds.toList() ?? [];
  }

  Future<bool> createCanvas(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _canvasNames.contains(trimmed)) return false;
    _canvasNames.add(trimmed);
    await _saveCanvasList();
    return true;
  }

  Future<void> switchCanvas(String name) async {
    if (!_canvasNames.contains(name) || name == _activeCanvasName) return;
    await _save();
    _activeCanvasName = name;
    await _saveCanvasList();
    await _loadFromFile();
  }

  Future<bool> deleteCanvas(String name) async {
    if (_canvasNames.length <= 1) return false;
    if (!_canvasNames.contains(name)) return false;
    _canvasNames.remove(name);
    if (_activeCanvasName == name) {
      _activeCanvasName = _canvasNames.first;
      await _loadFromFile();
    }
    await _saveCanvasList();
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath != null) {
        final file = File(
          p.join(vaultPath, '.rf', 'canvases', '$name.canvas.json'),
        );
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      debugPrint('Canvas: failed to delete canvas file for "$name"');
    }
    return true;
  }

  Future<bool> renameCanvas(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || _canvasNames.contains(trimmed)) return false;
    if (!_canvasNames.contains(oldName)) return false;
    final index = _canvasNames.indexOf(oldName);
    _canvasNames[index] = trimmed;
    if (_activeCanvasName == oldName) {
      _activeCanvasName = trimmed;
    }
    await _saveCanvasList();
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath != null) {
        final oldFile = File(
          p.join(vaultPath, '.rf', 'canvases', '$oldName.canvas.json'),
        );
        final newFile = File(
          p.join(vaultPath, '.rf', 'canvases', '$trimmed.canvas.json'),
        );
        if (await oldFile.exists()) await oldFile.rename(newFile.path);
      }
    } catch (_) {
      debugPrint(
        'Canvas: failed to rename canvas file from "$oldName" to "$newName"',
      );
    }
    return true;
  }

  // === Layout delegation ===

  void autoLayout(AutoLayoutType type) {
    if (state.cards.isEmpty) return;
    _pushUndo();
    final positions = _layoutService.computeLayout(
      state.cards,
      state.connections,
      type,
      snapToGrid: state.settings.snapToGrid,
    );
    final newCards = state.cards.map((card) {
      final pos = positions[card.id];
      if (pos != null) {
        return card.copyWith(x: pos.dx, y: pos.dy);
      }
      return card;
    }).toList();
    state = state.copyWith(cards: newCards);
    _debouncedSave();
  }

  // === Export delegation ===

  String exportToSvg() => _exportService.exportToSvg(state, _activeCanvasName);

  String exportToPdf() => _exportService.exportToPdf(state, _activeCanvasName);

  String exportToMarkdown() => _exportService.exportToMarkdown(state, _activeCanvasName);

  String exportToHtml() => _exportService.exportToHtml(state);

  String exportToJpeg() => _exportService.exportToJpeg(state, _activeCanvasName);

  String exportToWebp() => _exportService.exportToWebp(state, _activeCanvasName);

  String encodeToUrl() => _exportService.encodeToUrl(state);

  (String, String) exportWithEmbeddedData() =>
      _exportService.exportWithEmbeddedData(state, _activeCanvasName);

  static CanvasData? decodeFromUrl(String url) =>
      CanvasExportService.decodeFromUrl(url);

  static CanvasData? importFromCsv(String csv) =>
      CanvasExportService.importFromCsv(csv);

  static CanvasData? importFromMermaid(String mermaid) =>
      CanvasExportService.importFromMermaid(mermaid);

  static CanvasData? importFromEmbeddedSvg(String svgContent) =>
      CanvasExportService.importFromEmbeddedSvg(svgContent);

  static CanvasData? importFromSvg(String svgContent) =>
      CanvasExportService.importFromSvg(svgContent);

  static CanvasData? importFromVsdx(String vsdxPath) =>
      CanvasExportService.importFromVsdx(vsdxPath);

  // === Layers delegation ===

  Future<void> addLayer(String name) async {
    _pushUndo();
    final layer = _layersService.createLayer(name, state.layers.length);
    state = state.copyWith(layers: [...state.layers, layer]);
    await _save();
  }

  Future<void> removeLayer(String layerId) async {
    _pushUndo();
    final newLayers = _layersService.removeLayer(state.layers, layerId);
    final cleanedCards = state.cards.map((c) {
      if (c.layerId == layerId) return c.copyWith(clearLayerId: true);
      return c;
    }).toList();
    state = state.copyWith(layers: newLayers, cards: cleanedCards);
    await _save();
  }

  void renameLayer(String layerId, String name) {
    final layers = _layersService.renameLayer(state.layers, layerId, name);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void toggleLayerVisibility(String layerId) {
    final layers = _layersService.toggleLayerVisibility(state.layers, layerId);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void toggleLayerLock(String layerId) {
    final layers = _layersService.toggleLayerLock(state.layers, layerId);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void moveCardToLayer(String cardId, String? layerId) {
    final cards = _layersService.moveCardToLayer(state.cards, cardId, layerId);
    state = state.copyWith(cards: cards);
    _debouncedSave();
  }

  bool isLayerLocked(String cardId) {
    return _layersService.isLayerLocked(state.layers, cardById(cardId));
  }

  bool isLayerVisible(String cardId) {
    return _layersService.isLayerVisible(state.layers, cardById(cardId));
  }

  void reorderLayer(String layerId, int newOrder) {
    final layers = _layersService.reorderLayer(state.layers, layerId, newOrder);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void moveLayerUp(String layerId) {
    final layers = _layersService.moveLayerUp(state.layers, layerId);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void moveLayerDown(String layerId) {
    final layers = _layersService.moveLayerDown(state.layers, layerId);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  int cardCountForLayer(String layerId) {
    return _layersService.cardCountForLayer(state.cards, layerId);
  }

  // === Scratchpad delegation ===

  Future<List<ScratchpadItem>> loadScratchpad() async {
    final vaultPath = ref.read(vaultProvider).currentVault?.path;
    if (vaultPath == null) return [];
    return _scratchpadService.loadScratchpad(vaultPath);
  }

  Future<void> saveScratchpadItem(ScratchpadItem item) async {
    final vaultPath = ref.read(vaultProvider).currentVault?.path;
    if (vaultPath == null) return;
    await _scratchpadService.saveScratchpadItem(vaultPath, item);
  }

  Future<void> removeScratchpadItem(String itemId) async {
    final vaultPath = ref.read(vaultProvider).currentVault?.path;
    if (vaultPath == null) return;
    await _scratchpadService.removeScratchpadItem(vaultPath, itemId);
  }

  CanvasCard createCardFromScratchpad(ScratchpadItem item, Offset pos) {
    return _scratchpadService.createCardFromScratchpad(item, pos);
  }

  // === Templates delegation ===

  void loadTemplate(String templateName) {
    final template = CanvasTemplatesService.builtInTemplates[templateName];
    if (template == null) return;
    _pushUndo();
    state = template;
    _debouncedSave();
  }

  void loadFromData(CanvasData data) {
    _pushUndo();
    state = data;
    _debouncedSave();
  }

  void setFontFamily(String cardId, String family) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(fontFamily: family));
    _debouncedSave();
  }

  void setTextColor(String cardId, int colorValue) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(textColorValue: colorValue));
    _debouncedSave();
  }

  void setLatexFormula(String cardId, String? formula) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(
      card.copyWith(latexFormula: formula, clearLatex: formula == null),
    );
    _debouncedSave();
  }

  void setHtmlContent(String cardId, String? html) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(
      card.copyWith(htmlContent: html, clearHtml: html == null),
    );
    _debouncedSave();
  }

  void setCustomSvg(String cardId, String? svgData) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(
      card.copyWith(customSvgData: svgData, clearSvg: svgData == null),
    );
    _debouncedSave();
  }

  void addSvgAsCustomShape(String cardId, String svgData) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(customSvgData: svgData));
    _debouncedSave();
  }

  void setConnectionPointOffset(String cardId, double offsetX, double offsetY) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(
      card.copyWith(
        connectionPointOffsetX: offsetX.clamp(0.0, 1.0),
        connectionPointOffsetY: offsetY.clamp(0.0, 1.0),
      ),
    );
    _debouncedSave();
  }
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasData>(
  CanvasNotifier.new,
);

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/canvas_model.dart';
import '../data/models/note.dart';
import '../data/stores/vault_store.dart';
import '../core/link/link_resolver.dart';

part 'canvas/canvas_templates.dart';
part 'canvas/canvas_export.dart';
part 'canvas/canvas_layout.dart';
part 'canvas/canvas_layers.dart';
part 'canvas/canvas_scratchpad.dart';

abstract class _CanvasNotifierBase extends Notifier<CanvasData> {
  Timer? _debounceTimer;
  SharedPreferences? _prefs;
  List<String> _canvasNames = ['default'];
  String _activeCanvasName = 'default';
  final List<CanvasData> _undoStack = [];
  final List<CanvasData> _redoStack = [];
  static const int _maxHistory = 50;

  String get activeCanvasName => _activeCanvasName;
  List<String> get canvasNames => List.unmodifiable(_canvasNames);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<SharedPreferences> get _ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  void _pushUndo();
  Future<void> _save();
  void _debouncedSave();
  CanvasCard? cardById(String id);
  List<String> groupCardIds(String groupId);
  String exportToSvg();
  void updateCardInMemory(CanvasCard card);
  void loadTemplate(String templateName);
  void loadFromData(CanvasData data);
  String exportToPdf();
  String encodeToUrl();
  void addSvgAsCustomShape(String cardId, String svgData);
  void autoLayout(AutoLayoutType type);
  void _forceDirectedLayout(List<CanvasCard> cards);
  void _hierarchicalLayout(List<CanvasCard> cards);
  void _gridLayout(List<CanvasCard> cards);
  double _snapToGrid(double value);
  Future<void> addLayer(String name);
  Future<void> removeLayer(String layerId);
  void renameLayer(String layerId, String name);
  void toggleLayerVisibility(String layerId);
  void toggleLayerLock(String layerId);
  void moveCardToLayer(String cardId, String? layerId);
  bool isLayerLocked(String cardId);
  bool isLayerVisible(String cardId);
  void reorderLayer(String layerId, int newOrder);
  void moveLayerUp(String layerId);
  void moveLayerDown(String layerId);
  int cardCountForLayer(String layerId);
  Future<List<ScratchpadItem>> loadScratchpad();
  Future<void> saveScratchpadItem(ScratchpadItem item);
  Future<void> removeScratchpadItem(String itemId);
  Future<void> _saveScratchpad(List<ScratchpadItem> items);
  CanvasCard createCardFromScratchpad(ScratchpadItem item, Offset pos);
}


class CanvasNotifier extends _CanvasNotifierBase
    with CanvasTemplatesMixin, CanvasExportMixin, CanvasLayoutMixin, CanvasLayersMixin, CanvasScratchpadMixin {
  List<String> get canvasNames => List.unmodifiable(_canvasNames);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<SharedPreferences> get _ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  CanvasData build() => CanvasData();

  @override
  void _pushUndo() {
    _undoStack.add(state);
    if (_undoStack.length > _CanvasNotifierBase._maxHistory) _undoStack.removeAt(0);
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

  @override
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

  @override
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

  @override
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

  @override
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

  String _xmlEscape(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  @override
  String exportToSvg() {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    double minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;
    for (final card in state.cards) {
      minX = minX < card.x ? minX : card.x;
      minY = minY < card.y ? minY : card.y;
      final rx = card.x + card.width;
      final ry = card.y + card.height;
      maxX = maxX > rx ? maxX : rx;
      maxY = maxY > ry ? maxY : ry;
    }
    if (minX == double.infinity) {
      minX = 0;
      minY = 0;
      maxX = 800;
      maxY = 600;
    }
    final pad = 40.0;
    final w = maxX - minX + pad * 2;
    final h = maxY - minY + pad * 2;
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="${minX - pad} ${minY - pad} $w $h">',
    );
    for (final conn in state.connections) {
      final from = cardById(conn.fromCardId);
      final to = cardById(conn.toCardId);
      if (from == null || to == null) continue;
      final (fs, ts) = CanvasConnection.computeSides(from, to);
      final fp = fs.point(from.rect, conn.fromSideOffset);
      final tp = ts.point(to.rect, conn.toSideOffset);
      buffer.writeln(
        '<line x1="${fp.dx}" y1="${fp.dy}" x2="${tp.dx}" y2="${tp.dy}" stroke="#666" stroke-width="2"/>',
      );
      if (conn.label.isNotEmpty) {
        final mx = (fp.dx + tp.dx) / 2;
        final my = (fp.dy + tp.dy) / 2;
        buffer.writeln(
          '<text x="$mx" y="$my" text-anchor="middle" font-size="12" fill="#666">${_xmlEscape(conn.label)}</text>',
        );
      }
    }
    for (final card in state.cards) {
      final hex =
          '#${(card.colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      final strokeHex =
          '#${(card.style?.borderColor ?? 0xFFE0E0E0 & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      final r = card.style?.borderRadius ?? 8.0;
      buffer.writeln(
        '<rect x="${card.x}" y="${card.y}" width="${card.width}" height="${card.height}" rx="$r" fill="$hex" stroke="$strokeHex" stroke-width="1"/>',
      );
      if (card.title.isNotEmpty) {
        buffer.writeln(
          '<text x="${card.x + 12}" y="${card.y + 20}" font-size="14" font-weight="bold" fill="#333">${_xmlEscape(card.title)}</text>',
        );
      }
      if (card.content.isNotEmpty) {
        final lines = card.content.split('\n').take(5);
        var cy = card.y + 40;
        for (final line in lines) {
          buffer.writeln(
            '<text x="${card.x + 12}" y="$cy" font-size="12" fill="#666">${_xmlEscape(line)}</text>',
          );
          cy += 16;
        }
      }
    }
    buffer.writeln('</svg>');
    return buffer.toString();
  }

  @override
  String exportToMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Canvas: $activeCanvasName');
    buffer.writeln();
    buffer.writeln('## Cards');
    buffer.writeln();
    buffer.writeln('| # | Type | Title | Position | Layer |');
    buffer.writeln('|---|------|-------|----------|-------|');
    for (int i = 0; i < state.cards.length; i++) {
      final c = state.cards[i];
      final layerName = c.layerId != null
          ? (state.layers.where((l) => l.id == c.layerId).firstOrNull?.name ??
                '-')
          : '-';
      buffer.writeln(
        '| ${i + 1} | ${c.type.label} | ${c.title} | (${c.x.round()}, ${c.y.round()}) | $layerName |',
      );
    }
    buffer.writeln();
    buffer.writeln('## Connections');
    buffer.writeln();
    for (final conn in state.connections) {
      final from = cardById(conn.fromCardId)?.title ?? conn.fromCardId;
      final to = cardById(conn.toCardId)?.title ?? conn.toCardId;
      final label = conn.label.isNotEmpty ? ' "${conn.label}"' : '';
      buffer.writeln('- $from →$label $to ${conn.isAuto ? "(auto)" : ""}');
    }
    return buffer.toString();
  }
  static CanvasData? decodeFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final data = uri.queryParameters['data'];
  if (data == null) return null;
  try {
  final json = utf8.decode(base64Decode(data));
  return CanvasData.fromJsonString(json);
  } catch (_) {
  return null;
  }
  }
  static CanvasData? importFromCsv(String csv) {
  final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return null;
  final cards = <CanvasCard>[];
  final connections = <CanvasConnection>[];
  for (int i = 0; i < lines.length; i++) {
  final parts = lines[i].split(',').map((p) => p.trim()).toList();
  if (parts.length < 2) continue;
  final id = 'csv_$i';
  cards.add(
  CanvasCard(
  id: id,
  type: CanvasCardType.rectangle,
  x: (i % 5) * 200.0,
  y: (i ~/ 5) * 120.0,
  width: 160,
  height: 60,
  title: parts[0],
  content: parts.length > 1 ? parts.sublist(1).join(', ') : '',
  ),
  );
  if (i > 0 && parts.length > 1) {
  for (int j = 0; j < i; j++) {
  final prevParts = lines[j].split(',').map((p) => p.trim()).toList();
  if (prevParts.isNotEmpty && parts.contains(prevParts[0])) {
  connections.add(
  CanvasConnection(
  id: 'csv_c_${j}_$i',
  fromCardId: 'csv_$j',
  toCardId: id,
  ),
  );
  }
  }
  }
  }
  if (cards.isEmpty) return null;
  return CanvasData(cards: cards, connections: connections);
  }
  static CanvasData? importFromMermaid(String mermaid) {
  final lines = mermaid
  .split('\n')
  .map((l) => l.trim())
  .where(
  (l) =>
  l.isNotEmpty &&
  !l.startsWith('graph') &&
  !l.startsWith('flowchart'),
  )
  .toList();
  if (lines.isEmpty) return null;
  final nodeMap = <String, String>{};
  final cards = <CanvasCard>[];
  final connections = <CanvasConnection>[];
  int col = 0, row = 0;
  for (final line in lines) {
  final arrowMatch = RegExp(r'(\w+)\s*-->?\s*(\w+)');
  final match = arrowMatch.firstMatch(line);
  if (match != null) {
  final fromId = match.group(1)!;
  final toId = match.group(2)!;
  if (!nodeMap.containsKey(fromId)) {
  final cardId = 'mr_${nodeMap.length}';
  nodeMap[fromId] = cardId;
  cards.add(
  CanvasCard(
  id: cardId,
  type: CanvasCardType.rectangle,
  x: col * 200.0,
  y: row * 100.0,
  width: 160,
  height: 60,
  title: fromId,
  ),
  );
  col++;
  if (col >= 5) {
  col = 0;
  row++;
  }
  }
  if (!nodeMap.containsKey(toId)) {
  final cardId = 'mr_${nodeMap.length}';
  nodeMap[toId] = cardId;
  cards.add(
  CanvasCard(
  id: cardId,
  type: CanvasCardType.rectangle,
  x: col * 200.0,
  y: row * 100.0,
  width: 160,
  height: 60,
  title: toId,
  ),
  );
  col++;
  if (col >= 5) {
  col = 0;
  row++;
  }
  }
  connections.add(
  CanvasConnection(
  id: 'mr_c_${connections.length}',
  fromCardId: nodeMap[fromId]!,
  toCardId: nodeMap[toId]!,
  ),
  );
  }
  }
  if (cards.isEmpty) return null;
  return CanvasData(cards: cards, connections: connections);
  }
  static CanvasData? importFromEmbeddedSvg(String svgContent) {
  final metaMatch = RegExp(
  r'<metadata>rfbrowser:([A-Za-z0-9+/=]+)</metadata>',
  ).firstMatch(svgContent);
  if (metaMatch == null) return null;
  try {
  final json = utf8.decode(base64Decode(metaMatch.group(1)!));
  return CanvasData.fromJsonString(json);
  } catch (_) {
  return null;
  }
  }
  static CanvasData? importFromSvg(String svgContent) {
  final embedded = importFromEmbeddedSvg(svgContent);
  if (embedded != null) return embedded;
  final rects = <CanvasCard>[];
  final rectRegex = RegExp(
  r'<rect[^>]*x="([^"]*)"[^>]*y="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"',
  );
  for (final m in rectRegex.allMatches(svgContent)) {
  rects.add(
  CanvasCard(
  id: 'svg_${rects.length}',
  type: CanvasCardType.rectangle,
  x: double.tryParse(m.group(1) ?? '0') ?? 0,
  y: double.tryParse(m.group(2) ?? '0') ?? 0,
  width: double.tryParse(m.group(3) ?? '100') ?? 100,
  height: double.tryParse(m.group(4) ?? '60') ?? 60,
  ),
  );
  }
  if (rects.isEmpty) return null;
  return CanvasData(cards: rects);
  }
  static CanvasData? importFromVsdx(String vsdxPath) {
  return null;
  }

}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasData>(
  CanvasNotifier.new,
);

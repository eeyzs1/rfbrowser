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

class CanvasNotifier extends Notifier<CanvasData> {
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
      final listFile = File(p.join(vaultPath, '.rf', 'canvases', '_canvas_list.json'));
      if (await listFile.exists()) {
        final json = jsonDecode(await listFile.readAsString()) as Map<String, dynamic>;
        _canvasNames = (json['canvases'] as List?)?.cast<String>() ?? ['default'];
        _activeCanvasName = json['active'] as String? ?? 'default';
        if (!_canvasNames.contains(_activeCanvasName)) {
          _activeCanvasName = _canvasNames.isNotEmpty ? _canvasNames.first : 'default';
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
      await listFile.writeAsString(jsonEncode({
        'canvases': _canvasNames,
        'active': _activeCanvasName,
      }));
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
      state = state.copyWith(selectedCardIds: ids, clearSelectedConnectionId: true);
    } else {
      state = state.copyWith(selectedCardIds: [cardId], clearSelectedConnectionId: true);
    }
  }

  void selectCards(List<String> cardIds) {
    state = state.copyWith(selectedCardIds: cardIds, clearSelectedConnectionId: true);
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
    state = state.copyWith(selectedCardIds: state.cards.map((c) => c.id).toList());
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedCardIds: true, clearSelectedConnectionId: true);
  }

  void selectConnection(String? connId) {
    if (connId == null) {
      state = state.copyWith(clearSelectedConnectionId: true);
    } else {
      state = state.copyWith(selectedConnectionId: connId, clearSelectedCardIds: true);
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
          .where((c) => !cardIdSet.contains(c.fromCardId) && !cardIdSet.contains(c.toCardId))
          .toList(),
      groups: state.groups.map((g) {
        final remaining = g.cardIds.where((id) => !cardIdSet.contains(id)).toList();
        return g.copyWith(cardIds: remaining);
      }).where((g) => g.cardIds.isNotEmpty).toList(),
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
    final selectedCards = state.cards.where((c) => cardIds.contains(c.id)).toList();
    if (selectedCards.isEmpty) return;

    final newCards = List<CanvasCard>.from(state.cards);
    switch (type) {
      case AlignmentType.left:
        final minX = selectedCards.map((c) => c.x).reduce((a, b) => a < b ? a : b);
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(x: minX);
          }
        }
      case AlignmentType.centerH:
        final avgCenterX = selectedCards.map((c) => c.center.dx).reduce((a, b) => a + b) / selectedCards.length;
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(x: avgCenterX - newCards[i].width / 2);
          }
        }
      case AlignmentType.right:
        final maxRight = selectedCards.map((c) => c.x + c.width).reduce((a, b) => a > b ? a : b);
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(x: maxRight - newCards[i].width);
          }
        }
      case AlignmentType.top:
        final minY = selectedCards.map((c) => c.y).reduce((a, b) => a < b ? a : b);
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(y: minY);
          }
        }
      case AlignmentType.centerV:
        final avgCenterY = selectedCards.map((c) => c.center.dy).reduce((a, b) => a + b) / selectedCards.length;
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(y: avgCenterY - newCards[i].height / 2);
          }
        }
      case AlignmentType.bottom:
        final maxBottom = selectedCards.map((c) => c.y + c.height).reduce((a, b) => a > b ? a : b);
        for (int i = 0; i < newCards.length; i++) {
          if (cardIds.contains(newCards[i].id)) {
            newCards[i] = newCards[i].copyWith(y: maxBottom - newCards[i].height);
          }
        }
    }
    state = state.copyWith(cards: newCards);
    _debouncedSave();
  }

  void distributeCards(List<String> cardIds, DistributeType type) {
    if (cardIds.length < 3) return;
    _pushUndo();
    final selectedCards = state.cards.where((c) => cardIds.contains(c.id)).toList();
    if (selectedCards.length < 3) return;

    final newCards = List<CanvasCard>.from(state.cards);
    switch (type) {
      case DistributeType.horizontal:
        final sorted = List<CanvasCard>.from(selectedCards)..sort((a, b) => a.x.compareTo(b.x));
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
        final sorted = List<CanvasCard>.from(selectedCards)..sort((a, b) => a.y.compareTo(b.y));
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

    final cardsWithNoteIds = state.cards.where((c) => c.noteId != null).toList();
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

        final extractedLinks = linkResolver.extractLinksFromContent(noteA.content);
        final hasLink = extractedLinks.any((link) {
          final resolvedPath = linkResolver.resolveTitleToPath(link.target);
          if (resolvedPath == null) return false;
          final targetId = resolvedPath
              .replaceAll(RegExp(r'[/\\]'), '_')
              .replaceAll('.md', '');
          return targetId == noteB.id;
        });

        if (hasLink) {
          final (fromSide, toSide) = CanvasConnection.computeSides(cardA, cardB);

          autoConns.add(CanvasConnection(
            id: 'auto_${cardA.id}_${cardB.id}',
            fromCardId: cardA.id,
            toCardId: cardB.id,
            fromSide: fromSide,
            toSide: toSide,
            isAuto: true,
          ));
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
        .where((c) =>
            c.title.toLowerCase().contains(lower) ||
            c.content.toLowerCase().contains(lower))
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
      groups: state.groups.map((g) {
        final remaining = g.cardIds.where((id) => id != cardId).toList();
        return g.copyWith(cardIds: remaining);
      }).where((g) => g.cardIds.isNotEmpty).toList(),
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
    final conns = state.connections.map((c) => c.id == conn.id ? conn : c).toList();
    state = state.copyWith(connections: conns);
    _debouncedSave();
  }

  void addWaypoint(String connId, Offset position, {int? insertIndex}) {
    final conns = state.connections.map((c) {
      if (c.id == connId) {
        if (insertIndex != null && insertIndex >= 0 && insertIndex <= c.waypoints.length) {
          final newWaypoints = List<Offset>.from(c.waypoints)..insert(insertIndex, position);
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
    updateCardInMemory(card.copyWith(tags: card.tags.where((t) => t != tag).toList()));
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
      settings: state.settings.copyWith(rulersVisible: !state.settings.rulersVisible),
    );
    _debouncedSave();
  }

  CanvasCard createCard(CanvasCardType type, Offset position, {String? title, String? noteId}) {
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

  CanvasConnection createConnection(String fromId, String toId, {String? label}) {
    final from = cardById(fromId);
    final to = cardById(toId);
    if (from == null || to == null) return CanvasConnection(id: '', fromCardId: fromId, toCardId: toId);
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
    updateCardInMemory(card.copyWith(metadata: meta.copyWith(hyperlink: url, clearHyperlink: url == null)));
    _debouncedSave();
  }

  void setTextAlign(String cardId, {TextAlignH? h, TextAlignV? v}) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(textAlignH: h ?? card.textAlignH, textAlignV: v ?? card.textAlignV));
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
    updateCardInMemory(card.copyWith(tableRows: rows, tableCols: cols, tableCells: cells));
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
        return card.copyWith(title: '${counter++}. ${card.title.replaceAll(RegExp(r'^\d+\.\s*'), '')}');
      }
      return card;
    }).toList();
    state = state.copyWith(cards: updatedCards);
    _debouncedSave();
  }

  String exportToPdf() {
    final svg = exportToSvg();
    return svg;
  }

  String encodeToUrl() {
    final json = state.toJsonString();
    final encoded = base64Encode(utf8.encode(json));
    return 'rfbrowser://canvas?data=$encoded';
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
      cards.add(CanvasCard(
        id: id,
        type: CanvasCardType.rectangle,
        x: (i % 5) * 200.0,
        y: (i ~/ 5) * 120.0,
        width: 160,
        height: 60,
        title: parts[0],
        content: parts.length > 1 ? parts.sublist(1).join(', ') : '',
      ));
      if (i > 0 && parts.length > 1) {
        for (int j = 0; j < i; j++) {
          final prevParts = lines[j].split(',').map((p) => p.trim()).toList();
          if (prevParts.isNotEmpty && parts.contains(prevParts[0])) {
            connections.add(CanvasConnection(
              id: 'csv_c_${j}_$i',
              fromCardId: 'csv_$j',
              toCardId: id,
            ));
          }
        }
      }
    }
    if (cards.isEmpty) return null;
    return CanvasData(cards: cards, connections: connections);
  }

  static CanvasData? importFromMermaid(String mermaid) {
    final lines = mermaid.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('graph') && !l.startsWith('flowchart')).toList();
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
          cards.add(CanvasCard(id: cardId, type: CanvasCardType.rectangle, x: col * 200.0, y: row * 100.0, width: 160, height: 60, title: fromId));
          col++;
          if (col >= 5) { col = 0; row++; }
        }
        if (!nodeMap.containsKey(toId)) {
          final cardId = 'mr_${nodeMap.length}';
          nodeMap[toId] = cardId;
          cards.add(CanvasCard(id: cardId, type: CanvasCardType.rectangle, x: col * 200.0, y: row * 100.0, width: 160, height: 60, title: toId));
          col++;
          if (col >= 5) { col = 0; row++; }
        }
        connections.add(CanvasConnection(id: 'mr_c_${connections.length}', fromCardId: nodeMap[fromId]!, toCardId: nodeMap[toId]!));
      }
    }
    if (cards.isEmpty) return null;
    return CanvasData(cards: cards, connections: connections);
  }

  void loadTemplate(String templateName) {
    final template = _builtInTemplates[templateName];
    if (template == null) return;
    _pushUndo();
    state = template;
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
    updateCardInMemory(card.copyWith(latexFormula: formula, clearLatex: formula == null));
    _debouncedSave();
  }

  void setHtmlContent(String cardId, String? html) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(htmlContent: html, clearHtml: html == null));
    _debouncedSave();
  }

  void setCustomSvg(String cardId, String? svgData) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(customSvgData: svgData, clearSvg: svgData == null));
    _debouncedSave();
  }

  void setConnectionPointOffset(String cardId, double offsetX, double offsetY) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(connectionPointOffsetX: offsetX.clamp(0.0, 1.0), connectionPointOffsetY: offsetY.clamp(0.0, 1.0)));
    _debouncedSave();
  }

  String exportToHtml() {
    final sb = StringBuffer();
    sb.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
    sb.writeln('<title>Canvas Export</title>');
    sb.writeln('<style>body{margin:0;background:#f5f5f5;display:flex;justify-content:center;align-items:center;min-height:100vh}');
    sb.writeln('.card{position:absolute;border:1px solid #ddd;border-radius:8px;padding:8px;background:white;font-family:sans-serif;font-size:13px}');
    sb.writeln('.conn{stroke:#333;stroke-width:2;fill:none}</style></head><body>');
    sb.writeln('<svg width="1200" height="800" style="position:absolute;top:0;left:0">');
    for (final conn in state.connections) {
      final from = cardById(conn.fromCardId);
      final to = cardById(conn.toCardId);
      if (from == null || to == null) continue;
      final fx = from.x + from.width * from.connectionPointOffsetX;
      final fy = from.y + from.height * from.connectionPointOffsetY;
      final tx = to.x + to.width * to.connectionPointOffsetX;
      final ty = to.y + to.height * to.connectionPointOffsetY;
      sb.writeln('<line x1="$fx" y1="$fy" x2="$tx" y2="$ty" class="conn"/>');
    }
    sb.writeln('</svg>');
    for (final card in state.cards) {
      final bg = '#${(card.colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      sb.writeln('<div class="card" style="left:${card.x}px;top:${card.y}px;width:${card.width}px;height:${card.height}px;background:$bg">');
      if (card.title.isNotEmpty) sb.writeln('<b>${card.title}</b><br>');
      if (card.content.isNotEmpty) sb.writeln(card.content);
      sb.writeln('</div>');
    }
    sb.writeln('</body></html>');
    return sb.toString();
  }

  String exportToJpeg() => exportToSvg();

  String exportToWebp() => exportToSvg();

  (String, String) exportWithEmbeddedData() {
    final json = state.toJsonString();
    final svg = exportToSvg();
    final svgWithMeta = svg.replaceFirst('</svg>', '<metadata>rfbrowser:${base64Encode(utf8.encode(json))}</metadata></svg>');
    return (svgWithMeta, json);
  }

  static CanvasData? importFromEmbeddedSvg(String svgContent) {
    final metaMatch = RegExp(r'<metadata>rfbrowser:([A-Za-z0-9+/=]+)</metadata>').firstMatch(svgContent);
    if (metaMatch == null) return null;
    try {
      final json = utf8.decode(base64Decode(metaMatch.group(1)!));
      return CanvasData.fromJsonString(json);
    } catch (_) { return null; }
  }

  static CanvasData? importFromSvg(String svgContent) {
    final embedded = importFromEmbeddedSvg(svgContent);
    if (embedded != null) return embedded;
    final rects = <CanvasCard>[];
    final rectRegex = RegExp(r'<rect[^>]*x="([^"]*)"[^>]*y="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"');
    for (final m in rectRegex.allMatches(svgContent)) {
      rects.add(CanvasCard(
        id: 'svg_${rects.length}',
        type: CanvasCardType.rectangle,
        x: double.tryParse(m.group(1) ?? '0') ?? 0,
        y: double.tryParse(m.group(2) ?? '0') ?? 0,
        width: double.tryParse(m.group(3) ?? '100') ?? 100,
        height: double.tryParse(m.group(4) ?? '60') ?? 60,
      ));
    }
    if (rects.isEmpty) return null;
    return CanvasData(cards: rects);
  }

  static CanvasData? importFromVsdx(String vsdxPath) {
    return null;
  }

  void addSvgAsCustomShape(String cardId, String svgData) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(card.copyWith(customSvgData: svgData));
    _debouncedSave();
  }

  static final Map<String, Map<String, List<CanvasCardType>>> shapeLibraryCategories = {
    'General': {'Basic': [CanvasCardType.rectangle, CanvasCardType.roundedRect, CanvasCardType.ellipse, CanvasCardType.diamond, CanvasCardType.triangle]},
    'Flowchart': {'Flow': [CanvasCardType.roundedRect, CanvasCardType.diamond, CanvasCardType.parallelogram, CanvasCardType.rectangle]},
    'UML': {'Class': [CanvasCardType.rectangle, CanvasCardType.diamond, CanvasCardType.ellipse, CanvasCardType.roundedRect]},
    'Network': {'Infrastructure': [CanvasCardType.cylinder, CanvasCardType.hexagon, CanvasCardType.ellipse, CanvasCardType.rectangle]},
    'Tables': {'Data': [CanvasCardType.table]},
    'Containers': {'Layout': [CanvasCardType.container, CanvasCardType.swimlaneH, CanvasCardType.swimlaneV]},
    'Decorative': {'Shapes': [CanvasCardType.star, CanvasCardType.hexagon, CanvasCardType.freehand]},
  };

  void loadFromData(CanvasData data) {
    _pushUndo();
    state = data;
    _debouncedSave();
  }

  static final Map<String, CanvasData> _builtInTemplates = {
    'flowchart': CanvasData(
      cards: [
        CanvasCard(id: 't_start', type: CanvasCardType.roundedRect, x: 300, y: 0, width: 120, height: 50, title: 'Start'),
        CanvasCard(id: 't_process', type: CanvasCardType.rectangle, x: 280, y: 100, width: 160, height: 60, title: 'Process'),
        CanvasCard(id: 't_decision', type: CanvasCardType.diamond, x: 270, y: 220, width: 180, height: 120, title: 'Decision?'),
        CanvasCard(id: 't_action_a', type: CanvasCardType.rectangle, x: 100, y: 400, width: 160, height: 60, title: 'Action A'),
        CanvasCard(id: 't_action_b', type: CanvasCardType.rectangle, x: 460, y: 400, width: 160, height: 60, title: 'Action B'),
        CanvasCard(id: 't_end', type: CanvasCardType.roundedRect, x: 300, y: 540, width: 120, height: 50, title: 'End'),
      ],
      connections: [
        CanvasConnection(id: 'tc1', fromCardId: 't_start', toCardId: 't_process', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'tc2', fromCardId: 't_process', toCardId: 't_decision', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'tc3', fromCardId: 't_decision', toCardId: 't_action_a', fromSide: ConnectionSide.left, toSide: ConnectionSide.top, label: 'Yes'),
        CanvasConnection(id: 'tc4', fromCardId: 't_decision', toCardId: 't_action_b', fromSide: ConnectionSide.right, toSide: ConnectionSide.top, label: 'No'),
        CanvasConnection(id: 'tc5', fromCardId: 't_action_a', toCardId: 't_end', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.left),
        CanvasConnection(id: 'tc6', fromCardId: 't_action_b', toCardId: 't_end', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.right),
      ],
    ),
    'uml_class': CanvasData(
      cards: [
        CanvasCard(id: 'u_base', type: CanvasCardType.rectangle, x: 200, y: 0, width: 200, height: 60, title: 'BaseClass', content: '+ method(): void'),
        CanvasCard(id: 'u_child1', type: CanvasCardType.rectangle, x: 50, y: 200, width: 200, height: 60, title: 'ChildClass1', content: '+ override(): void'),
        CanvasCard(id: 'u_child2', type: CanvasCardType.rectangle, x: 350, y: 200, width: 200, height: 60, title: 'ChildClass2', content: '+ newMethod(): int'),
        CanvasCard(id: 'u_iface', type: CanvasCardType.roundedRect, x: 200, y: -160, width: 200, height: 60, title: '<<interface>>', content: '+ contract(): bool'),
      ],
      connections: [
        CanvasConnection(id: 'uc1', fromCardId: 'u_child1', toCardId: 'u_base', fromSide: ConnectionSide.top, toSide: ConnectionSide.bottom, style: CanvasConnectionStyle(pathType: ConnectionPath.orthogonal, arrowStyle: ArrowStyle.triangle)),
        CanvasConnection(id: 'uc2', fromCardId: 'u_child2', toCardId: 'u_base', fromSide: ConnectionSide.top, toSide: ConnectionSide.bottom, style: CanvasConnectionStyle(pathType: ConnectionPath.orthogonal, arrowStyle: ArrowStyle.triangle)),
        CanvasConnection(id: 'uc3', fromCardId: 'u_base', toCardId: 'u_iface', fromSide: ConnectionSide.top, toSide: ConnectionSide.bottom, style: CanvasConnectionStyle(pathType: ConnectionPath.orthogonal, arrowStyle: ArrowStyle.triangle, startArrowStyle: ArrowStyle.triangle)),
      ],
    ),
    'swimlane': CanvasData(
      cards: [
        CanvasCard(id: 's_lane', type: CanvasCardType.swimlaneH, x: 0, y: 0, width: 800, height: 400, title: 'Process Flow'),
      ],
    ),
    'mindmap': CanvasData(
      cards: [
        CanvasCard(id: 'm_center', type: CanvasCardType.ellipse, x: 340, y: 200, width: 180, height: 100, title: 'Central Topic'),
        CanvasCard(id: 'm_b1', type: CanvasCardType.roundedRect, x: 50, y: 50, width: 160, height: 60, title: 'Branch 1'),
        CanvasCard(id: 'm_b2', type: CanvasCardType.roundedRect, x: 650, y: 50, width: 160, height: 60, title: 'Branch 2'),
        CanvasCard(id: 'm_b3', type: CanvasCardType.roundedRect, x: 50, y: 350, width: 160, height: 60, title: 'Branch 3'),
        CanvasCard(id: 'm_b4', type: CanvasCardType.roundedRect, x: 650, y: 350, width: 160, height: 60, title: 'Branch 4'),
      ],
      connections: [
        CanvasConnection(id: 'mc1', fromCardId: 'm_center', toCardId: 'm_b1', style: CanvasConnectionStyle(pathType: ConnectionPath.curved)),
        CanvasConnection(id: 'mc2', fromCardId: 'm_center', toCardId: 'm_b2', style: CanvasConnectionStyle(pathType: ConnectionPath.curved)),
        CanvasConnection(id: 'mc3', fromCardId: 'm_center', toCardId: 'm_b3', style: CanvasConnectionStyle(pathType: ConnectionPath.curved)),
        CanvasConnection(id: 'mc4', fromCardId: 'm_center', toCardId: 'm_b4', style: CanvasConnectionStyle(pathType: ConnectionPath.curved)),
      ],
    ),
    'network': CanvasData(
      cards: [
        CanvasCard(id: 'n_cloud', type: CanvasCardType.ellipse, x: 300, y: 0, width: 200, height: 80, title: 'Cloud / Internet'),
        CanvasCard(id: 'n_fw', type: CanvasCardType.hexagon, x: 320, y: 150, width: 160, height: 80, title: 'Firewall'),
        CanvasCard(id: 'n_lb', type: CanvasCardType.diamond, x: 320, y: 300, width: 160, height: 100, title: 'Load Balancer'),
        CanvasCard(id: 'n_srv1', type: CanvasCardType.cylinder, x: 150, y: 480, width: 140, height: 100, title: 'Server 1'),
        CanvasCard(id: 'n_srv2', type: CanvasCardType.cylinder, x: 510, y: 480, width: 140, height: 100, title: 'Server 2'),
        CanvasCard(id: 'n_db', type: CanvasCardType.cylinder, x: 330, y: 650, width: 140, height: 100, title: 'Database'),
      ],
      connections: [
        CanvasConnection(id: 'nc1', fromCardId: 'n_cloud', toCardId: 'n_fw', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'nc2', fromCardId: 'n_fw', toCardId: 'n_lb', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'nc3', fromCardId: 'n_lb', toCardId: 'n_srv1', fromSide: ConnectionSide.left, toSide: ConnectionSide.top, label: ''),
        CanvasConnection(id: 'nc4', fromCardId: 'n_lb', toCardId: 'n_srv2', fromSide: ConnectionSide.right, toSide: ConnectionSide.top, label: ''),
        CanvasConnection(id: 'nc5', fromCardId: 'n_srv1', toCardId: 'n_db', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.left),
        CanvasConnection(id: 'nc6', fromCardId: 'n_srv2', toCardId: 'n_db', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.right),
      ],
    ),
    'er_diagram': CanvasData(
      cards: [
        CanvasCard(id: 'er_user', type: CanvasCardType.rectangle, x: 100, y: 50, width: 180, height: 120, title: 'User', content: 'id: PK\nname: VARCHAR\nemail: VARCHAR'),
        CanvasCard(id: 'er_order', type: CanvasCardType.rectangle, x: 450, y: 50, width: 180, height: 120, title: 'Order', content: 'id: PK\nuser_id: FK\ntotal: DECIMAL'),
        CanvasCard(id: 'er_product', type: CanvasCardType.rectangle, x: 450, y: 300, width: 180, height: 120, title: 'Product', content: 'id: PK\nname: VARCHAR\nprice: DECIMAL'),
        CanvasCard(id: 'er_item', type: CanvasCardType.diamond, x: 250, y: 300, width: 160, height: 100, title: 'OrderItem'),
      ],
      connections: [
        CanvasConnection(id: 'erc1', fromCardId: 'er_user', toCardId: 'er_order', fromSide: ConnectionSide.right, toSide: ConnectionSide.left, label: '1:N'),
        CanvasConnection(id: 'erc2', fromCardId: 'er_order', toCardId: 'er_item', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top, label: '1:N'),
        CanvasConnection(id: 'erc3', fromCardId: 'er_product', toCardId: 'er_item', fromSide: ConnectionSide.left, toSide: ConnectionSide.right, label: '1:N'),
      ],
    ),
    'kanban': CanvasData(
      cards: [
        CanvasCard(id: 'kb_col1', type: CanvasCardType.swimlaneV, x: 0, y: 0, width: 240, height: 600, title: 'To Do'),
        CanvasCard(id: 'kb_col2', type: CanvasCardType.swimlaneV, x: 260, y: 0, width: 240, height: 600, title: 'In Progress'),
        CanvasCard(id: 'kb_col3', type: CanvasCardType.swimlaneV, x: 520, y: 0, width: 240, height: 600, title: 'Done'),
      ],
    ),
    'org_chart': CanvasData(
      cards: [
        CanvasCard(id: 'oc_ceo', type: CanvasCardType.roundedRect, x: 300, y: 0, width: 160, height: 60, title: 'CEO'),
        CanvasCard(id: 'oc_cto', type: CanvasCardType.roundedRect, x: 120, y: 120, width: 160, height: 60, title: 'CTO'),
        CanvasCard(id: 'oc_cfo', type: CanvasCardType.roundedRect, x: 480, y: 120, width: 160, height: 60, title: 'CFO'),
        CanvasCard(id: 'oc_dev1', type: CanvasCardType.roundedRect, x: 30, y: 240, width: 140, height: 50, title: 'Dev Lead'),
        CanvasCard(id: 'oc_dev2', type: CanvasCardType.roundedRect, x: 200, y: 240, width: 140, height: 50, title: 'QA Lead'),
        CanvasCard(id: 'oc_acc', type: CanvasCardType.roundedRect, x: 420, y: 240, width: 140, height: 50, title: 'Accounting'),
        CanvasCard(id: 'oc_hr', type: CanvasCardType.roundedRect, x: 590, y: 240, width: 140, height: 50, title: 'HR'),
      ],
      connections: [
        CanvasConnection(id: 'occ1', fromCardId: 'oc_ceo', toCardId: 'oc_cto', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'occ2', fromCardId: 'oc_ceo', toCardId: 'oc_cfo', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'occ3', fromCardId: 'oc_cto', toCardId: 'oc_dev1', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'occ4', fromCardId: 'oc_cto', toCardId: 'oc_dev2', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'occ5', fromCardId: 'oc_cfo', toCardId: 'oc_acc', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'occ6', fromCardId: 'oc_cfo', toCardId: 'oc_hr', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
      ],
    ),
    'state_machine': CanvasData(
      cards: [
        CanvasCard(id: 'sm_init', type: CanvasCardType.ellipse, x: 300, y: 0, width: 100, height: 50, title: 'Init'),
        CanvasCard(id: 'sm_idle', type: CanvasCardType.roundedRect, x: 280, y: 120, width: 140, height: 60, title: 'Idle'),
        CanvasCard(id: 'sm_active', type: CanvasCardType.roundedRect, x: 280, y: 260, width: 140, height: 60, title: 'Active'),
        CanvasCard(id: 'sm_paused', type: CanvasCardType.roundedRect, x: 80, y: 260, width: 140, height: 60, title: 'Paused'),
        CanvasCard(id: 'sm_done', type: CanvasCardType.ellipse, x: 280, y: 400, width: 140, height: 60, title: 'Done'),
        CanvasCard(id: 'sm_error', type: CanvasCardType.diamond, x: 500, y: 260, width: 140, height: 100, title: 'Error'),
      ],
      connections: [
        CanvasConnection(id: 'smc1', fromCardId: 'sm_init', toCardId: 'sm_idle', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top),
        CanvasConnection(id: 'smc2', fromCardId: 'sm_idle', toCardId: 'sm_active', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top, label: 'start'),
        CanvasConnection(id: 'smc3', fromCardId: 'sm_active', toCardId: 'sm_paused', fromSide: ConnectionSide.left, toSide: ConnectionSide.right, label: 'pause'),
        CanvasConnection(id: 'smc4', fromCardId: 'sm_paused', toCardId: 'sm_active', fromSide: ConnectionSide.right, toSide: ConnectionSide.left, label: 'resume'),
        CanvasConnection(id: 'smc5', fromCardId: 'sm_active', toCardId: 'sm_done', fromSide: ConnectionSide.bottom, toSide: ConnectionSide.top, label: 'finish'),
        CanvasConnection(id: 'smc6', fromCardId: 'sm_active', toCardId: 'sm_error', fromSide: ConnectionSide.right, toSide: ConnectionSide.left, label: 'error'),
        CanvasConnection(id: 'smc7', fromCardId: 'sm_error', toCardId: 'sm_idle', fromSide: ConnectionSide.top, toSide: ConnectionSide.right, label: 'reset'),
      ],
    ),
    'venn': CanvasData(
      cards: [
        CanvasCard(id: 'vn_a', type: CanvasCardType.ellipse, x: 100, y: 100, width: 250, height: 250, title: 'Set A', colorValue: 0xFFE3F2FD),
        CanvasCard(id: 'vn_b', type: CanvasCardType.ellipse, x: 300, y: 100, width: 250, height: 250, title: 'Set B', colorValue: 0xFFFCE4EC),
        CanvasCard(id: 'vn_c', type: CanvasCardType.ellipse, x: 200, y: 280, width: 250, height: 250, title: 'Set C', colorValue: 0xFFE8F5E9),
      ],
    ),
    'timeline': CanvasData(
      cards: [
        CanvasCard(id: 'tl_1', type: CanvasCardType.roundedRect, x: 0, y: 80, width: 140, height: 60, title: 'Phase 1'),
        CanvasCard(id: 'tl_2', type: CanvasCardType.roundedRect, x: 180, y: 80, width: 140, height: 60, title: 'Phase 2'),
        CanvasCard(id: 'tl_3', type: CanvasCardType.roundedRect, x: 360, y: 80, width: 140, height: 60, title: 'Phase 3'),
        CanvasCard(id: 'tl_4', type: CanvasCardType.roundedRect, x: 540, y: 80, width: 140, height: 60, title: 'Phase 4'),
      ],
      connections: [
        CanvasConnection(id: 'tlc1', fromCardId: 'tl_1', toCardId: 'tl_2', fromSide: ConnectionSide.right, toSide: ConnectionSide.left),
        CanvasConnection(id: 'tlc2', fromCardId: 'tl_2', toCardId: 'tl_3', fromSide: ConnectionSide.right, toSide: ConnectionSide.left),
        CanvasConnection(id: 'tlc3', fromCardId: 'tl_3', toCardId: 'tl_4', fromSide: ConnectionSide.right, toSide: ConnectionSide.left),
      ],
    ),
    'gantt': CanvasData(
      cards: [
        CanvasCard(id: 'gt_header', type: CanvasCardType.swimlaneH, x: 0, y: 0, width: 800, height: 400, title: 'Gantt Chart'),
      ],
    ),
    'decision_tree': CanvasData(
      cards: [
        CanvasCard(id: 'dt_root', type: CanvasCardType.diamond, x: 270, y: 0, width: 180, height: 120, title: 'Condition?'),
        CanvasCard(id: 'dt_y1', type: CanvasCardType.diamond, x: 50, y: 200, width: 180, height: 120, title: 'Check A?'),
        CanvasCard(id: 'dt_n1', type: CanvasCardType.diamond, x: 490, y: 200, width: 180, height: 120, title: 'Check B?'),
        CanvasCard(id: 'dt_yy', type: CanvasCardType.roundedRect, x: 0, y: 400, width: 120, height: 50, title: 'Result 1'),
        CanvasCard(id: 'dt_yn', type: CanvasCardType.roundedRect, x: 160, y: 400, width: 120, height: 50, title: 'Result 2'),
        CanvasCard(id: 'dt_ny', type: CanvasCardType.roundedRect, x: 440, y: 400, width: 120, height: 50, title: 'Result 3'),
        CanvasCard(id: 'dt_nn', type: CanvasCardType.roundedRect, x: 600, y: 400, width: 120, height: 50, title: 'Result 4'),
      ],
      connections: [
        CanvasConnection(id: 'dtc1', fromCardId: 'dt_root', toCardId: 'dt_y1', fromSide: ConnectionSide.left, toSide: ConnectionSide.top, label: 'Yes'),
        CanvasConnection(id: 'dtc2', fromCardId: 'dt_root', toCardId: 'dt_n1', fromSide: ConnectionSide.right, toSide: ConnectionSide.top, label: 'No'),
        CanvasConnection(id: 'dtc3', fromCardId: 'dt_y1', toCardId: 'dt_yy', fromSide: ConnectionSide.left, toSide: ConnectionSide.top, label: 'Yes'),
        CanvasConnection(id: 'dtc4', fromCardId: 'dt_y1', toCardId: 'dt_yn', fromSide: ConnectionSide.right, toSide: ConnectionSide.top, label: 'No'),
        CanvasConnection(id: 'dtc5', fromCardId: 'dt_n1', toCardId: 'dt_ny', fromSide: ConnectionSide.left, toSide: ConnectionSide.top, label: 'Yes'),
        CanvasConnection(id: 'dtc6', fromCardId: 'dt_n1', toCardId: 'dt_nn', fromSide: ConnectionSide.right, toSide: ConnectionSide.top, label: 'No'),
      ],
    ),
  };

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
        final file = File(p.join(vaultPath, '.rf', 'canvases', '$name.canvas.json'));
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
        final oldFile = File(p.join(vaultPath, '.rf', 'canvases', '$oldName.canvas.json'));
        final newFile = File(p.join(vaultPath, '.rf', 'canvases', '$trimmed.canvas.json'));
        if (await oldFile.exists()) await oldFile.rename(newFile.path);
      }
    } catch (_) {
      debugPrint('Canvas: failed to rename canvas file from "$oldName" to "$newName"');
    }
    return true;
  }

  // === Layer Management ===

  Future<void> addLayer(String name) async {
    _pushUndo();
    final layer = CanvasLayer(
      id: 'layer_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      order: state.layers.length,
    );
    state = state.copyWith(layers: [...state.layers, layer]);
    await _save();
  }

  Future<void> removeLayer(String layerId) async {
    _pushUndo();
    final newLayers = state.layers.where((l) => l.id != layerId).toList();
    final newCards = state.cards.map((c) {
      if (c.layerId == layerId) return c.copyWith(clearLayerId: true);
      return c;
    }).toList();
    state = state.copyWith(layers: newLayers, cards: newCards);
    await _save();
  }

  void renameLayer(String layerId, String name) {
    final layers = state.layers.map((l) {
      if (l.id == layerId) return l.copyWith(name: name);
      return l;
    }).toList();
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void toggleLayerVisibility(String layerId) {
    final layers = state.layers.map((l) {
      if (l.id == layerId) return l.copyWith(visible: !l.visible);
      return l;
    }).toList();
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void toggleLayerLock(String layerId) {
    final layers = state.layers.map((l) {
      if (l.id == layerId) return l.copyWith(locked: !l.locked);
      return l;
    }).toList();
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void moveCardToLayer(String cardId, String? layerId) {
    final cards = state.cards.map((c) {
      if (c.id == cardId) {
        return layerId != null ? c.copyWith(layerId: layerId) : c.copyWith(clearLayerId: true);
      }
      return c;
    }).toList();
    state = state.copyWith(cards: cards);
    _debouncedSave();
  }

  bool isLayerLocked(String cardId) {
    final card = cardById(cardId);
    if (card == null || card.layerId == null) return false;
    final layer = state.layers.where((l) => l.id == card.layerId).firstOrNull;
    return layer?.locked ?? false;
  }

  bool isLayerVisible(String cardId) {
    final card = cardById(cardId);
    if (card == null || card.layerId == null) return true;
    final layer = state.layers.where((l) => l.id == card.layerId).firstOrNull;
    return layer?.visible ?? true;
  }

  void reorderLayer(String layerId, int newOrder) {
    final sortedLayers = List<CanvasLayer>.from(state.layers)
      ..sort((a, b) => a.order.compareTo(b.order));
    sortedLayers.removeWhere((l) => l.id == layerId);
    final targetLayer = state.layers.where((l) => l.id == layerId).firstOrNull;
    if (targetLayer == null) return;
    newOrder = newOrder.clamp(0, sortedLayers.length);
    sortedLayers.insert(newOrder, targetLayer);
    final reordered = <CanvasLayer>[];
    for (int i = 0; i < sortedLayers.length; i++) {
      reordered.add(sortedLayers[i].copyWith(order: i));
    }
    state = state.copyWith(layers: reordered);
    _debouncedSave();
  }

  void moveLayerUp(String layerId) {
    final sortedLayers = List<CanvasLayer>.from(state.layers)
      ..sort((a, b) => a.order.compareTo(b.order));
    final idx = sortedLayers.indexWhere((l) => l.id == layerId);
    if (idx <= 0) return;
    final temp = sortedLayers[idx];
    sortedLayers[idx] = sortedLayers[idx - 1];
    sortedLayers[idx - 1] = temp;
    final reordered = <CanvasLayer>[];
    for (int i = 0; i < sortedLayers.length; i++) {
      reordered.add(sortedLayers[i].copyWith(order: i));
    }
    state = state.copyWith(layers: reordered);
    _debouncedSave();
  }

  void moveLayerDown(String layerId) {
    final sortedLayers = List<CanvasLayer>.from(state.layers)
      ..sort((a, b) => a.order.compareTo(b.order));
    final idx = sortedLayers.indexWhere((l) => l.id == layerId);
    if (idx < 0 || idx >= sortedLayers.length - 1) return;
    final temp = sortedLayers[idx];
    sortedLayers[idx] = sortedLayers[idx + 1];
    sortedLayers[idx + 1] = temp;
    final reordered = <CanvasLayer>[];
    for (int i = 0; i < sortedLayers.length; i++) {
      reordered.add(sortedLayers[i].copyWith(order: i));
    }
    state = state.copyWith(layers: reordered);
    _debouncedSave();
  }

  int cardCountForLayer(String layerId) {
    return state.cards.where((c) => c.layerId == layerId).length;
  }

  // === Auto Layout ===

  void autoLayout(AutoLayoutType type) {
    if (state.cards.isEmpty) return;
    _pushUndo();
    final newCards = List<CanvasCard>.from(state.cards);
    switch (type) {
      case AutoLayoutType.forceDirected:
        _forceDirectedLayout(newCards);
      case AutoLayoutType.hierarchical:
        _hierarchicalLayout(newCards);
      case AutoLayoutType.grid:
        _gridLayout(newCards);
    }
    state = state.copyWith(cards: newCards);
    _debouncedSave();
  }

  void _forceDirectedLayout(List<CanvasCard> cards) {
    final n = cards.length;
    if (n == 0) return;
    final positions = <String, (double, double)>{};
    for (int i = 0; i < n; i++) {
      final angle = 2 * 3.14159265 * i / n;
      final radius = 200.0 * (n > 1 ? 1 : 0);
      positions[cards[i].id] = (radius * (1 + angle / 6.28) * 2 - radius, radius * (1 + (angle * 0.5).abs()));
    }
    for (int iter = 0; iter < 50; iter++) {
      final forces = <String, (double, double)>{};
      for (final card in cards) {
        forces[card.id] = (0.0, 0.0);
      }
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          final a = cards[i];
          final b = cards[j];
          final posA = positions[a.id]!;
          final posB = positions[b.id]!;
          final dx = posB.$1 - posA.$1;
          final dy = posB.$2 - posA.$2;
          final dist = (dx * dx + dy * dy).toDouble().clamp(1.0, double.infinity);
          final repulsion = 50000.0 / dist;
          final fx = dx / math.sqrt(dist) * repulsion;
          final fy = dy / math.sqrt(dist) * repulsion;
          forces[a.id] = (forces[a.id]!.$1 - fx, forces[a.id]!.$2 - fy);
          forces[b.id] = (forces[b.id]!.$1 + fx, forces[b.id]!.$2 + fy);
        }
      }
      for (final conn in state.connections) {
        final posA = positions[conn.fromCardId];
        final posB = positions[conn.toCardId];
        if (posA == null || posB == null) continue;
        final dx = posB.$1 - posA.$1;
        final dy = posB.$2 - posA.$2;
        final dist = (dx * dx + dy * dy).toDouble().clamp(1.0, double.infinity);
        final attraction = dist * 0.01;
        final fx = dx / math.sqrt(dist) * attraction;
        final fy = dy / math.sqrt(dist) * attraction;
        forces[conn.fromCardId] = (forces[conn.fromCardId]!.$1 + fx, forces[conn.fromCardId]!.$2 + fy);
        forces[conn.toCardId] = (forces[conn.toCardId]!.$1 - fx, forces[conn.toCardId]!.$2 - fy);
      }
      for (final card in cards) {
        final f = forces[card.id]!;
        final pos = positions[card.id]!;
        final maxMove = 20.0;
        final fx = f.$1.clamp(-maxMove, maxMove);
        final fy = f.$2.clamp(-maxMove, maxMove);
        positions[card.id] = (pos.$1 + fx, pos.$2 + fy);
      }
    }
    for (int i = 0; i < cards.length; i++) {
      final pos = positions[cards[i].id]!;
      cards[i] = cards[i].copyWith(x: _snapToGrid(pos.$1), y: _snapToGrid(pos.$2));
    }
  }

  void _hierarchicalLayout(List<CanvasCard> cards) {
    final cardMap = <String, CanvasCard>{};
    for (final c in cards) { cardMap[c.id] = c; }
    final hasIncoming = <String, int>{};
    for (final c in cards) { hasIncoming[c.id] = 0; }
    for (final conn in state.connections) {
      if (hasIncoming.containsKey(conn.toCardId)) {
        hasIncoming[conn.toCardId] = hasIncoming[conn.toCardId]! + 1;
      }
    }
    final levels = <String, int>{};
    final visited = <String>{};
    void assignLevel(String id, int level) {
      if (visited.contains(id)) return;
      visited.add(id);
      levels[id] = level;
      for (final conn in state.connections) {
        if (conn.fromCardId == id && cardMap.containsKey(conn.toCardId)) {
          assignLevel(conn.toCardId, level + 1);
        }
      }
    }
    for (final c in cards) {
      if (hasIncoming[c.id] == 0) assignLevel(c.id, 0);
    }
    for (final c in cards) {
      if (!levels.containsKey(c.id)) levels[c.id] = 0;
    }
    final maxLevel = levels.values.fold(0, (a, b) => a > b ? a : b);
    final byLevel = <int, List<String>>{};
    for (final entry in levels.entries) {
      byLevel.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    for (int level = 0; level <= maxLevel; level++) {
      final ids = byLevel[level] ?? [];
      for (int i = 0; i < ids.length; i++) {
        final card = cardMap[ids[i]]!;
        final idx = cards.indexWhere((c) => c.id == ids[i]);
        if (idx >= 0) {
          cards[idx] = card.copyWith(
            x: _snapToGrid(200.0 + i * 300.0),
            y: _snapToGrid(200.0 + level * 200.0),
          );
        }
      }
    }
  }

  void _gridLayout(List<CanvasCard> cards) {
    final n = cards.length;
    final cols = math.sqrt(n).ceil();
    for (int i = 0; i < n; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      cards[i] = cards[i].copyWith(
        x: _snapToGrid(100.0 + col * 300.0),
        y: _snapToGrid(100.0 + row * 220.0),
      );
    }
  }

  double _snapToGrid(double value) {
    if (!state.settings.snapToGrid) return value;
    return (value / 20).roundToDouble() * 20.0;
  }

  // === Export ===

  String exportToSvg() {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final card in state.cards) {
      minX = minX < card.x ? minX : card.x;
      minY = minY < card.y ? minY : card.y;
      final rx = card.x + card.width;
      final ry = card.y + card.height;
      maxX = maxX > rx ? maxX : rx;
      maxY = maxY > ry ? maxY : ry;
    }
    if (minX == double.infinity) { minX = 0; minY = 0; maxX = 800; maxY = 600; }
    final pad = 40.0;
    final w = maxX - minX + pad * 2;
    final h = maxY - minY + pad * 2;
    buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="${minX - pad} ${minY - pad} $w $h">');
    for (final conn in state.connections) {
      final from = cardById(conn.fromCardId);
      final to = cardById(conn.toCardId);
      if (from == null || to == null) continue;
      final (fs, ts) = CanvasConnection.computeSides(from, to);
      final fp = fs.point(from.rect, conn.fromSideOffset);
      final tp = ts.point(to.rect, conn.toSideOffset);
      buffer.writeln('<line x1="${fp.dx}" y1="${fp.dy}" x2="${tp.dx}" y2="${tp.dy}" stroke="#666" stroke-width="2"/>');
      if (conn.label.isNotEmpty) {
        final mx = (fp.dx + tp.dx) / 2;
        final my = (fp.dy + tp.dy) / 2;
        buffer.writeln('<text x="$mx" y="$my" text-anchor="middle" font-size="12" fill="#666">${_xmlEscape(conn.label)}</text>');
      }
    }
    for (final card in state.cards) {
      final hex = '#${(card.colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      final strokeHex = '#${(card.style?.borderColor ?? 0xFFE0E0E0 & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      final r = card.style?.borderRadius ?? 8.0;
      buffer.writeln('<rect x="${card.x}" y="${card.y}" width="${card.width}" height="${card.height}" rx="$r" fill="$hex" stroke="$strokeHex" stroke-width="1"/>');
      if (card.title.isNotEmpty) {
        buffer.writeln('<text x="${card.x + 12}" y="${card.y + 20}" font-size="14" font-weight="bold" fill="#333">${_xmlEscape(card.title)}</text>');
      }
      if (card.content.isNotEmpty) {
        final lines = card.content.split('\n').take(5);
        var cy = card.y + 40;
        for (final line in lines) {
          buffer.writeln('<text x="${card.x + 12}" y="$cy" font-size="12" fill="#666">${_xmlEscape(line)}</text>');
          cy += 16;
        }
      }
    }
    buffer.writeln('</svg>');
    return buffer.toString();
  }

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
          ? (state.layers.where((l) => l.id == c.layerId).firstOrNull?.name ?? '-')
          : '-';
      buffer.writeln('| ${i + 1} | ${c.type.label} | ${c.title} | (${c.x.round()}, ${c.y.round()}) | $layerName |');
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

  String _xmlEscape(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

  // === Scratchpad ===

  Future<List<ScratchpadItem>> loadScratchpad() async {
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return [];
      final file = File(p.join(vaultPath, '.rf', 'scratchpad.json'));
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString()) as List;
      return json.map((e) => ScratchpadItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveScratchpadItem(ScratchpadItem item) async {
    final items = await loadScratchpad();
    items.add(item);
    await _saveScratchpad(items);
  }

  Future<void> removeScratchpadItem(String itemId) async {
    final items = await loadScratchpad();
    items.removeWhere((i) => i.id == itemId);
    await _saveScratchpad(items);
  }

  Future<void> _saveScratchpad(List<ScratchpadItem> items) async {
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
      final dir = Directory(p.join(vaultPath, '.rf'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'scratchpad.json'));
      await file.writeAsString(jsonEncode(items.map((i) => i.toJson()).toList()));
    } catch (_) {
      debugPrint('Canvas: failed to save scratchpad');
    }
  }

  CanvasCard createCardFromScratchpad(ScratchpadItem item, Offset pos) {
    return CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: item.type,
      x: pos.dx,
      y: pos.dy,
      width: item.width,
      height: item.height,
      colorValue: item.colorValue,
      style: item.style,
      title: item.name,
    );
  }
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasData>(
  CanvasNotifier.new,
);

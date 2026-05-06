import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  String get activeCanvasName => _activeCanvasName;
  List<String> get canvasNames => List.unmodifiable(_canvasNames);

  Future<SharedPreferences> get _ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  CanvasData build() => CanvasData();

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
    state = state.copyWith(cards: [...state.cards, card]);
    await _save();
  }

  Future<void> updateCard(CanvasCard card) async {
    final cards = state.cards.map((c) => c.id == card.id ? card : c).toList();
    state = state.copyWith(cards: cards);
    await _save();
  }

  Future<void> removeCard(String cardId) async {
    state = state.copyWith(
      cards: state.cards.where((c) => c.id != cardId).toList(),
      connections: state.connections
          .where((c) => c.fromCardId != cardId && c.toCardId != cardId)
          .toList(),
    );
    await _save();
  }

  Future<void> addConnection(CanvasConnection conn) async {
    state = state.copyWith(connections: [...state.connections, conn]);
    await _save();
  }

  Future<void> removeConnection(String connId) async {
    state = state.copyWith(
      connections: state.connections.where((c) => c.id != connId).toList(),
    );
    await _save();
  }

  Future<void> clearCanvas() async {
    state = CanvasData();
    await _save();
  }

  CanvasCard? cardById(String id) {
    try {
      return state.cards.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
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
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasData>(
  CanvasNotifier.new,
);

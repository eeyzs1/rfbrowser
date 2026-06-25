import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../data/models/canvas_model.dart';
import '../data/models/note.dart';
import '../data/stores/vault_store.dart';
import '../core/link/link_resolver.dart';
import '../core/shared_prefs_aware.dart';
import '../core/logging/app_logger.dart';
import 'canvas/canvas_layout_service.dart';
import 'canvas/canvas_export_service.dart';
import 'canvas/canvas_layers_service.dart';
import 'canvas/canvas_scratchpad_service.dart';
import 'canvas/canvas_style_service.dart';
import 'canvas/canvas_templates_service.dart';

part 'canvas_card_operations.dart';
part 'canvas_connection_operations.dart';
part 'canvas_selection_batch_operations.dart';
part 'canvas_layer_operations.dart';
part 'canvas_canvas_management.dart';
part 'canvas_export_operations.dart';
part 'canvas_layout_settings_operations.dart';
part 'canvas_scratchpad_template_operations.dart';
part 'canvas_style_operations.dart';

/// Base class holding core infrastructure: fields, constructor, getters,
/// undo/redo, file I/O, mutation helpers, and lookup helpers.
///
/// Mixins (in part files) use `on CanvasNotifierBase` to access these
/// private members within the same library. [CanvasNotifier] extends this
/// base and mixes in all operation mixins.
class CanvasNotifierBase extends Notifier<CanvasData>
    with SharedPrefsAware {
  final CanvasLayoutService _layoutService;
  final CanvasExportService _exportService;
  final CanvasLayersService _layersService;
  final CanvasScratchpadService _scratchpadService;
  final CanvasStyleService _styleService;

  Timer? _debounceTimer;
  List<String> _canvasNames = ['default'];
  String _activeCanvasName = 'default';
  final List<CanvasData> _undoStack = [];
  final List<CanvasData> _redoStack = [];
  static const int _maxHistory = 50;

  CanvasNotifierBase({
    CanvasLayoutService? layoutService,
    CanvasExportService? exportService,
    CanvasLayersService? layersService,
    CanvasScratchpadService? scratchpadService,
    CanvasStyleService? styleService,
  }) : _layoutService = layoutService ?? const CanvasLayoutService(),
       _exportService = exportService ?? const CanvasExportService(),
       _layersService = layersService ?? const CanvasLayersService(),
       _scratchpadService =
           scratchpadService ?? const CanvasScratchpadService(),
       _styleService = styleService ?? const CanvasStyleService();

  // === Public getters ===

  String get activeCanvasName => _activeCanvasName;
  List<String> get canvasNames => List.unmodifiable(_canvasNames);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get autoConnectionsEnabled => state.settings.autoConnectionsEnabled;
  int get unassignedCardCount =>
      state.cards.where((c) => c.layerId == null).length;

  // === Lifecycle ===

  @override
  CanvasData build() => CanvasData();

  Future<void> initialize() async {
    await _loadCanvasList();
    await _loadFromFile();
  }

  // === Undo / Redo ===

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

  // === Canvas-list I/O ===

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
      appLog.error('Canvas: failed to save canvas list');
    }
  }

  // === File I/O (persistence core) ===

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
      appLog.error('Canvas save failed', error: e);
    }
  }

  Future<void> _saveToSharedPrefs() async {
    final prefs = await ensurePrefs;
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
      appLog.error('Canvas: failed to load canvas from file');
    }
    await _migrateFromSharedPrefs();
  }

  Future<void> _migrateFromSharedPrefs() async {
    final prefs = await ensurePrefs;
    final json = prefs.getString('canvas_data');
    if (json != null) {
      state = CanvasData.fromJsonString(json);
      try {
        await prefs.remove('canvas_data');
        await _saveToFile();
      } catch (_) {
        appLog.error('Canvas: migration from SharedPrefs failed');
      }
    }
  }

  // === Core mutation helpers ===

  void updateCardInMemory(CanvasCard card) {
    final cards = state.cards.map((c) => c.id == card.id ? card : c).toList();
    state = state.copyWith(cards: cards);
    _debouncedSave();
  }

  Future<void> persist() async {
    _debounceTimer?.cancel();
    await _save();
  }

  Future<void> _mutateAndPersist(CanvasData Function() mutation) async {
    _pushUndo();
    state = mutation();
    await _save();
  }

  void _mutateAndDebounce(CanvasData Function() mutation) {
    state = mutation();
    _debouncedSave();
  }

  // === Lookup helpers ===

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
}

/// Manages canvas state (cards, connections, groups, layers, settings) and
/// delegates to specialized services for layout, export, layers, scratchpad,
/// style, and templates.
///
/// The class is split across multiple part files using mixins to keep each
/// concern in its own file while sharing private infrastructure via
/// [CanvasNotifierBase]:
/// - [CanvasCardOperations]: card CRUD, tags, factory, per-card style setters
/// - [CanvasConnectionOperations]: connection CRUD, waypoints, auto-conn, search
/// - [CanvasSelectionBatchOperations]: selection, inline editing, batch ops
/// - [CanvasLayerOperations]: layer add/remove/rename/visibility/lock/reorder
/// - [CanvasCanvasManagement]: multi-canvas create/switch/delete/rename
/// - [CanvasExportOperations]: export delegation (non-static)
/// - [CanvasLayoutSettingsOperations]: auto-layout + settings toggles
/// - [CanvasScratchpadTemplateOperations]: scratchpad + templates
/// - [CanvasStyleOperations]: default styles + background color
class CanvasNotifier extends CanvasNotifierBase
    with
        CanvasCardOperations,
        CanvasConnectionOperations,
        CanvasSelectionBatchOperations,
        CanvasLayerOperations,
        CanvasCanvasManagement,
        CanvasExportOperations,
        CanvasLayoutSettingsOperations,
        CanvasScratchpadTemplateOperations,
        CanvasStyleOperations {
  CanvasNotifier({
    super.layoutService,
    super.exportService,
    super.layersService,
    super.scratchpadService,
    super.styleService,
  });

  // === Static import methods (cannot live in mixins) ===

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
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasData>(
  CanvasNotifier.new,
);

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShortcutConflictError implements Exception {
  final String message;
  final String existingAction;

  ShortcutConflictError(this.message, this.existingAction);

  @override
  String toString() =>
      'ShortcutConflictError: $message (conflicts with $existingAction)';
}

/// G11-AC2: a single conflict between two actions sharing a shortcut.
class ShortcutConflict {
  final String shortcut;
  final String actionA;
  final String actionB;

  const ShortcutConflict({
    required this.shortcut,
    required this.actionA,
    required this.actionB,
  });

  @override
  String toString() =>
      'ShortcutConflict($actionA, $actionB) both bound to "$shortcut"';

  @override
  bool operator ==(Object other) =>
      other is ShortcutConflict &&
      other.shortcut == shortcut &&
      other.actionA == actionA &&
      other.actionB == actionB;

  @override
  int get hashCode => Object.hash(shortcut, actionA, actionB);
}

class ShortcutService {
  Map<String, String> _bindings = {};
  Map<String, String> _defaults = {};
  SharedPreferences? _prefs;

  ShortcutService() {
    _defaults = {
      'new_note': 'Ctrl+N',
      'save': 'Ctrl+S',
      'search': 'Ctrl+K',
      'toggle_editor': 'Ctrl+E',
      'toggle_browser': 'Ctrl+B',
      'toggle_graph': 'Ctrl+Shift+G',
      'toggle_canvas': 'Ctrl+Shift+C',
      'daily_note': 'Ctrl+D',
      'toggle_preview': 'Ctrl+P',
      'settings': 'Ctrl+W',
      'find': 'Ctrl+F',
      'switch_capture': 'Ctrl+1',
      'switch_think': 'Ctrl+2',
      'switch_connect': 'Ctrl+3',
      'connect_canvas': 'Ctrl+4',
      'connect_graph': 'Ctrl+5',
      'canvas_undo': 'Ctrl+Z',
      'canvas_redo': 'Ctrl+Y',
      'canvas_delete': 'Delete',
      'canvas_select_all': 'Ctrl+A',
      'canvas_group': 'Ctrl+G',
      'canvas_ungroup': 'Ctrl+Shift+U',
      'memory_browser': 'Ctrl+Shift+M',
    };
    _bindings = Map.from(_defaults);
  }

  String? getShortcut(String action) => _bindings[action];

  Map<String, String> get allBindings => Map.unmodifiable(_bindings);

  Map<String, String> get defaults => Map.unmodifiable(_defaults);

  void register(String action, String shortcut) {
    final existing = _findActionForShortcut(shortcut);
    if (existing != null && existing != action) {
      throw ShortcutConflictError(
        'Shortcut $shortcut is already bound to $existing',
        existing,
      );
    }
    _bindings[action] = shortcut;
  }

  /// Bypasses conflict detection. Used by tests and one-off user overrides
  /// where the caller has already resolved any conflict explicitly.
  void forceRegister(String action, String shortcut) {
    _bindings[action] = shortcut;
  }

  /// Removes the binding for [action]. Returns true if anything was removed.
  bool unregister(String action) {
    return _bindings.remove(action) != null;
  }

  String? findActionForShortcut(String shortcut) =>
      _findActionForShortcut(shortcut);

  String? _findActionForShortcut(String shortcut) {
    for (final entry in _bindings.entries) {
      if (entry.value.toLowerCase() == shortcut.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }

  void resetToDefaults() {
    _bindings = Map.from(_defaults);
  }

  /// G11-AC2: returns every pair of actions that share the same shortcut.
  /// Each pair appears once (sorted by action key for determinism). For N
  /// colliding actions on the same shortcut, returns C(N,2) pairs.
  List<ShortcutConflict> detectConflicts() {
    final byShortcut = <String, List<String>>{};
    for (final entry in _bindings.entries) {
      final key = entry.value.toLowerCase();
      byShortcut.putIfAbsent(key, () => []).add(entry.key);
    }
    final conflicts = <ShortcutConflict>[];
    for (final entry in byShortcut.entries) {
      final actions = entry.value;
      if (actions.length < 2) continue;
      actions.sort();
      for (var i = 0; i < actions.length; i++) {
        for (var j = i + 1; j < actions.length; j++) {
          conflicts.add(
            ShortcutConflict(
              shortcut: entry.key,
              actionA: actions[i],
              actionB: actions[j],
            ),
          );
        }
      }
    }
    return conflicts;
  }

  Future<void> persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('rfbrowser_shortcuts', jsonEncode(_bindings));
  }

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final json = _prefs!.getString('rfbrowser_shortcuts');
    if (json != null) {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _bindings = decoded.map((k, v) => MapEntry(k, v as String));
    }
  }
}

final shortcutServiceProvider = Provider<ShortcutService>((ref) {
  final service = ShortcutService();
  return service;
});

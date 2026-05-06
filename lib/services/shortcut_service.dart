import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShortcutConflictError implements Exception {
  final String message;
  final String existingAction;

  ShortcutConflictError(this.message, this.existingAction);

  @override
  String toString() => 'ShortcutConflictError: $message (conflicts with $existingAction)';
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

  String? findActionForShortcut(String shortcut) => _findActionForShortcut(shortcut);

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

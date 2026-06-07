import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/services/shortcut_service.dart';

void main() {
  group('Shortcut Service Integration', () {
    late ProviderContainer container;
    late ShortcutService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      service = container.read(shortcutServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('service has default shortcuts', () {
      final bindings = service.allBindings;
      expect(bindings, isNotEmpty);
      expect(bindings.containsKey('new_note'), isTrue);
      expect(bindings.containsKey('save'), isTrue);
      expect(bindings.containsKey('search'), isTrue);
    });

    test('getShortcut returns default binding', () {
      expect(service.getShortcut('new_note'), 'Ctrl+N');
      expect(service.getShortcut('save'), 'Ctrl+S');
      expect(service.getShortcut('search'), 'Ctrl+K');
      expect(service.getShortcut('toggle_editor'), 'Ctrl+E');
      expect(service.getShortcut('toggle_browser'), 'Ctrl+B');
      expect(service.getShortcut('daily_note'), 'Ctrl+D');
    });

    test('getShortcut returns null for unknown action', () {
      expect(service.getShortcut('unknown_action'), isNull);
    });

    test('register sets custom shortcut', () {
      service.register('new_note', 'Ctrl+Shift+N');

      expect(service.getShortcut('new_note'), 'Ctrl+Shift+N');
    });

    test('register throws ShortcutConflictError on duplicate shortcut', () {
      service.register('new_note', 'Ctrl+Shift+N');

      expect(
        () => service.register('save', 'Ctrl+Shift+N'),
        throwsA(isA<ShortcutConflictError>()),
      );
    });

    test('resetToDefaults restores all defaults', () {
      service.register('new_note', 'Ctrl+Shift+N');
      service.register('save', 'Ctrl+Shift+S');

      service.resetToDefaults();
      expect(service.getShortcut('new_note'), 'Ctrl+N');
      expect(service.getShortcut('save'), 'Ctrl+S');
    });

    test('defaults is unmodifiable', () {
      final defaults = service.defaults;
      expect(defaults.length, equals(service.allBindings.length));
    });

    test('allBindings includes custom bindings', () {
      final before = service.allBindings.length;
      service.register('custom_action', 'Ctrl+Alt+C');

      final after = service.allBindings;
      expect(after.length, before + 1);
      expect(after['custom_action'], 'Ctrl+Alt+C');
    });

    test('all canvas shortcuts are present', () {
      expect(service.getShortcut('canvas_undo'), 'Ctrl+Z');
      expect(service.getShortcut('canvas_redo'), 'Ctrl+Y');
      expect(service.getShortcut('canvas_delete'), 'Delete');
      expect(service.getShortcut('canvas_select_all'), 'Ctrl+A');
      expect(service.getShortcut('canvas_group'), 'Ctrl+G');
      expect(service.getShortcut('canvas_ungroup'), 'Ctrl+Shift+U');
    });

    test('all scene shortcuts are present', () {
      expect(service.getShortcut('switch_capture'), 'Ctrl+1');
      expect(service.getShortcut('switch_think'), 'Ctrl+2');
      expect(service.getShortcut('switch_connect'), 'Ctrl+3');
      expect(service.getShortcut('connect_canvas'), 'Ctrl+4');
      expect(service.getShortcut('connect_graph'), 'Ctrl+5');
    });

    test('settings shortcut is present', () {
      expect(service.getShortcut('settings'), 'Ctrl+W');
    });

    test('find shortcut is present', () {
      expect(service.getShortcut('find'), 'Ctrl+F');
    });

    test('toggle_preview shortcut is present', () {
      expect(service.getShortcut('toggle_preview'), 'Ctrl+P');
    });
  });
}
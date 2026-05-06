import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/services/shortcut_service.dart';

void main() {
  group('ShortcutService', () {
    late ShortcutService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ShortcutService();
    });

    test('AC-P5-1-1: register and getShortcut', () {
      service.register('new_note', 'Ctrl+N');
      expect(service.getShortcut('new_note'), 'Ctrl+N');
    });

    test('AC-P5-1-2: register conflicting shortcut throws error', () {
      service.register('new_note', 'Ctrl+N');
      expect(
        () => service.register('save', 'Ctrl+N'),
        throwsA(isA<ShortcutConflictError>()),
      );
    });

    test('re-register same action with same shortcut succeeds', () {
      service.register('new_note', 'Ctrl+N');
      expect(
        () => service.register('new_note', 'Ctrl+N'),
        returnsNormally,
      );
    });

    test('AC-P5-1-3: resetToDefaults restores default bindings', () {
      service.register('new_note', 'Ctrl+Shift+N');
      expect(service.getShortcut('new_note'), 'Ctrl+Shift+N');

      service.resetToDefaults();
      expect(service.getShortcut('new_note'), 'Ctrl+N');
    });

    test('defaults are populated', () {
      final defaults = service.defaults;
      expect(defaults.isNotEmpty, true);
      expect(defaults['new_note'], 'Ctrl+N');
      expect(defaults['save'], 'Ctrl+S');
    });

    test('findActionForShortcut returns correct action', () {
      service.register('save', 'Ctrl+S');
      expect(service.findActionForShortcut('Ctrl+S'), 'save');
      expect(service.findActionForShortcut('Ctrl+X'), isNull);
    });

    test('case-insensitive shortcut matching', () {
      service.register('save', 'Ctrl+S');
      expect(service.findActionForShortcut('ctrl+s'), 'save');
    });

    test('allBindings returns all registered shortcuts', () {
      final bindings = service.allBindings;
      expect(bindings.length, greaterThanOrEqualTo(10));
    });

    test('AC-P5-1-4: persist and load restores custom bindings', () async {
      service.register('new_note', 'Ctrl+Shift+N');
      service.register('save', 'Ctrl+Shift+S');
      expect(service.getShortcut('new_note'), 'Ctrl+Shift+N');

      await service.persist();

      final restored = ShortcutService();
      await restored.load();

      expect(restored.getShortcut('new_note'), 'Ctrl+Shift+N');
      expect(restored.getShortcut('save'), 'Ctrl+Shift+S');
      expect(restored.getShortcut('search'), 'Ctrl+K');
    });
  });

  group('Canvas shortcut', () {
    late ShortcutService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ShortcutService();
    });

    test('AC-K-1: toggle_canvas registered with Ctrl+Shift+C', () {
      expect(service.getShortcut('toggle_canvas'), equals('Ctrl+Shift+C'));
    });

    test('AC-K-2: Ctrl+Shift+C does not conflict with existing shortcuts', () {
      for (final entry in service.defaults.entries) {
        if (entry.key == 'toggle_canvas') continue;
        expect(entry.value, isNot(equals('Ctrl+Shift+C')),
            reason: 'toggle_canvas conflicts with ${entry.key}');
      }
    });

    test('AC-K-3: toggle_canvas can be customized', () {
      service.register('toggle_canvas', 'Ctrl+Alt+C');
      expect(service.getShortcut('toggle_canvas'), equals('Ctrl+Alt+C'));
    });
  });
}

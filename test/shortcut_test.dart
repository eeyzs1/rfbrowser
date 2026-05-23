import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/services/shortcut_service.dart';
import 'package:rfbrowser/ui/layout/keyboard_util.dart';

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
      expect(() => service.register('new_note', 'Ctrl+N'), returnsNormally);
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
        expect(
          entry.value,
          isNot(equals('Ctrl+Shift+C')),
          reason: 'toggle_canvas conflicts with ${entry.key}',
        );
      }
    });

    test('AC-K-3: toggle_canvas can be customized', () {
      service.register('toggle_canvas', 'Ctrl+Alt+C');
      expect(service.getShortcut('toggle_canvas'), equals('Ctrl+Alt+C'));
    });
  });

  group('ShortcutService edge cases', () {
    late ShortcutService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ShortcutService();
    });

    test('getShortcut returns null for unknown action', () {
      expect(service.getShortcut('nonexistent_action'), isNull);
    });

    test('ShortcutConflictError contains existing action name', () {
      service.register('new_note', 'Ctrl+N');
      try {
        service.register('save', 'Ctrl+N');
        fail('Should have thrown');
      } on ShortcutConflictError catch (e) {
        expect(e.existingAction, 'new_note');
        expect(e.message, contains('Ctrl+N'));
      }
    });

    test('register with triple modifier combination', () {
      service.register('custom_action', 'Ctrl+Shift+Alt+X');
      expect(service.getShortcut('custom_action'), 'Ctrl+Shift+Alt+X');
    });

    test('register with single key no modifier', () {
      service.register('quick_action', 'F5');
      expect(service.getShortcut('quick_action'), 'F5');
    });

    test('all default shortcuts are unique', () {
      final defaults = service.defaults;
      final values = defaults.values.toList();
      final uniqueValues = values.toSet();
      expect(
        values.length,
        equals(uniqueValues.length),
        reason: 'Default shortcuts must all be unique',
      );
    });

    test('findActionForShortcut is case-insensitive for modifiers', () {
      expect(service.findActionForShortcut('CTRL+N'), 'new_note');
      expect(service.findActionForShortcut('ctrl+n'), 'new_note');
    });

    test('resetToDefaults after multiple customizations', () {
      service.register('new_note', 'Alt+N');
      service.register('save', 'Alt+S');
      service.register('search', 'Alt+K');

      service.resetToDefaults();

      expect(service.getShortcut('new_note'), 'Ctrl+N');
      expect(service.getShortcut('save'), 'Ctrl+S');
      expect(service.getShortcut('search'), 'Ctrl+K');
    });

    test('allBindings is unmodifiable', () {
      final bindings = service.allBindings;
      expect(() => bindings['hack'] = 'Ctrl+H', throwsA(anything));
    });

    test('defaults is unmodifiable', () {
      final defaults = service.defaults;
      expect(() => defaults['hack'] = 'Ctrl+H', throwsA(anything));
    });
  });

  group('ShortcutService + parseShortcut end-to-end', () {
    late ShortcutService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ShortcutService();
    });

    test('user rebinds to Ctrl+Shift+Alt+O and parseShortcut resolves it', () {
      service.register('custom_action', 'Ctrl+Shift+Alt+O');

      final shortcut = service.getShortcut('custom_action');
      expect(shortcut, 'Ctrl+Shift+Alt+O');

      final activator = parseShortcut(shortcut!);
      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.keyO);
      expect(activator.control, isTrue);
      expect(activator.shift, isTrue);
      expect(activator.alt, isTrue);
    });

    test('user rebinds to F2 and parseShortcut resolves it', () {
      service.register('rename', 'F2');

      final shortcut = service.getShortcut('rename');
      expect(shortcut, 'F2');

      final activator = parseShortcut(shortcut!);
      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.f2);
      expect(activator.control, isFalse);
      expect(activator.shift, isFalse);
    });

    test('user rebinds to Ctrl+Shift+U and parseShortcut resolves it', () {
      service.register('canvas_ungroup', 'Ctrl+Shift+U');

      final shortcut = service.getShortcut('canvas_ungroup');
      final activator = parseShortcut(shortcut!);
      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.keyU);
      expect(activator.control, isTrue);
      expect(activator.shift, isTrue);
    });

    test('all default shortcuts parse to valid SingleActivator', () {
      for (final entry in service.defaults.entries) {
        final activator = parseShortcut(entry.value);
        expect(
          activator,
          isNotNull,
          reason:
              'Default shortcut "${entry.value}" for "${entry.key}" must parse to a valid SingleActivator',
        );
      }
    });

    test('persisted custom multi-modifier shortcut survives load', () async {
      service.register('custom1', 'Ctrl+Shift+Alt+F');
      service.register('custom2', 'Ctrl+Shift+P');

      await service.persist();

      final restored = ShortcutService();
      await restored.load();

      expect(restored.getShortcut('custom1'), 'Ctrl+Shift+Alt+F');
      expect(restored.getShortcut('custom2'), 'Ctrl+Shift+P');

      final activator1 = parseShortcut(restored.getShortcut('custom1')!);
      final activator2 = parseShortcut(restored.getShortcut('custom2')!);
      expect(activator1!.trigger, LogicalKeyboardKey.keyF);
      expect(activator1.control, isTrue);
      expect(activator1.shift, isTrue);
      expect(activator1.alt, isTrue);
      expect(activator2!.trigger, LogicalKeyboardKey.keyP);
      expect(activator2.control, isTrue);
      expect(activator2.shift, isTrue);
    });

    test('conflict detection works with multi-modifier shortcuts', () {
      service.register('action_a', 'Ctrl+Shift+K');
      expect(
        () => service.register('action_b', 'Ctrl+Shift+K'),
        throwsA(isA<ShortcutConflictError>()),
      );
    });

    test('same base key different modifiers do not conflict', () {
      service.register('action_a', 'Ctrl+Q');
      expect(
        () => service.register('action_b', 'Ctrl+Shift+Q'),
        returnsNormally,
      );
      expect(() => service.register('action_c', 'Ctrl+Alt+Q'), returnsNormally);
      expect(() => service.register('action_d', 'Alt+Q'), returnsNormally);
    });

    test('rebinding toggle_graph from Ctrl+Shift+G to Alt+G', () {
      expect(service.getShortcut('toggle_graph'), 'Ctrl+Shift+G');

      service.register('toggle_graph', 'Alt+G');
      expect(service.getShortcut('toggle_graph'), 'Alt+G');

      final activator = parseShortcut('Alt+G');
      expect(activator!.trigger, LogicalKeyboardKey.keyG);
      expect(activator.alt, isTrue);
      expect(activator.control, isFalse);
      expect(activator.shift, isFalse);
    });
  });
}

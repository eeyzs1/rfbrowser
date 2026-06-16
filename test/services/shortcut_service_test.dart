import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/shortcut_service.dart';

void main() {
  group('ShortcutService (G11)', () {
    late ShortcutService service;

    setUp(() {
      service = ShortcutService();
    });

    group('AC1: top 5 actions have keyboard shortcuts', () {
      test('search (Ctrl+K), new_note (Ctrl+N), save (Ctrl+S) are bound', () {
        final bindings = service.allBindings;
        expect(bindings['search'], 'Ctrl+K');
        expect(bindings['new_note'], 'Ctrl+N');
        expect(bindings['save'], 'Ctrl+S');
      });

      test('switch_view / scene-switching actions exist (Ctrl+1/2/3)', () {
        final bindings = service.allBindings;
        expect(bindings['switch_capture'], 'Ctrl+1');
        expect(bindings['switch_think'], 'Ctrl+2');
        expect(bindings['switch_connect'], 'Ctrl+3');
      });

      test('daily_note action has a shortcut', () {
        expect(service.allBindings.containsKey('daily_note'), isTrue);
      });

      test('default bindings contain the documented 5+ actions', () {
        // UX-7: Top 5 operations must have shortcuts.
        final required = [
          'search',
          'new_note',
          'save',
          'switch_capture',
          'daily_note',
        ];
        for (final action in required) {
          expect(
            service.allBindings.containsKey(action),
            isTrue,
            reason: 'Missing default binding for $action',
          );
          expect(service.getShortcut(action), isNotNull);
        }
      });

      test('all default bindings are present and non-empty', () {
        expect(service.defaults.length, greaterThanOrEqualTo(22));
        for (final entry in service.defaults.entries) {
          expect(entry.value, isNotEmpty);
        }
      });
    });

    group('AC2: conflict detection', () {
      test('register throws on duplicate shortcut (different action)', () {
        expect(
          () => service.register('foo', 'Ctrl+K'),
          throwsA(isA<ShortcutConflictError>()),
        );
      });

      test('register allows re-binding the SAME action', () {
        expect(() => service.register('search', 'Ctrl+K'), returnsNormally);
        expect(service.getShortcut('search'), 'Ctrl+K');
      });

      test('detectConflicts() returns empty list for clean defaults', () {
        expect(service.detectConflicts(), isEmpty);
      });

      test('detectConflicts() flags two actions sharing a shortcut', () {
        // use forceRegister to set up a conflict state for testing
        service.forceRegister('action_a', 'Ctrl+Shift+X');
        service.forceRegister('action_b', 'Ctrl+Shift+X');

        final conflicts = service.detectConflicts();
        expect(conflicts.length, 1);
        expect(conflicts.first.shortcut, 'ctrl+shift+x');
        // Sorted by action key for determinism.
        expect(conflicts.first.actionA, 'action_a');
        expect(conflicts.first.actionB, 'action_b');
      });

      test(
        'detectConflicts() handles case-insensitive shortcut comparison',
        () {
          service.forceRegister('foo', 'ctrl+shift+y');
          service.forceRegister('bar', 'Ctrl+Shift+Y');

          final conflicts = service.detectConflicts();
          expect(conflicts.length, 1);
          expect(conflicts.first.shortcut, 'ctrl+shift+y');
        },
      );

      test('detectConflicts() lists multiple distinct conflicts', () {
        service.forceRegister('action_a', 'Ctrl+Q');
        service.forceRegister('action_b', 'Ctrl+Q');
        service.forceRegister('action_c', 'Ctrl+R');
        service.forceRegister('action_d', 'Ctrl+R');

        final conflicts = service.detectConflicts();
        expect(conflicts.length, 2);
        final shortcuts = conflicts.map((c) => c.shortcut).toSet();
        expect(shortcuts, contains('ctrl+q'));
        expect(shortcuts, contains('ctrl+r'));
      });

      test('detectConflicts() handles 3+ actions on same shortcut', () {
        service.forceRegister('a1', 'Ctrl+J');
        service.forceRegister('a2', 'Ctrl+J');
        service.forceRegister('a3', 'Ctrl+J');

        // 3 actions → C(3,2) = 3 pairs.
        final conflicts = service.detectConflicts();
        expect(conflicts.length, 3);
      });

      test('resolveConflict by updating one action clears the conflict', () {
        service.forceRegister('a', 'Ctrl+M');
        service.forceRegister('b', 'Ctrl+M');
        expect(service.detectConflicts(), hasLength(1));

        // Use a non-conflicting shortcut that's not in the defaults.
        service.register('b', 'Ctrl+Alt+Shift+F9');
        expect(service.detectConflicts(), isEmpty);
      });
    });

    group('persistence API (load / persist)', () {
      test('resetToDefaults restores all bindings', () {
        service.register('search', 'Ctrl+F2');
        expect(service.getShortcut('search'), 'Ctrl+F2');
        service.resetToDefaults();
        expect(service.getShortcut('search'), 'Ctrl+K');
      });

      test('getShortcut returns null for unknown action', () {
        expect(service.getShortcut('does_not_exist'), isNull);
      });

      test('findActionForShortcut returns null when nothing matches', () {
        expect(service.findActionForShortcut('Ctrl+None'), isNull);
      });

      test('findActionForShortcut returns the bound action', () {
        expect(service.findActionForShortcut('Ctrl+K'), 'search');
      });
    });

    group('ShortcutConflict equality', () {
      test('two equal ShortcutConflict instances compare as equal', () {
        const a = ShortcutConflict(
          shortcut: 'ctrl+x',
          actionA: 'a',
          actionB: 'b',
        );
        const b = ShortcutConflict(
          shortcut: 'ctrl+x',
          actionA: 'a',
          actionB: 'b',
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different fields compare unequal', () {
        const a = ShortcutConflict(
          shortcut: 'ctrl+x',
          actionA: 'a',
          actionB: 'b',
        );
        const b = ShortcutConflict(
          shortcut: 'ctrl+y',
          actionA: 'a',
          actionB: 'b',
        );
        expect(a, isNot(equals(b)));
      });
    });
  });
}

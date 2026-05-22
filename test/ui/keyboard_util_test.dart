import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/ui/layout/keyboard_util.dart';

void main() {
  group('parseShortcut single key', () {
    test('parses single letter key', () {
      final result = parseShortcut('A');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.keyA);
      expect(result.control, isFalse);
      expect(result.shift, isFalse);
      expect(result.alt, isFalse);
      expect(result.meta, isFalse);
    });

    test('parses single digit key', () {
      final result = parseShortcut('5');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.digit5);
    });

    test('parses function key', () {
      final result = parseShortcut('F5');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.f5);
    });

    test('parses special keys', () {
      expect(parseShortcut('Delete')!.trigger, LogicalKeyboardKey.delete);
      expect(parseShortcut('Escape')!.trigger, LogicalKeyboardKey.escape);
      expect(parseShortcut('Enter')!.trigger, LogicalKeyboardKey.enter);
      expect(parseShortcut('Space')!.trigger, LogicalKeyboardKey.space);
      expect(parseShortcut('Tab')!.trigger, LogicalKeyboardKey.tab);
      expect(parseShortcut('Backspace')!.trigger, LogicalKeyboardKey.backspace);
    });

    test('parses arrow keys', () {
      expect(parseShortcut('Up')!.trigger, LogicalKeyboardKey.arrowUp);
      expect(parseShortcut('Down')!.trigger, LogicalKeyboardKey.arrowDown);
      expect(parseShortcut('Left')!.trigger, LogicalKeyboardKey.arrowLeft);
      expect(parseShortcut('Right')!.trigger, LogicalKeyboardKey.arrowRight);
    });
  });

  group('parseShortcut with modifiers', () {
    test('parses Ctrl+letter', () {
      final result = parseShortcut('Ctrl+N');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.keyN);
      expect(result.control, isTrue);
      expect(result.shift, isFalse);
      expect(result.alt, isFalse);
    });

    test('parses Ctrl+Shift+letter', () {
      final result = parseShortcut('Ctrl+Shift+G');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.keyG);
      expect(result.control, isTrue);
      expect(result.shift, isTrue);
      expect(result.alt, isFalse);
    });

    test('parses Ctrl+Alt+letter', () {
      final result = parseShortcut('Ctrl+Alt+C');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.keyC);
      expect(result.control, isTrue);
      expect(result.shift, isFalse);
      expect(result.alt, isTrue);
    });

    test('parses triple modifier Ctrl+Shift+Alt+X', () {
      final result = parseShortcut('Ctrl+Shift+Alt+X');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.keyX);
      expect(result.control, isTrue);
      expect(result.shift, isTrue);
      expect(result.alt, isTrue);
    });

    test('parses Ctrl+digit', () {
      final result = parseShortcut('Ctrl+1');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.digit1);
      expect(result.control, isTrue);
    });

    test('parses Ctrl+function key', () {
      final result = parseShortcut('Ctrl+F12');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.f12);
      expect(result.control, isTrue);
    });

    test('parses Alt+letter', () {
      final result = parseShortcut('Alt+F');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.keyF);
      expect(result.alt, isTrue);
      expect(result.control, isFalse);
    });

    test('parses Shift+letter', () {
      final result = parseShortcut('Shift+Tab');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.tab);
      expect(result.shift, isTrue);
    });
  });

  group('parseShortcut case insensitivity', () {
    test('ctrl is case-insensitive', () {
      final r1 = parseShortcut('Ctrl+N');
      final r2 = parseShortcut('CTRL+N');
      final r3 = parseShortcut('ctrl+n');

      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(r3, isNotNull);
      expect(r1!.control, isTrue);
      expect(r2!.control, isTrue);
      expect(r3!.control, isTrue);
    });

    test('shift is case-insensitive', () {
      final r1 = parseShortcut('Shift+A');
      final r2 = parseShortcut('SHIFT+A');
      expect(r1!.shift, isTrue);
      expect(r2!.shift, isTrue);
    });

    test('alt is case-insensitive', () {
      final r1 = parseShortcut('Alt+X');
      final r2 = parseShortcut('ALT+X');
      expect(r1!.alt, isTrue);
      expect(r2!.alt, isTrue);
    });

    test('meta/cmd aliases', () {
      final r1 = parseShortcut('Meta+K');
      final r2 = parseShortcut('Cmd+K');
      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(r1!.meta, isTrue);
      expect(r2!.meta, isTrue);
    });

    test('control is alias for ctrl', () {
      final r1 = parseShortcut('Control+S');
      expect(r1, isNotNull);
      expect(r1!.control, isTrue);
    });
  });

  group('parseShortcut edge cases', () {
    test('returns null for empty string', () {
      expect(parseShortcut(''), isNull);
    });

    test('returns null for unknown key name', () {
      expect(parseShortcut('Ctrl+Unknown'), isNull);
    });

    test('returns null for modifier-only input', () {
      expect(parseShortcut('Ctrl'), isNull);
      expect(parseShortcut('Ctrl+Shift'), isNull);
      expect(parseShortcut('Ctrl+Shift+Alt'), isNull);
    });

    test('handles extra whitespace around parts', () {
      final result = parseShortcut('Ctrl + N');
      expect(result, isNotNull);
      expect(result!.trigger, LogicalKeyboardKey.keyN);
      expect(result.control, isTrue);
    });

    test('ESC and ESCAPE both map to escape key', () {
      expect(parseShortcut('ESC')!.trigger, LogicalKeyboardKey.escape);
      expect(parseShortcut('ESCAPE')!.trigger, LogicalKeyboardKey.escape);
    });

    test('RETURN maps to enter key', () {
      expect(parseShortcut('RETURN')!.trigger, LogicalKeyboardKey.enter);
    });
  });

  group('parseShortcut all default shortcuts', () {
    final defaultShortcuts = {
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
    };

    for (final entry in defaultShortcuts.entries) {
      test('${entry.key}: ${entry.value} parses successfully', () {
        final result = parseShortcut(entry.value);
        expect(result, isNotNull,
            reason:
                'Default shortcut "${entry.value}" for "${entry.key}" must parse to a valid SingleActivator');
      });
    }
  });
}

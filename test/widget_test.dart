import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/services/shortcut_service.dart';

void main() {
  group('Note fromMarkdown YAML parsing', () {
    test('parses simple frontmatter with title', () {
      const md = '''---
title: My Note
tags: [tag1, tag2]
---
# Content here
''';
      final note = Note.fromMarkdown('test.md', md);
      expect(note.title, 'My Note');
      expect(note.tags, ['tag1', 'tag2']);
      expect(note.content, '# Content here');
    });

    test('parses nested frontmatter values', () {
      const md = '''---
title: Deep Note
tags:
  - nested1
  - nested2
aliases:
  - alias1
  - alias2
source: https://example.com
custom_field:
  key: value
  count: 42
---
Body text
''';
      final note = Note.fromMarkdown('test.md', md);
      expect(note.title, 'Deep Note');
      expect(note.tags, ['nested1', 'nested2']);
      expect(note.aliases, ['alias1', 'alias2']);
      expect(note.sourceUrl, 'https://example.com');
      expect(note.frontMatter.containsKey('custom_field'), true);
      expect(note.content, 'Body text');
    });

    test('falls back to first heading when no title in frontmatter', () {
      const md = '''---
tags: [test]
---
# Fallback Title

Content
''';
      final note = Note.fromMarkdown('test.md', md);
      expect(note.title, 'Fallback Title');
      expect(note.tags, ['test']);
    });

    test('handles empty frontmatter gracefully', () {
      const md = '''---
---
# Just Content
''';
      final note = Note.fromMarkdown('test.md', md);
      expect(note.content, '# Just Content');
      expect(note.frontMatter, isEmpty);
    });

    test('handles no frontmatter', () {
      const md = '# Simple Note\n\nJust text.';
      final note = Note.fromMarkdown('test.md', md);
      expect(note.title, 'Simple Note');
      expect(note.content, '# Simple Note\n\nJust text.');
    });

    test('handles malformed YAML gracefully', () {
      const md = '''---
title: "unclosed
broken: [a, b
---
Content
''';
      final note = Note.fromMarkdown('test.md', md);
      expect(note.content, 'Content');
    });

    test('toMarkdown round-trips correctly', () {
      final note = Note(
        title: 'Round Trip',
        filePath: 'round.md',
        content: 'Hello world',
        tags: ['test', 'demo'],
        sourceUrl: 'https://example.com',
      );
      final md = note.toMarkdown();
      expect(md.contains('title: "Round Trip"'), true);
      expect(md.contains('tags: [test, demo]'), true);
      expect(md.contains('source: https://example.com'), true);
      expect(md.contains('Hello world'), true);
    });
  });

  group('ShortcutService', () {
    test('has default bindings for all core actions', () {
      final service = ShortcutService();
      expect(service.getShortcut('new_note'), 'Ctrl+N');
      expect(service.getShortcut('save'), 'Ctrl+S');
      expect(service.getShortcut('search'), 'Ctrl+K');
      expect(service.getShortcut('toggle_editor'), 'Ctrl+E');
      expect(service.getShortcut('toggle_browser'), 'Ctrl+B');
      expect(service.getShortcut('toggle_graph'), 'Ctrl+Shift+G');
      expect(service.getShortcut('daily_note'), 'Ctrl+D');
      expect(service.getShortcut('toggle_preview'), 'Ctrl+P');
      expect(service.getShortcut('settings'), 'Ctrl+W');
      expect(service.getShortcut('find'), 'Ctrl+F');
    });

    test('registers custom shortcut and finds by action', () {
      final service = ShortcutService();
      service.register('new_note', 'Ctrl+Shift+N');
      expect(service.getShortcut('new_note'), 'Ctrl+Shift+N');
    });

    test('throws when registering conflicting shortcut', () {
      final service = ShortcutService();
      service.register('new_note', 'Ctrl+X');
      expect(
        () => service.register('daily_note', 'Ctrl+X'),
        throwsA(isA<ShortcutConflictError>()),
      );
    });

    test('resetToDefaults restores original bindings', () {
      final service = ShortcutService();
      service.register('new_note', 'Ctrl+Shift+N');
      service.resetToDefaults();
      expect(service.getShortcut('new_note'), 'Ctrl+N');
    });
  });
}

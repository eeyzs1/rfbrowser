import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/repositories/note_repository.dart';

void main() {
  group('NoteRepository', () {
    late String tempDir;
    late NoteRepository repo;

    setUp(() {
      tempDir = p.join(
        Directory.systemTemp.path,
        'rfbrowser_test_repo_${DateTime.now().millisecondsSinceEpoch}',
      );
      Directory(tempDir).createSync(recursive: true);
      repo = NoteRepository(tempDir);
    });

    tearDown(() {
      if (Directory(tempDir).existsSync()) {
        Directory(tempDir).deleteSync(recursive: true);
      }
    });

    group('_validatePath', () {
      test('accepts valid relative path', () {
        expect(() => repo.validatePath('subdir/note.md'), returnsNormally);
      });

      test('throws on path traversal with ..', () {
        expect(
          () => repo.validatePath('../outside.md'),
          throwsA(isA<PathTraversalException>()),
        );
      });

      test('throws on absolute path outside vault', () {
        if (Platform.isWindows) {
          expect(
            () => repo.validatePath('C:\\outside\\note.md'),
            throwsA(isA<PathTraversalException>()),
          );
        }
      });
    });

    group('_normalizeRelativePath', () {
      test('normalizes dot paths', () {
        expect(repo.normalizeRelativePath('.'), '');
        expect(repo.normalizeRelativePath('./'), '');
      });

      test('normalizes double-dot paths', () {
        expect(repo.normalizeRelativePath('subdir/../file.md'), 'file.md');
      });

      test('throws on path traversal', () {
        expect(
          () => repo.normalizeRelativePath('..'),
          throwsA(isA<PathTraversalException>()),
        );
      });

      test('throws on absolute path', () {
        if (Platform.isWindows) {
          expect(
            () => repo.normalizeRelativePath('C:\\file.md'),
            throwsA(isA<PathTraversalException>()),
          );
        }
      });
    });

    group('_sanitizeFileName', () {
      test('replaces illegal characters with underscore', () {
        expect(repo.sanitizeFileName('test<file>.md'), 'test_file_.md');
        expect(repo.sanitizeFileName('a:b*?"file'), 'a_b___file');
      });

      test('replaces whitespace with dash', () {
        expect(repo.sanitizeFileName('my note title'), 'my-note-title');
      });

      test('handles empty or dot names', () {
        expect(repo.sanitizeFileName(''), 'untitled');
        expect(repo.sanitizeFileName('.'), 'untitled');
      });

      test('truncates long names', () {
        final long = 'a' * 150;
        expect(repo.sanitizeFileName(long).length, 100);
      });
    });

    group('createNote', () {
      test('creates note file with correct content', () async {
        final note = await repo.createNote(title: 'Test Note');
        expect(note.title, 'Test Note');
        expect(note.filePath, 'Test-Note.md');

        final file = File(p.join(tempDir, 'Test-Note.md'));
        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        expect(content, contains('# Test Note'));
      });

      test('creates note in subfolder', () async {
        final note = await repo.createNote(title: 'Sub Note', folder: 'subdir');
        expect(note.filePath, p.join('subdir', 'Sub-Note.md'));
        expect(Directory(p.join(tempDir, 'subdir')).existsSync(), isTrue);
        expect(
          File(p.join(tempDir, 'subdir', 'Sub-Note.md')).existsSync(),
          isTrue,
        );
      });
    });

    group('getNoteByPath', () {
      test('returns note for existing file', () async {
        await repo.createNote(title: 'Hello World');
        final loaded = await repo.getNoteByPath('Hello-World.md');
        expect(loaded, isNotNull);
        expect(loaded!.title, 'Hello World');
      });

      test('returns null for missing file', () async {
        final loaded = await repo.getNoteByPath('nonexistent.md');
        expect(loaded, isNull);
      });
    });

    group('saveNote', () {
      test('updates existing note file', () async {
        final note = await repo.createNote(title: 'Original');
        final updated = note.copyWith(title: 'Updated');
        await repo.saveNote(updated);

        final loaded = await repo.getNoteByPath(note.filePath);
        expect(loaded!.title, 'Updated');
      });
    });

    group('deleteNote', () {
      test('deletes note file', () async {
        final note = await repo.createNote(title: 'ToDelete');
        await repo.deleteNote(note.filePath);
        expect(File(p.join(tempDir, note.filePath)).existsSync(), isFalse);
      });

      test('handles deleting non-existent file gracefully', () async {
        await repo.deleteNote('nonexistent.md');
      });
    });

    group('createDailyNote', () {
      test('creates daily note with correct path', () async {
        final date = DateTime(2024, 6, 15);
        final note = await repo.createDailyNote(date);
        final expectedPath = p.join('daily-notes', '2024-06-15.md');
        expect(note.filePath, expectedPath);
        expect(note.tags, contains('daily-note'));
        expect(File(p.join(tempDir, expectedPath)).existsSync(), isTrue);
      });

      test('returns existing daily note without recreating', () async {
        final date = DateTime(2024, 6, 15);
        final first = await repo.createDailyNote(date);
        final second = await repo.createDailyNote(date);
        expect(second.filePath, first.filePath);
      });
    });

    group('clipToNote', () {
      test('creates clipping note', () async {
        final note = await repo.clipToNote(
          url: 'https://example.com',
          title: 'Example Page',
          content: 'page content',
          selectedText: 'selected text',
        );
        expect(note.sourceUrl, 'https://example.com');
        expect(note.tags, contains('clipping'));
        expect(note.filePath, contains('clippings'));
        expect(note.filePath, contains('Example-Page'));

        final file = File(p.join(tempDir, note.filePath));
        final content = await file.readAsString();
        expect(content, contains('# Example Page'));
        expect(content, contains('page content'));
        expect(content, contains('selected text'));
      });
    });

    group('getAllNotes', () {
      test('returns all markdown notes in vault', () async {
        await repo.createNote(title: 'Note One');
        await repo.createNote(title: 'Note Two');

        final all = await repo.getAllNotes();
        expect(all.length, 2);
        expect(all.any((n) => n.title == 'Note One'), isTrue);
        expect(all.any((n) => n.title == 'Note Two'), isTrue);
      });

      test('returns empty list for empty vault', () async {
        final all = await repo.getAllNotes();
        expect(all, isEmpty);
      });
    });

    group('integration', () {
      test('full CRUD lifecycle', () async {
        await repo.createNote(title: 'Lifecycle');
        expect(File(p.join(tempDir, 'Lifecycle.md')).existsSync(), isTrue);

        final loaded = await repo.getNoteByPath('Lifecycle.md');
        expect(loaded!.title, 'Lifecycle');

        await repo.saveNote(loaded.copyWith(title: 'Updated'));
        final afterSave = await repo.getNoteByPath('Lifecycle.md');
        expect(afterSave!.title, 'Updated');

        await repo.deleteNote('Lifecycle.md');
        expect(File(p.join(tempDir, 'Lifecycle.md')).existsSync(), isFalse);
      });
    });
  });
}

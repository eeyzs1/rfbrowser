import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/context/content_extractor.dart';
import 'package:rfbrowser/core/context/reference_parser.dart';
import 'package:rfbrowser/data/models/context_assembly.dart';
import 'package:rfbrowser/data/models/note.dart';

void main() {
  late List<Note> testNotes;

  setUp(() {
    testNotes = [
      Note(
        id: 'note-1',
        title: 'Getting Started',
        filePath: 'getting-started.md',
        content:
            '# Getting Started\n\nWelcome to the project.\n\n## Setup\n\nInstall dependencies.\n\n## Usage\n\nRun the app.\n\n## Advanced\n\nMore details here.',
      ),
      Note(
        id: 'note-2',
        title: 'API Reference',
        filePath: 'api.md',
        content: '# API Reference\n\nEndpoint list.',
        aliases: const ['api-docs'],
      ),
    ];
  });

  group('NoteContentSource', () {
    test('resolves note by exact title', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'Getting Started',
        position: 0,
        rawText: '@note:Getting Started',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.type, ContextType.note);
      expect(result.id, 'note-1');
      expect(result.content, startsWith('# Getting Started'));
      expect(result.metadata['title'], 'Getting Started');
      expect(result.metadata['filePath'], 'getting-started.md');
    });

    test('resolves note by case-insensitive title match', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'getting started',
        position: 0,
        rawText: '@note:getting started',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.id, 'note-1');
    });

    test('resolves note by alias', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'api-docs',
        position: 0,
        rawText: '@note:api-docs',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.id, 'note-2');
      expect(result.content, startsWith('# API Reference'));
    });

    test('resolves note by case-insensitive alias', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'API-DOCS',
        position: 0,
        rawText: '@note:API-DOCS',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.id, 'note-2');
    });

    test('returns error item when note not found', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'NonExistent',
        position: 0,
        rawText: '@note:NonExistent',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, '');
      expect(result.metadata['error'], 'not_found');
    });

    test('returns null when ref type is not note', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.web,
        target: 'something',
        position: 0,
        rawText: '@web:something',
      );
      final result = await source.resolve(ref);
      expect(result, isNull);
    });

    test('returns error when no current note for "current"', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'current',
        position: 0,
        rawText: '@note:current',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, '');
      expect(result.metadata['error'], 'no_active_note');
    });

    test('resolves current note when currentNote provided', () async {
      final currentNote = Note(
        id: 'current-1',
        title: 'Current Note',
        filePath: 'current.md',
        content: '# Current Note\n\nThis is the current note.',
      );
      final source = NoteContentSource(testNotes, currentNote: currentNote);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'current',
        position: 0,
        rawText: '@note:current',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.type, ContextType.note);
      expect(result.id, 'current-1');
      expect(result.content, startsWith('# Current Note'));
      expect(result.metadata['title'], 'Current Note');
      expect(result.metadata['filePath'], 'current.md');
    });

    test('resolves current note section with selector', () async {
      final currentNote = Note(
        id: 'current-1',
        title: 'Current Note',
        filePath: 'current.md',
        content:
            '# Current Note\n\nintro\n\n## Setup\n\nInstall dependencies.\n\n## Usage\n\nRun the app.',
      );
      final source = NoteContentSource(testNotes, currentNote: currentNote);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'current',
        selector: 'Setup',
        position: 0,
        rawText: '@note:current#Setup',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.id, 'current-1');
      expect(result.content, 'Install dependencies.');
    });

    test('extracts section by heading selector', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'Getting Started',
        selector: 'Setup',
        position: 0,
        rawText: '@note:Getting Started#Setup',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, 'Install dependencies.');
    });

    test('returns full content when section not found', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'Getting Started',
        selector: 'NonExistentSection',
        position: 0,
        rawText: '@note:Getting Started#NonExistentSection',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, startsWith('# Getting Started'));
    });

    test('extracts section with case-insensitive heading match', () async {
      final source = NoteContentSource(testNotes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'Getting Started',
        selector: 'SETUP',
        position: 0,
        rawText: '@note:Getting Started#SETUP',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, 'Install dependencies.');
    });

    test(
      'stops at same-level or higher heading when extracting section',
      () async {
        final notes = [
          Note(
            id: 'n1',
            title: 'Doc',
            filePath: 'doc.md',
            content:
                '# Doc\n\nintro\n\n## Section A\n\ncontent A\n\n### Sub A1\n\nsub content\n\n## Section B\n\ncontent B',
          ),
        ];
        final source = NoteContentSource(notes);
        final ref = ParsedReference(
          type: ContextRefType.note,
          target: 'Doc',
          selector: 'Section A',
          position: 0,
          rawText: '@note:Doc#Section A',
        );
        final result = await source.resolve(ref);
        expect(result, isNotNull);
        expect(result!.content, contains('content A'));
        expect(result.content, contains('sub content'));
        expect(result.content, isNot(contains('Section B')));
      },
    );
  });

  group('WebContentSource', () {
    test('resolves current web page', () async {
      final source = WebContentSource(
        currentUrl: 'https://example.com',
        currentTitle: 'Example',
        currentContent: '<html>content</html>',
      );
      final ref = ParsedReference(
        type: ContextRefType.web,
        target: 'current',
        position: 0,
        rawText: '@web:current',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.type, ContextType.webPage);
      expect(result.id, 'https://example.com');
      expect(result.content, '<html>content</html>');
      expect(result.metadata['title'], 'Example');
    });

    test('returns error when no active page for "current"', () async {
      final source = WebContentSource();
      final ref = ParsedReference(
        type: ContextRefType.web,
        target: 'current',
        position: 0,
        rawText: '@web:current',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, '');
      expect(result.metadata['error'], 'no_active_page');
    });

    test('returns error when currentContent is empty', () async {
      final source = WebContentSource(currentContent: '');
      final ref = ParsedReference(
        type: ContextRefType.web,
        target: 'current',
        position: 0,
        rawText: '@web:current',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.metadata['error'], 'no_active_page');
    });

    test('returns not_found for specific web refs', () async {
      final source = WebContentSource();
      final ref = ParsedReference(
        type: ContextRefType.web,
        target: 'https://other.com',
        position: 0,
        rawText: '@web:https://other.com',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, '');
      expect(result.metadata['error'], 'not_found');
    });

    test('returns null when ref type is not web', () async {
      final source = WebContentSource();
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'something',
        position: 0,
        rawText: '@note:something',
      );
      final result = await source.resolve(ref);
      expect(result, isNull);
    });

    test('uses "current" as id when currentUrl is null', () async {
      final source = WebContentSource(currentContent: 'body');
      final ref = ParsedReference(
        type: ContextRefType.web,
        target: 'current',
        position: 0,
        rawText: '@web:current',
      );
      final result = await source.resolve(ref);
      expect(result!.id, 'current');
    });
  });

  group('ClipContentSource', () {
    test('resolves clip by id', () async {
      final source = ClipContentSource(clips: {'my-clip': 'clipped content'});
      final ref = ParsedReference(
        type: ContextRefType.clip,
        target: 'my-clip',
        position: 0,
        rawText: '@clip:my-clip',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, 'clipped content');
      expect(result.metadata['source'], 'clip');
    });

    test('returns error for missing clip', () async {
      final source = ClipContentSource();
      final ref = ParsedReference(
        type: ContextRefType.clip,
        target: 'missing',
        position: 0,
        rawText: '@clip:missing',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, '');
      expect(result.metadata['error'], 'not_found');
    });

    test('returns null when ref type is not clip', () async {
      final source = ClipContentSource();
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'something',
        position: 0,
        rawText: '@note:something',
      );
      final result = await source.resolve(ref);
      expect(result, isNull);
    });
  });

  group('AgentResultContentSource', () {
    test('resolves agent result by id', () async {
      final source = AgentResultContentSource(
        agentResults: {'task-1': 'agent response'},
      );
      final ref = ParsedReference(
        type: ContextRefType.agent,
        target: 'task-1',
        position: 0,
        rawText: '@agent:task-1',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.type, ContextType.agentResult);
      expect(result.content, 'agent response');
      expect(result.metadata['source'], 'agent');
    });

    test('returns error for missing agent result', () async {
      final source = AgentResultContentSource();
      final ref = ParsedReference(
        type: ContextRefType.agent,
        target: 'missing',
        position: 0,
        rawText: '@agent:missing',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, '');
      expect(result.metadata['error'], 'not_found');
    });

    test('returns null when ref type is not agent', () async {
      final source = AgentResultContentSource();
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'something',
        position: 0,
        rawText: '@note:something',
      );
      final result = await source.resolve(ref);
      expect(result, isNull);
    });
  });

  group('FileContentSource', () {
    test('resolves file by path', () async {
      final source = FileContentSource(
        files: {'/path/to/file.txt': 'file content'},
      );
      final ref = ParsedReference(
        type: ContextRefType.file,
        target: '/path/to/file.txt',
        position: 0,
        rawText: '@file:/path/to/file.txt',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.type, ContextType.file);
      expect(result.content, 'file content');
      expect(result.metadata['source'], 'file');
      expect(result.metadata['path'], '/path/to/file.txt');
    });

    test('returns error for missing file', () async {
      final source = FileContentSource();
      final ref = ParsedReference(
        type: ContextRefType.file,
        target: '/nonexistent.txt',
        position: 0,
        rawText: '@file:/nonexistent.txt',
      );
      final result = await source.resolve(ref);
      expect(result, isNotNull);
      expect(result!.content, '');
      expect(result.metadata['error'], 'not_found');
    });

    test('returns null when ref type is not file', () async {
      final source = FileContentSource();
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'something',
        position: 0,
        rawText: '@note:something',
      );
      final result = await source.resolve(ref);
      expect(result, isNull);
    });
  });
}

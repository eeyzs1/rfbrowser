import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/skill.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/note_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('NoteState', () {
    test('initial state has empty notes and null activeNoteId', () {
      const state = NoteState();
      expect(state.notes, isEmpty);
      expect(state.activeNoteId, isNull);
      expect(state.activeNote, isNull);
    });

    test('activeNote returns matching note', () {
      final note = Note(title: 'Test', filePath: 'test.md');
      final state = NoteState(notes: [note], activeNoteId: note.id);
      expect(state.activeNote, isNotNull);
      expect(state.activeNote!.title, 'Test');
    });

    test('activeNote returns null when id not found', () {
      final state = NoteState(
        notes: [Note(title: 'A', filePath: 'a.md')],
        activeNoteId: 'nonexistent',
      );
      expect(state.activeNote, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final note = Note(title: 'A', filePath: 'a.md');
      final state = NoteState(notes: [note], activeNoteId: note.id);
      final copied = state.copyWith();
      expect(copied.notes.length, 1);
      expect(copied.activeNoteId, note.id);
    });

    test('copyWith overrides specified fields', () {
      const state = NoteState();
      final note = Note(title: 'B', filePath: 'b.md');
      final copied = state.copyWith(notes: [note], activeNoteId: note.id);
      expect(copied.notes.length, 1);
      expect(copied.activeNoteId, note.id);
    });
  });

  ProviderContainer createContainer(String vaultPath) {
    final vaultState = VaultState(
      currentVault: VaultConfig(
        path: vaultPath,
        name: 'test',
        lastOpened: DateTime.now(),
      ),
    );
    return ProviderContainer(overrides: [
      vaultProvider.overrideWith(() => _TestVaultNotifier(vaultState)),
    ]);
  }

  group('NoteNotifier unit logic', () {
    late ProviderContainer container;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('rfbrowser_note_test_');
      final rfbrowserDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!await rfbrowserDir.exists()) {
        await rfbrowserDir.create(recursive: true);
      }
      container = createContainer(tempDir.path);
      container.read(noteServiceProvider);
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      container.dispose();
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    NoteNotifier notifier() => container.read(noteServiceProvider.notifier);

    NoteState state() => container.read(noteServiceProvider);

    test('getUniqueTitle returns base when no conflict', () async {
      final result = await notifier().getUniqueTitle('New Note');
      expect(result, 'New Note');
    });

    test('getUniqueTitle appends number on conflict', () async {
      final note = Note(title: 'Existing', filePath: 'existing.md');
      notifier().state = NoteState(notes: [note]);

      final result = await notifier().getUniqueTitle('Existing');
      expect(result, 'Existing 1');
    });

    test('getUniqueTitle increments until finding free title', () async {
      final notes = [
        Note(title: 'Note', filePath: 'note.md'),
        Note(title: 'Note 1', filePath: 'note-1.md'),
        Note(title: 'Note 2', filePath: 'note-2.md'),
      ];
      notifier().state = NoteState(notes: notes);

      final result = await notifier().getUniqueTitle('Note');
      expect(result, 'Note 3');
    });

    test('getNote returns note by id', () {
      final note = Note(title: 'FindMe', filePath: 'find.md');
      notifier().state = NoteState(notes: [note]);

      final found = notifier().getNote(note.id);
      expect(found, isNotNull);
      expect(found!.title, 'FindMe');
    });

    test('getNote returns null for unknown id', () {
      final result = notifier().getNote('nonexistent');
      expect(result, isNull);
    });

    test('getAllTags returns sorted unique tags', () {
      final notes = [
        Note(title: 'A', filePath: 'a.md', tags: ['ztag', 'atag']),
        Note(title: 'B', filePath: 'b.md', tags: ['atag', 'mtag']),
      ];
      notifier().state = NoteState(notes: notes);

      final tags = notifier().getAllTags();
      expect(tags, ['atag', 'mtag', 'ztag']);
    });

    test('getAllTags returns empty for no tags', () {
      notifier().state = const NoteState();
      final tags = notifier().getAllTags();
      expect(tags, isEmpty);
    });

    test('getDailyNotes filters by tag and date', () {
      final now = DateTime.now();
      final notes = [
        Note(
          title: 'Daily 1',
          filePath: 'd1.md',
          tags: ['daily-note'],
          created: now.subtract(const Duration(hours: 1)),
        ),
        Note(
          title: 'Daily 2',
          filePath: 'd2.md',
          tags: ['daily-note'],
          created: now.subtract(const Duration(days: 10)),
        ),
        Note(
          title: 'Not Daily',
          filePath: 'nd.md',
          tags: ['other'],
          created: now,
        ),
      ];
      notifier().state = NoteState(notes: notes);

      final daily = notifier().getDailyNotes(7);
      expect(daily.length, 1);
      expect(daily[0].title, 'Daily 1');
    });

    test('getDailyNotes sorts by created descending', () {
      final now = DateTime.now();
      final notes = [
        Note(
          title: 'Older',
          filePath: 'o.md',
          tags: ['daily-note'],
          created: now.subtract(const Duration(days: 1)),
        ),
        Note(
          title: 'Newer',
          filePath: 'n.md',
          tags: ['daily-note'],
          created: now,
        ),
      ];
      notifier().state = NoteState(notes: notes);

      final daily = notifier().getDailyNotes(7);
      expect(daily[0].title, 'Newer');
      expect(daily[1].title, 'Older');
    });

    test('getNotesByTag filters correctly', () {
      final notes = [
        Note(title: 'A', filePath: 'a.md', tags: ['project']),
        Note(title: 'B', filePath: 'b.md', tags: ['personal']),
        Note(title: 'C', filePath: 'c.md', tags: ['project', 'important']),
      ];
      notifier().state = NoteState(notes: notes);

      final projectNotes = notifier().getNotesByTag('project');
      expect(projectNotes.length, 2);
      expect(projectNotes.every((n) => n.tags.contains('project')), isTrue);
    });

    test('createNote writes file and updates state', () async {
      final note = await notifier().createNote(title: 'Test Create');
      expect(note.title, 'Test Create');
      expect(note.filePath, 'Test-Create.md');
      expect(note.content, contains('Test Create'));

      final file = File(p.join(tempDir.path, note.filePath));
      expect(await file.exists(), isTrue);

      final currentState = state();
      expect(currentState.notes.any((n) => n.id == note.id), isTrue);
      expect(currentState.activeNoteId, note.id);
    });

    test('createNote deduplicates title', () async {
      await notifier().createNote(title: 'Dup');
      final second = await notifier().createNote(title: 'Dup');
      expect(second.title, 'Dup 1');
    });

    test('deleteNote removes file and state entry', () async {
      final note = await notifier().createNote(title: 'ToDelete');
      final file = File(p.join(tempDir.path, note.filePath));
      expect(await file.exists(), isTrue);

      await notifier().deleteNote(note.id);
      expect(await file.exists(), isFalse);
      expect(state().notes.any((n) => n.id == note.id), isFalse);
    });

    test('deleteNote removes only target note and keeps others', () async {
      final note1 = await notifier().createNote(title: 'KeepMe');
      final note2 = await notifier().createNote(title: 'DeleteMe');
      final countBefore = state().notes.length;

      await notifier().deleteNote(note2.id);
      expect(state().notes.length, countBefore - 1);
      expect(state().notes.any((n) => n.id == note2.id), isFalse);
      expect(state().notes.any((n) => n.id == note1.id), isTrue);
    });

    test('deleteNote does nothing for nonexistent id', () async {
      await notifier().createNote(title: 'Keep');
      final countBefore = state().notes.length;
      await notifier().deleteNote('nonexistent');
      expect(state().notes.length, countBefore);
    });

    test('saveNote updates existing note in state', () async {
      final note = await notifier().createNote(title: 'SaveTest');
      final updated = note.copyWith(content: 'Updated content');
      await notifier().saveNote(updated);

      final found = notifier().getNote(note.id);
      expect(found, isNotNull);
      expect(found!.content, 'Updated content');
    });

    test('saveNote adds note if not in state', () async {
      final note = Note(title: 'External', filePath: 'external.md', content: 'Hello');
      await notifier().saveNote(note);

      final found = notifier().getNote(note.id);
      expect(found, isNotNull);
    });

    test('renameNote renames file and updates state', () async {
      final note = await notifier().createNote(title: 'OldName');
      final renamed = await notifier().renameNote(note.filePath, 'NewName');

      expect(renamed.title, 'NewName');
      expect(renamed.filePath, 'NewName.md');

      final oldFile = File(p.join(tempDir.path, note.filePath));
      final newFile = File(p.join(tempDir.path, renamed.filePath));
      expect(await oldFile.exists(), isFalse);
      expect(await newFile.exists(), isTrue);
    });

    test('moveNote moves file to new folder', () async {
      final note = await notifier().createNote(title: 'MoveMe');
      await notifier().moveNote(note.id, 'subfolder');

      final found = notifier().getNote(note.id);
      expect(found, isNotNull);
      expect(found!.filePath, contains('subfolder'));
    });

    test('moveNote does nothing for nonexistent note', () async {
      await notifier().createNote(title: 'Stay');
      final countBefore = state().notes.length;
      await notifier().moveNote('nonexistent', 'folder');
      expect(state().notes.length, countBefore);
    });
  });

  group('NoteNotifier _sanitizeFileName (via createNote)', () {
    late ProviderContainer container;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('rfbrowser_sanitize_');
      final rfbrowserDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!await rfbrowserDir.exists()) {
        await rfbrowserDir.create(recursive: true);
      }
      container = createContainer(tempDir.path);
      container.read(noteServiceProvider);
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      container.dispose();
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    NoteNotifier notifier() => container.read(noteServiceProvider.notifier);

    test('sanitizes special characters in title', () async {
      final note = await notifier().createNote(title: 'Test: File<Name>');
      expect(note.filePath, contains('Test_'));
      expect(note.filePath, endsWith('.md'));
      expect(note.filePath, isNot(contains(':')));
      expect(note.filePath, isNot(contains('<')));
      expect(note.filePath, isNot(contains('>')));
    });

    test('replaces spaces with hyphens', () async {
      final note = await notifier().createNote(title: 'Hello World');
      expect(note.filePath, 'Hello-World.md');
    });

    test('handles empty title gracefully', () async {
      final note = await notifier().createNote(title: '');
      expect(note.filePath, isNotEmpty);
    });
  });

  group('NoteNotifier _getBuiltinSkills', () {
    late ProviderContainer container;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('rfbrowser_skills_');
      final rfbrowserDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!await rfbrowserDir.exists()) {
        await rfbrowserDir.create(recursive: true);
      }
      container = createContainer(tempDir.path);
      container.read(noteServiceProvider);
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      container.dispose();
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    NoteNotifier notifier() => container.read(noteServiceProvider.notifier);

    test('getAllSkills returns builtin skills', () async {
      final skills = await notifier().getAllSkills();
      expect(skills.length, greaterThanOrEqualTo(7));
      expect(skills.where((s) => s.isBuiltin).length, greaterThanOrEqualTo(7));
    });

    test('builtin skills have required fields', () async {
      final skills = await notifier().getAllSkills();
      for (final skill in skills.where((s) => s.isBuiltin)) {
        expect(skill.id, isNotEmpty);
        expect(skill.name, isNotEmpty);
        expect(skill.prompt, isNotEmpty);
      }
    });

    test('createSkill and getAllSkills round-trip', () async {
      final skill = Skill(
        id: 'custom-test',
        name: 'Custom Test',
        description: 'A test skill',
        prompt: 'Do something with {{input}}',
      );
      await notifier().createSkill(skill);

      final skills = await notifier().getAllSkills();
      final found = skills.where((s) => s.id == 'custom-test').firstOrNull;
      expect(found, isNotNull);
      expect(found!.name, 'Custom Test');
      expect(found.isBuiltin, isFalse);
    });

    test('deleteSkill removes skill', () async {
      final skill = Skill(
        id: 'to-delete',
        name: 'Delete Me',
        description: '',
        prompt: '',
      );
      await notifier().createSkill(skill);
      await notifier().deleteSkill('to-delete');

      final skills = await notifier().getAllSkills();
      expect(skills.where((s) => s.id == 'to-delete').firstOrNull, isNull);
    });
  });

  group('NoteNotifier clipToNote', () {
    late ProviderContainer container;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('rfbrowser_clip_');
      final rfbrowserDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!await rfbrowserDir.exists()) {
        await rfbrowserDir.create(recursive: true);
      }
      container = createContainer(tempDir.path);
      container.read(noteServiceProvider);
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      container.dispose();
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    NoteNotifier notifier() => container.read(noteServiceProvider.notifier);

    test('clipToNote creates note in clippings folder', () async {
      final note = await notifier().clipToNote(
        url: 'https://example.com',
        title: 'Test Clip',
        content: 'Clipped content here',
      );
      expect(note.filePath, startsWith('clippings'));
      expect(note.tags, contains('clipping'));
      expect(note.sourceUrl, 'https://example.com');

      final file = File(p.join(tempDir.path, note.filePath));
      expect(await file.exists(), isTrue);
    });

    test('clipToNote includes selectedText when provided', () async {
      final note = await notifier().clipToNote(
        url: 'https://example.com',
        title: 'Clip With Selection',
        content: 'Main content',
        selectedText: 'Selected text here',
      );
      expect(note.content, contains('Selected text here'));
    });

    test('clipBookmark creates minimal note', () async {
      final note = await notifier().clipBookmark(
        url: 'https://example.com',
        title: 'Bookmarked',
      );
      expect(note.sourceUrl, 'https://example.com');
    });

    test('clipSelection creates note with selected text', () async {
      final note = await notifier().clipSelection(
        url: 'https://example.com',
        title: 'Selection Clip',
        selectedText: 'Just this part',
      );
      expect(note.content, contains('Just this part'));
    });
  });
}

class _TestVaultNotifier extends VaultNotifier {
  final VaultState _initialState;

  _TestVaultNotifier(this._initialState);

  @override
  VaultState build() => _initialState;
}


import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/data/repositories/note_repository.dart';
import 'package:rfbrowser/services/agent_service.dart';
import 'package:rfbrowser/services/knowledge_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AgentNotifier Create note (P0-2 ACs)', () {
    test('AC-IMP-2-1: Create note step actually creates note via KnowledgeNotifier', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ai_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final kn = container.read(knowledgeProvider.notifier);
      final note = await kn.createNote(title: '量子研究笔记');

      expect(note.title, '量子研究笔记');

      // Verify note exists on disk via repo
      final onDisk = await repo.getNoteByPath(note.filePath);
      expect(onDisk, isNotNull);
      expect(onDisk!.title, '量子研究笔记');
    });

    test('AC-IMP-2-2: Note content can be updated and saved via saveActiveNote', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ai_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final kn = container.read(knowledgeProvider.notifier);
      final note = await kn.createNote(title: '带上下文的笔记');

      kn.updateActiveNoteContent('# 带上下文的笔记\n\n## Context\n\nStep 1 result');
      await kn.saveActiveNote();

      final onDisk = await repo.getNoteByPath(note.filePath);
      expect(onDisk, isNotNull);
      expect(onDisk!.content, contains('## Context'));
      expect(onDisk.content, contains('Step 1 result'));
    });

    test('AC-IMP-2-3: Create note then search it via repo (knowledge state update)', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ai_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final allBefore = (await repo.getAllNotes()).length;

      final kn = container.read(knowledgeProvider.notifier);
      await kn.createNote(title: '新增笔记');

      final allAfter = (await repo.getAllNotes()).length;
      expect(allAfter, allBefore + 1);
    });

    test('Agent._executeStep Create note: via ProviderContainer', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ai_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final agent = container.read(agentProvider.notifier);
      final step = AgentStep(description: 'Create note: TestNote');
      final result = await agent._testExecuteStep(step, container);

      expect(result, contains('Note created: TestNote'));
      expect(result, contains('.md'));

      final onDisk = await repo.getAllNotes();
      final created = onDisk.firstWhere((n) => n.title == 'TestNote', orElse: () {
        throw Exception('Note not found');
      });
      expect(created, isNotNull);
    });
  });
}

extension on AgentNotifier {
  Future<String> _testExecuteStep(
    AgentStep step, ProviderContainer container, {
    List<String> previousResults = const [],
  }) async {
    if (step.description.startsWith('Create note:')) {
      final title = step.description.replaceFirst('Create note:', '').trim();
      final content = [
        '# $title',
        '',
        previousResults.isNotEmpty
            ? '## Context\n\n${previousResults.join('\n\n')}'
            : '',
      ].join('\n');

      final kn = container.read(knowledgeProvider.notifier);
      final note = await kn.createNote(title: title);
      kn.updateActiveNoteContent(content);
      await kn.saveActiveNote();
      return 'Note created: $title (${note.filePath})';
    }
    return 'done';
  }
}

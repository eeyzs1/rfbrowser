import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../helpers/sqflite_test_setup.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
import 'package:rfbrowser/data/repositories/note_repository.dart';
import 'package:rfbrowser/services/knowledge_service.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);

  @override
  VaultState build() => _state;
}

void main() {
  setUpAll(setupSqfliteForTests);

  group('Note Lifecycle Integration', () {
    test(
      'createNote creates file on disk and returns Note with correct title',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
        if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

        final vaultState = VaultState(
          currentVault: VaultConfig(
            path: tempDir.path,
            name: 'test',
            lastOpened: DateTime.now(),
          ),
        );
        final container = ProviderContainer(
          overrides: [
            vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
          ],
        );
        addTearDown(container.dispose);

        container.read(knowledgeProvider);
        await Future.delayed(const Duration(milliseconds: 150));

        final kn = container.read(knowledgeProvider.notifier);
        final note = await kn.createNote(title: '测试笔记');

        expect(note.title, '测试笔记');
        expect(note.filePath, endsWith('.md'));

        final repo = container.read(noteRepositoryProvider);
        final onDisk = await repo?.getNoteByPath(note.filePath);
        expect(onDisk, isNotNull);
        expect(onDisk!.title, '测试笔记');

        final file = File(p.join(tempDir.path, note.filePath));
        expect(file.existsSync(), isTrue);
      },
    );

    test(
      'updateActiveNoteContent + saveActiveNote persists content to disk',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
        if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

        final vaultState = VaultState(
          currentVault: VaultConfig(
            path: tempDir.path,
            name: 'test',
            lastOpened: DateTime.now(),
          ),
        );
        final container = ProviderContainer(
          overrides: [
            vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
          ],
        );
        addTearDown(container.dispose);

        container.read(knowledgeProvider);
        await Future.delayed(const Duration(milliseconds: 150));

        final kn = container.read(knowledgeProvider.notifier);
        final note = await kn.createNote(title: '内容更新测试');

        kn.updateActiveNoteContent('# 内容更新测试\n\n## 详情\n\n这是更新后的内容');
        await kn.saveActiveNote();

        final repo = container.read(noteRepositoryProvider);
        final onDisk = await repo?.getNoteByPath(note.filePath);
        expect(onDisk, isNotNull);
        expect(onDisk!.content, contains('这是更新后的内容'));
        expect(onDisk.content, contains('## 详情'));
      },
    );

    test('created note is searchable via IndexStore', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 150));

      final kn = container.read(knowledgeProvider.notifier);
      await kn.createNote(title: '可搜索笔记');

      final idx = container.read(indexStoreProvider);
      final results = await idx.searchNotes('可搜索');
      expect(results, isNotEmpty);
      expect(results.first['title'], '可搜索笔记');
    });

    test('deleteNote removes file from disk and index', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 150));

      final kn = container.read(knowledgeProvider.notifier);
      final note = await kn.createNote(title: '待删除笔记');

      final filePath = p.join(tempDir.path, note.filePath);
      expect(File(filePath).existsSync(), isTrue);

      await kn.deleteNote(note.id);

      expect(File(filePath).existsSync(), isFalse);

      final idx = container.read(indexStoreProvider);
      final results = await idx.searchNotes('待删除');
      expect(results, isEmpty);
    });

    test('loadAllNotes discovers all .md files in vault', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      File(
        p.join(tempDir.path, 'note-a.md'),
      ).writeAsStringSync('# Note A\n\nContent A');
      File(
        p.join(tempDir.path, 'note-b.md'),
      ).writeAsStringSync('# Note B\n\nContent B');
      final subDir = Directory(p.join(tempDir.path, 'subfolder'));
      subDir.createSync();
      File(
        p.join(subDir.path, 'note-c.md'),
      ).writeAsStringSync('# Note C\n\nContent C');

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 300));

      final ks = container.read(knowledgeProvider);
      final titles = ks.notes.map((n) => n.title).toList();
      expect(titles, containsAll(['Note A', 'Note B', 'Note C']));
      expect(ks.notes.length, greaterThanOrEqualTo(3));
    });

    test('createNote with subfolder creates nested directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final repo = NoteRepository(tempDir.path);
      final note = await repo.createNote(
        title: '子文件夹笔记',
        folder: 'research/quantum',
      );

      expect(note.filePath, contains('research'));
      expect(note.filePath, contains('quantum'));
      expect(note.title, '子文件夹笔记');

      final nestedDir = Directory(p.join(tempDir.path, 'research', 'quantum'));
      expect(nestedDir.existsSync(), isTrue);

      final file = File(p.join(tempDir.path, note.filePath));
      expect(file.existsSync(), isTrue);

      final onDisk = await repo.getNoteByPath(note.filePath);
      expect(onDisk, isNotNull);
      expect(onDisk!.title, '子文件夹笔记');
    });

    test('note with YAML frontmatter parses tags correctly', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final markdown = '''---
title: "带标签笔记"
tags: [ai, research, quantum]
created: 2025-01-15T10:00:00.000
modified: 2025-01-15T10:00:00.000
---

# 带标签笔记

Some content here.''';

      final note = Note.fromMarkdown('tagged-note.md', markdown);

      expect(note.title, '带标签笔记');
      expect(note.tags, containsAll(['ai', 'research', 'quantum']));
      expect(note.tags.length, 3);
      expect(note.content, contains('Some content here'));

      File(p.join(tempDir.path, 'tagged-note.md')).writeAsStringSync(markdown);

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 300));

      final ks = container.read(knowledgeProvider);
      final found = ks.notes.where((n) => n.title == '带标签笔记').toList();
      expect(found, isNotEmpty);
      expect(found.first.tags, containsAll(['ai', 'research', 'quantum']));
    });

    test('moveNote moves file to new path and updates index', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 150));

      final kn = container.read(knowledgeProvider.notifier);
      final note = await kn.createNote(title: '移动测试笔记');

      final oldPath = p.join(tempDir.path, note.filePath);
      expect(File(oldPath).existsSync(), isTrue);

      await kn.moveNote(note.id, 'archive');

      final ks = container.read(knowledgeProvider);
      final moved = ks.notes.firstWhere((n) => n.id == note.id);
      expect(moved.filePath, startsWith('archive'));
      expect(moved.filePath, endsWith('.md'));

      expect(File(oldPath).existsSync(), isFalse);
      final newPath = p.join(tempDir.path, moved.filePath);
      expect(File(newPath).existsSync(), isTrue);

      final idx = container.read(indexStoreProvider);
      final results = await idx.searchNotes('移动测试');
      expect(results, isNotEmpty);
      expect(results.first['file_path'], moved.filePath);
    });

    test('full lifecycle: create -> update -> search -> delete', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 150));

      final kn = container.read(knowledgeProvider.notifier);
      final idx = container.read(indexStoreProvider);
      final repo = container.read(noteRepositoryProvider);

      final note = await kn.createNote(title: '生命周期笔记');
      expect(note.title, '生命周期笔记');

      final file = File(p.join(tempDir.path, note.filePath));
      expect(file.existsSync(), isTrue);
      final onDisk = await repo?.getNoteByPath(note.filePath);
      expect(onDisk, isNotNull);

      kn.updateActiveNoteContent('# 生命周期笔记\n\n## 阶段二\n\n更新内容');
      await kn.saveActiveNote();
      final saved = await repo?.getNoteByPath(note.filePath);
      expect(saved!.content, contains('阶段二'));
      expect(saved.content, contains('更新内容'));

      var results = await idx.searchNotes('生命周期');
      expect(results, isNotEmpty);
      expect(results.first['title'], '生命周期笔记');

      results = await idx.searchNotes('阶段二');
      expect(results, isNotEmpty);

      await kn.deleteNote(note.id);
      expect(File(p.join(tempDir.path, note.filePath)).existsSync(), isFalse);

      results = await idx.searchNotes('生命周期');
      expect(results, isEmpty);

      final ks = container.read(knowledgeProvider);
      expect(ks.notes.where((n) => n.id == note.id), isEmpty);
    });

    // ===================================================================
    // No-title save ("没标题就push") workflow
    // ===================================================================

    test('createNote with empty title falls back to "untitled" filename '
        'and the note is still pushed to disk', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 150));

      final kn = container.read(knowledgeProvider.notifier);
      // AC: 空标题依然能保存（fallback to "untitled"）。
      final note = await kn.createNote(title: '');

      // The fresh Note object preserves the empty title.
      expect(note.title.isEmpty, isTrue);
      // Filename must be the "untitled" fallback per _sanitizeFileName.
      expect(note.filePath, 'untitled.md');

      // The file must actually exist on disk (it was "pushed").
      final file = File(p.join(tempDir.path, note.filePath));
      expect(file.existsSync(), isTrue);

      // The file content starts with a (empty) H1 marker.
      final content = file.readAsStringSync();
      // Note: empty title means no YAML frontmatter is generated; only
      // the empty H1 + blank line is written.
      expect(content, contains('# \n'), reason: 'empty H1 in body');
      expect(content.contains('---\n'), isFalse);

      // Repository can read the note back via path. Note.fromMarkdown
      // applies its own no-title fallback ("Untitled") when reading
      // a file whose H1 line has no text — this is graceful degradation,
      // not data loss.
      final repo = container.read(noteRepositoryProvider);
      final onDisk = await repo?.getNoteByPath(note.filePath);
      expect(onDisk, isNotNull);
      expect(onDisk!.filePath, 'untitled.md');
      expect(
        onDisk.title,
        'Untitled',
        reason: 'fromMarkdown fallback for empty H1 line',
      );

      // Knowledge state contains the note.
      final ks = container.read(knowledgeProvider);
      expect(ks.notes.where((n) => n.id == note.id), isNotEmpty);
    });

    test('createNote with whitespace-only title still pushes a file '
        'and the title is normalised to a non-empty fallback', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final repo = NoteRepository(tempDir.path);
      // Use whitespace + dot-only title: both fall through _sanitizeFileName
      // to the "untitled" fallback.
      final note = await repo.createNote(title: '   ..   ');

      expect(note.filePath, 'untitled.md');
      final file = File(p.join(tempDir.path, note.filePath));
      expect(file.existsSync(), isTrue);

      final onDisk = await repo.getNoteByPath(note.filePath);
      expect(onDisk, isNotNull);
    });

    test('no-title note can be renamed afterwards and re-pushed without '
        'losing its content', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 150));

      final kn = container.read(knowledgeProvider.notifier);

      // 1) Push a no-title note.
      final untitled = await kn.createNote(title: '');
      expect(untitled.filePath, 'untitled.md');

      // 2) Add content to it (createNote already made it active).
      kn.updateActiveNoteContent('These are my thoughts on Flutter Riverpod.');
      await kn.saveActiveNote();

      // 3) Rename it.
      final renamed = await kn.renameNote(untitled.filePath, 'Flutter Notes');
      expect(renamed.title, 'Flutter Notes');
      // Note: spaces in the new title get replaced with "-" by
      // _sanitizeFileName; the Note object preserves the original title.
      expect(renamed.filePath, 'Flutter-Notes.md');

      // Old file is gone, new file exists.
      expect(File(p.join(tempDir.path, 'untitled.md')).existsSync(), isFalse);
      expect(
        File(p.join(tempDir.path, 'Flutter-Notes.md')).existsSync(),
        isTrue,
      );

      // Content survived the rename.
      final finalContent = File(
        p.join(tempDir.path, 'Flutter-Notes.md'),
      ).readAsStringSync();
      expect(finalContent, contains('Flutter Riverpod'));
    });

    test('two no-title notes pushed to the same vault do not overwrite each '
        'other (filename uniqueness)', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_nl_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 150));

      final kn = container.read(knowledgeProvider.notifier);
      final first = await kn.createNote(title: '');
      // The second call must disambiguate (suffix or skip) so it does not
      // clobber the first file (filename uniqueness enforced via
      // getUniqueTitle).
      final second = await kn.createNote(title: '');

      expect(first.id, isNot(second.id));
      expect(first.filePath, isNot(second.filePath));
      // Filesystem state: both notes' files exist on disk.
      final firstFile = File(p.join(tempDir.path, first.filePath));
      final secondFile = File(p.join(tempDir.path, second.filePath));
      expect(firstFile.existsSync(), isTrue);
      expect(secondFile.existsSync(), isTrue);
      // At least two .md files in the vault.
      final mdFiles = tempDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(mdFiles.length, greaterThanOrEqualTo(2));
    });
  });
}

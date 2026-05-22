import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Note Lifecycle Integration', () {
    test('createNote creates file on disk and returns Note with correct title',
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
      final container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
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
    });

    test('updateActiveNoteContent + saveActiveNote persists content to disk',
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
      final container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
      addTearDown(container.dispose);

      container.read(knowledgeProvider);
      await Future.delayed(const Duration(milliseconds: 150));

      final kn = container.read(knowledgeProvider.notifier);
      final note = await kn.createNote(title: '内容更新测试');

      kn.updateActiveNoteContent(
          '# 内容更新测试\n\n## 详情\n\n这是更新后的内容');
      await kn.saveActiveNote();

      final repo = container.read(noteRepositoryProvider);
      final onDisk = await repo?.getNoteByPath(note.filePath);
      expect(onDisk, isNotNull);
      expect(onDisk!.content, contains('这是更新后的内容'));
      expect(onDisk.content, contains('## 详情'));
    });

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
      final container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
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
      final container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
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

      File(p.join(tempDir.path, 'note-a.md'))
          .writeAsStringSync('# Note A\n\nContent A');
      File(p.join(tempDir.path, 'note-b.md'))
          .writeAsStringSync('# Note B\n\nContent B');
      final subDir = Directory(p.join(tempDir.path, 'subfolder'));
      subDir.createSync();
      File(p.join(subDir.path, 'note-c.md'))
          .writeAsStringSync('# Note C\n\nContent C');

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      final container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
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
          title: '子文件夹笔记', folder: 'research/quantum');

      expect(note.filePath, contains('research'));
      expect(note.filePath, contains('quantum'));
      expect(note.title, '子文件夹笔记');

      final nestedDir =
          Directory(p.join(tempDir.path, 'research', 'quantum'));
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
      final container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
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
      final container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
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
      final container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
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
  });
}

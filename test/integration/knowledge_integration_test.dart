import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../helpers/sqflite_test_setup.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/knowledge_service.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
}

void main() {
  setUpAll(setupSqfliteForTests);

  group('Knowledge Service Integration', () {
    test('loadAllNotes discovers notes and builds links', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ks_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      File(
        p.join(tempDir.path, 'source.md'),
      ).writeAsStringSync('# Source Note\n\nSee [[Target Note]] for details.');
      File(
        p.join(tempDir.path, 'target.md'),
      ).writeAsStringSync('# Target Note\n\nTarget content');

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
      expect(ks.notes.length, greaterThanOrEqualTo(2));
      expect(ks.notes.any((n) => n.title == 'Source Note'), isTrue);
      expect(ks.notes.any((n) => n.title == 'Target Note'), isTrue);
    });

    test('knowledge state tracks active note', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ks_');
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
      final note = await kn.createNote(title: 'Active Test');

      kn.openNote(note.id);
      final ks = container.read(knowledgeProvider);
      expect(ks.activeNoteId, note.id);
      expect(ks.activeNote, isNotNull);
      expect(ks.activeNote!.title, 'Active Test');
    });

    test('knowledge state computes outlinks and backlinks', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ks_');
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
      await kn.createNote(title: 'Target');
      final source = await kn.createNote(title: 'Source');

      kn.updateActiveNoteContent('See [[Target]] for more');
      await kn.saveActiveNote();

      kn.openNote(source.id);
      final ks = container.read(knowledgeProvider);
      expect(ks.activeNoteId, source.id);
    });

    test('knowledge state filters notes by tag', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ks_');
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
      await kn.createNote(title: 'AI Note');

      kn.toggleTag('ai');
      kn.toggleTag('research');
      final ks = container.read(knowledgeProvider);
      expect(ks.selectedTags, containsAll(['ai', 'research']));
    });

    test('knowledge state note filter works', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ks_');
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
      kn.setFilter(NoteFilter.hasTags);
      expect(container.read(knowledgeProvider).noteFilter, NoteFilter.hasTags);

      kn.setFilter(NoteFilter.hasLinks);
      expect(container.read(knowledgeProvider).noteFilter, NoteFilter.hasLinks);
    });

    test('knowledge search returns results', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ks_');
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
      await kn.createNote(title: 'Searchable Note');

      await kn.search('Searchable');
      final ks = container.read(knowledgeProvider);
      expect(ks.searchResults, isNotEmpty);
    });
  });

  group('Link Service Integration', () {
    test('rebuildAllLinks creates links from wikilinks', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final linkNotifier = container.read(linkServiceProvider.notifier);
      final notes = [
        Note(
          id: 'n1',
          title: 'Note One',
          filePath: 'note-one.md',
          content: 'Refers to [[Note Two]]',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
        Note(
          id: 'n2',
          title: 'Note Two',
          filePath: 'note-two.md',
          content: 'Target note',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];

      linkNotifier.rebuildAllLinks(notes);

      final state = container.read(linkServiceProvider);
      expect(state.links, isNotEmpty);
      // _pathToId converts filePath to id: 'note-two.md' -> 'note-two'
      expect(
        state.links.any((l) => l.sourceId == 'n1' && l.targetId == 'note-two'),
        isTrue,
      );
    });

    test('getBacklinks returns backlinks for a note', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final linkNotifier = container.read(linkServiceProvider.notifier);
      final notes = [
        Note(
          id: 'a',
          title: 'Note A',
          filePath: 'a.md',
          content: 'Links to [[Note B]]',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
        Note(
          id: 'b',
          title: 'Note B',
          filePath: 'b.md',
          content: 'Target',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];

      linkNotifier.rebuildAllLinks(notes);

      final backlinks = container.read(linkServiceProvider).backlinksCache;
      expect(backlinks.containsKey('b'), isTrue);
      expect(backlinks['b']!.any((l) => l.sourceId == 'a'), isTrue);
    });

    test('links from source note are found via getNoteLinks', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final linkNotifier = container.read(linkServiceProvider.notifier);
      final notes = [
        Note(
          id: 'x',
          title: 'X',
          filePath: 'x.md',
          content: 'Ref [[Y]] and [[Z]]',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
        Note(
          id: 'y',
          title: 'Y',
          filePath: 'y.md',
          content: 'Y content',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
        Note(
          id: 'z',
          title: 'Z',
          filePath: 'z.md',
          content: 'Z content',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];

      linkNotifier.rebuildAllLinks(notes);

      final outlinks = linkNotifier.getNoteLinks('x');
      expect(outlinks.length, 2);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/knowledge_service.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
  @override
  set state(VaultState newState) => super.state = newState;
}

ProviderContainer createContainer() {
  return ProviderContainer(overrides: [
    vaultProvider.overrideWith(() => TestVaultNotifier(VaultState())),
  ]);
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('KnowledgeState', () {
    test('default state has empty values', () {
      final state = KnowledgeState();
      expect(state.notes, isEmpty);
      expect(state.activeNoteId, isNull);
      expect(state.links, isEmpty);
      expect(state.backlinksCache, isEmpty);
      expect(state.searchResults, isEmpty);
      expect(state.isSearching, false);
      expect(state.selectedTags, isEmpty);
      expect(state.noteFilter, NoteFilter.all);
    });

    test('copyWith updates notes', () {
      final note = Note(title: 'Test', filePath: 'test.md');
      final state = KnowledgeState().copyWith(notes: [note]);
      expect(state.notes, hasLength(1));
      expect(state.notes.first.title, 'Test');
    });

    test('copyWith updates activeNoteId', () {
      final state = KnowledgeState().copyWith(activeNoteId: 'note-1');
      expect(state.activeNoteId, 'note-1');
    });

    test('copyWith updates links', () {
      final link = Link(
        sourceId: 'n1',
        targetId: 'n2',
        type: LinkType.wikilink,
      );
      final state = KnowledgeState().copyWith(links: [link]);
      expect(state.links, hasLength(1));
    });

    test('copyWith updates searchResults', () {
      final results = [{'title': 'Result 1'}];
      final state = KnowledgeState().copyWith(searchResults: results);
      expect(state.searchResults, results);
    });

    test('copyWith updates isSearching', () {
      final state = KnowledgeState().copyWith(isSearching: true);
      expect(state.isSearching, true);
    });

    test('copyWith updates noteFilter', () {
      final state = KnowledgeState().copyWith(noteFilter: NoteFilter.hasTags);
      expect(state.noteFilter, NoteFilter.hasTags);
    });

    test('activeNote returns null when no activeNoteId', () {
      final state = KnowledgeState();
      expect(state.activeNote, isNull);
    });

    test('activeNote returns note matching activeNoteId', () {
      final note = Note(title: 'Active', filePath: 'active.md');
      final state = KnowledgeState(
        notes: [note],
        activeNoteId: note.id,
      );
      expect(state.activeNote, isNotNull);
      expect(state.activeNote!.title, 'Active');
    });

    test('activeNote returns null when id not found', () {
      final state = KnowledgeState(
        notes: [Note(title: 'Other', filePath: 'other.md')],
        activeNoteId: 'non-existent',
      );
      expect(state.activeNote, isNull);
    });

    test('outlinks returns links from active note', () {
      final link1 = Link(sourceId: 'n1', targetId: 'a', type: LinkType.wikilink);
      final link2 = Link(sourceId: 'n2', targetId: 'b', type: LinkType.wikilink);
      final link3 = Link(sourceId: 'n1', targetId: 'c', type: LinkType.wikilink);
      final state = KnowledgeState(
        activeNoteId: 'n1',
        links: [link1, link2, link3],
      );
      expect(state.outlinks, hasLength(2));
      expect(state.outlinks[0].sourceId, 'n1');
      expect(state.outlinks[1].sourceId, 'n1');
    });

    test('outlinks returns empty when no activeNoteId', () {
      final state = KnowledgeState(links: [
        Link(sourceId: 'n1', targetId: 't', type: LinkType.wikilink),
      ]);
      expect(state.outlinks, isEmpty);
    });

    test('backlinks returns links to active note', () {
      final link1 = Link(sourceId: 'n1', targetId: 'n2', type: LinkType.wikilink);
      final link2 = Link(sourceId: 'n3', targetId: 'n4', type: LinkType.wikilink);
      final state = KnowledgeState(
        activeNoteId: 'n2',
        links: [link1, link2],
      );
      expect(state.backlinks, hasLength(1));
      expect(state.backlinks.first.sourceId, 'n1');
    });

    test('backlinks returns empty when no activeNoteId', () {
      final state = KnowledgeState(links: [
        Link(sourceId: 'n1', targetId: 'n2', type: LinkType.wikilink),
      ]);
      expect(state.backlinks, isEmpty);
    });

    test('copyWith updates backlinksCache', () {
      final cache = {'n1': [Link(sourceId: 'n1', targetId: 'n2', type: LinkType.wikilink)]};
      final state = KnowledgeState().copyWith(backlinksCache: cache);
      expect(state.backlinksCache, cache);
    });
  });

  group('KnowledgeNotifier', () {
    test('build returns KnowledgeState', () {
      final container = createContainer();
      final notifier = container.read(knowledgeProvider.notifier);
      expect(notifier.state.notes, isEmpty);
    });

    test('setFilter updates note filter', () {
      final container = createContainer();
      final notifier = container.read(knowledgeProvider.notifier);
      notifier.setFilter(NoteFilter.hasLinks);
      expect(notifier.state.noteFilter, NoteFilter.hasLinks);
    });

    test('openNote sets activeNoteId', () {
      final container = createContainer();
      final notifier = container.read(knowledgeProvider.notifier);
      notifier.openNote('note-1');
      expect(notifier.state.activeNoteId, 'note-1');
    });

    test('updateActiveNoteContent does nothing when no active note', () {
      final container = createContainer();
      final notifier = container.read(knowledgeProvider.notifier);
      notifier.updateActiveNoteContent('new content');
      expect(notifier.state.notes, isEmpty);
    });

    test('updateActiveNoteContent updates active note content', () {
      final container = createContainer();
      final notifier = container.read(knowledgeProvider.notifier);
      final note = Note(title: 'Test', filePath: 'test.md');
      notifier.state = KnowledgeState(
        notes: [note],
        activeNoteId: note.id,
      );
      notifier.updateActiveNoteContent('updated content');
      expect(notifier.state.activeNote?.content, 'updated content');
    });

    test('updateActiveNoteContent preserves other notes', () {
      final container = createContainer();
      final notifier = container.read(knowledgeProvider.notifier);
      final note1 = Note(title: 'Note 1', filePath: 'note1.md');
      final note2 = Note(title: 'Note 2', filePath: 'note2.md', content: 'original');
      notifier.state = KnowledgeState(
        notes: [note1, note2],
        activeNoteId: note2.id,
      );
      notifier.updateActiveNoteContent('changed');
      final n1 = notifier.state.notes.firstWhere((n) => n.id == note1.id);
      expect(n1.content, isEmpty);
      final n2 = notifier.state.notes.firstWhere((n) => n.id == note2.id);
      expect(n2.content, 'changed');
    });

    test('setFilter cycles through all filter types', () {
      final container = createContainer();
      final notifier = container.read(knowledgeProvider.notifier);
      notifier.setFilter(NoteFilter.hasAttachments);
      expect(notifier.state.noteFilter, NoteFilter.hasAttachments);
      notifier.setFilter(NoteFilter.hasTags);
      expect(notifier.state.noteFilter, NoteFilter.hasTags);
      notifier.setFilter(NoteFilter.all);
      expect(notifier.state.noteFilter, NoteFilter.all);
    });
  });
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/note.dart';
import '../data/models/link.dart';
import '../data/repositories/note_repository.dart';
import '../data/stores/index_store.dart';
import '../core/link/link_extractor.dart';
import '../core/link/link_resolver.dart';

class KnowledgeState {
  final List<Note> notes;
  final Note? activeNote;
  final List<Link> backlinks;
  final List<Link> outlinks;
  final List<Map<String, dynamic>> searchResults;
  final bool isIndexing;
  final String? error;

  KnowledgeState({
    this.notes = const [],
    this.activeNote,
    this.backlinks = const [],
    this.outlinks = const [],
    this.searchResults = const [],
    this.isIndexing = false,
    this.error,
  });

  KnowledgeState copyWith({
    List<Note>? notes,
    Note? activeNote,
    List<Link>? backlinks,
    List<Link>? outlinks,
    List<Map<String, dynamic>>? searchResults,
    bool? isIndexing,
    String? error,
    bool clearError = false,
    bool clearActiveNote = false,
  }) {
    return KnowledgeState(
      notes: notes ?? this.notes,
      activeNote: clearActiveNote ? null : (activeNote ?? this.activeNote),
      backlinks: backlinks ?? this.backlinks,
      outlinks: outlinks ?? this.outlinks,
      searchResults: searchResults ?? this.searchResults,
      isIndexing: isIndexing ?? this.isIndexing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class KnowledgeNotifier extends Notifier<KnowledgeState> {
  final LinkExtractor _linkExtractor = LinkExtractor();

  @override
  KnowledgeState build() => KnowledgeState();

  NoteRepository? get _noteRepo => ref.read(noteRepositoryProvider);
  IndexStore get _indexStore => ref.read(indexStoreProvider);
  LinkResolver? get _linkResolver => ref.read(linkResolverProvider);

  NoteRepository get _repo {
    final r = _noteRepo;
    if (r == null) throw Exception('No vault open');
    return r;
  }

  Future<void> loadAllNotes() async {
    final repo = _noteRepo;
    if (repo == null) return;
    state = state.copyWith(isIndexing: true);
    try {
      final notes = await repo.getAllNotes();
      await _indexStore.rebuildIndex(notes);
      _linkResolver?.rebuildTitleIndex(notes);
      await _rebuildAllLinks(notes);
      state = state.copyWith(notes: notes, isIndexing: false);
    } catch (e) {
      state = state.copyWith(isIndexing: false, error: e.toString());
    }
  }

  Future<void> openNote(String relativePath) async {
    final repo = _noteRepo;
    if (repo == null) return;
    try {
      final note = await repo.getNoteByPath(relativePath);
      if (note != null) {
        final backlinks = await _indexStore.getBacklinks(note.id);
        final outlinks = await _resolveOutlinks(note);
        state = state.copyWith(
          activeNote: note,
          backlinks: backlinks,
          outlinks: outlinks,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Note> createNote({required String title, String folder = ''}) async {
    final note = await _repo.createNote(title: title, folder: folder);
    await _indexStore.indexNote(note);
    await _indexLinksForNote(note);
    _linkResolver?.rebuildTitleIndex([...state.notes, note]);
    state = state.copyWith(notes: [...state.notes, note], activeNote: note);
    return note;
  }

  Future<void> saveActiveNote() async {
    final note = state.activeNote;
    final repo = _noteRepo;
    if (note == null || repo == null) return;
    await repo.saveNote(note);
    await _indexStore.indexNote(note);
    await _indexLinksForNote(note);
    final backlinks = await _indexStore.getBacklinks(note.id);
    final outlinks = await _resolveOutlinks(note);
    state = state.copyWith(backlinks: backlinks, outlinks: outlinks);
  }

  Future<void> updateActiveNoteContent(String content) async {
    final note = state.activeNote;
    if (note == null) return;
    final tags = _linkExtractor.extractTags(content);
    final updated = note.copyWith(content: content, tags: tags);
    state = state.copyWith(activeNote: updated);
  }

  Future<void> deleteNote(String relativePath) async {
    final repo = _noteRepo;
    if (repo == null) return;
    final note = await repo.getNoteByPath(relativePath);
    if (note != null) {
      await repo.deleteNote(relativePath);
      await _indexStore.removeNote(note.id);
      final remaining = state.notes
          .where((n) => n.filePath != relativePath)
          .toList();
      _linkResolver?.rebuildTitleIndex(remaining);
      state = state.copyWith(
        notes: remaining,
        clearActiveNote: state.activeNote?.filePath == relativePath,
      );
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }
    try {
      final results = await _indexStore.searchNotes(query);
      state = state.copyWith(searchResults: results);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Note> createDailyNote(DateTime date) async {
    final note = await _repo.createDailyNote(date);
    await _indexStore.indexNote(note);
    await _indexLinksForNote(note);
    _linkResolver?.rebuildTitleIndex([...state.notes, note]);
    state = state.copyWith(activeNote: note);
    return note;
  }

  Future<Note> clipToNote({
    required String url,
    required String title,
    required String content,
    String? selectedText,
  }) async {
    final note = await _repo.clipToNote(
      url: url,
      title: title,
      content: content,
      selectedText: selectedText,
    );
    await _indexStore.indexNote(note);
    await _indexLinksForNote(note);
    _linkResolver?.rebuildTitleIndex([...state.notes, note]);
    state = state.copyWith(notes: [...state.notes, note], activeNote: note);
    return note;
  }

  Future<void> _rebuildAllLinks(List<Note> notes) async {
    final resolver = _linkResolver;
    if (resolver == null) return;
    for (final note in notes) {
      await _indexLinksForNote(note);
    }
  }

  Future<void> _indexLinksForNote(Note note) async {
    final resolver = _linkResolver;
    if (resolver == null) return;
    final links = await resolver.resolveLinksForNote(note);
    for (final link in links) {
      await _indexStore.indexLink(link);
    }
    final tags = _linkExtractor.extractTags(note.content);
    if (tags.isNotEmpty) {
      final updated = note.copyWith(tags: tags);
      await _indexStore.indexNote(updated);
    }
  }

  Future<List<Link>> _resolveOutlinks(Note note) async {
    final resolver = _linkResolver;
    if (resolver == null) return [];
    return resolver.resolveLinksForNote(note);
  }
}

final indexStoreProvider = Provider<IndexStore>((ref) => IndexStore());

final knowledgeProvider = NotifierProvider<KnowledgeNotifier, KnowledgeState>(
  KnowledgeNotifier.new,
);

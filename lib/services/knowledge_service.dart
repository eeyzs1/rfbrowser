import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/note.dart';
import '../data/models/link.dart';
import '../data/repositories/note_repository.dart';
import '../data/stores/index_store.dart';

class KnowledgeState {
  final List<Note> notes;
  final Note? activeNote;
  final List<Link> backlinks;
  final List<Map<String, dynamic>> searchResults;
  final bool isIndexing;
  final String? error;

  KnowledgeState({
    this.notes = const [],
    this.activeNote,
    this.backlinks = const [],
    this.searchResults = const [],
    this.isIndexing = false,
    this.error,
  });

  KnowledgeState copyWith({
    List<Note>? notes,
    Note? activeNote,
    List<Link>? backlinks,
    List<Map<String, dynamic>>? searchResults,
    bool? isIndexing,
    String? error,
    bool clearError = false,
  }) {
    return KnowledgeState(
      notes: notes ?? this.notes,
      activeNote: activeNote ?? this.activeNote,
      backlinks: backlinks ?? this.backlinks,
      searchResults: searchResults ?? this.searchResults,
      isIndexing: isIndexing ?? this.isIndexing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class KnowledgeNotifier extends StateNotifier<KnowledgeState> {
  final NoteRepository? _noteRepo;
  final IndexStore _indexStore;

  KnowledgeNotifier(this._noteRepo, this._indexStore) : super(KnowledgeState());

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
        state = state.copyWith(activeNote: note, backlinks: backlinks);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Note> createNote({required String title, String folder = ''}) async {
    final note = await _repo.createNote(title: title, folder: folder);
    await _indexStore.indexNote(note);
    state = state.copyWith(
      notes: [...state.notes, note],
      activeNote: note,
    );
    return note;
  }

  Future<void> saveActiveNote() async {
    final note = state.activeNote;
    final repo = _noteRepo;
    if (note == null || repo == null) return;
    await repo.saveNote(note);
    await _indexStore.indexNote(note);
  }

  Future<void> updateActiveNoteContent(String content) async {
    final note = state.activeNote;
    if (note == null) return;
    final updated = note.copyWith(content: content);
    state = state.copyWith(activeNote: updated);
  }

  Future<void> deleteNote(String relativePath) async {
    final repo = _noteRepo;
    if (repo == null) return;
    final note = await repo.getNoteByPath(relativePath);
    if (note != null) {
      await repo.deleteNote(relativePath);
      await _indexStore.removeNote(note.id);
      state = state.copyWith(
        notes: state.notes.where((n) => n.filePath != relativePath).toList(),
        activeNote: state.activeNote?.filePath == relativePath ? null : state.activeNote,
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
    state = state.copyWith(
      notes: [...state.notes, note],
      activeNote: note,
    );
    return note;
  }
}

final indexStoreProvider = Provider<IndexStore>((ref) => IndexStore());

final knowledgeProvider = StateNotifierProvider<KnowledgeNotifier, KnowledgeState>((ref) {
  final noteRepo = ref.watch(noteRepositoryProvider);
  final indexStore = ref.watch(indexStoreProvider);
  return KnowledgeNotifier(noteRepo, indexStore);
});

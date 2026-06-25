import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../data/models/note.dart';
import '../data/models/link.dart';
import '../data/models/skill.dart';
import '../data/models/unlinked_mention.dart';
import '../data/stores/index_store.dart';
import '../data/stores/vault_store.dart';
import '../data/stores/split_pane_store.dart';
import '../core/graph/filter_engine.dart';
import '../core/active_note_mixin.dart';
import '../core/logging/app_logger.dart';
import 'note_service.dart';
import 'link_service.dart';
import 'search_service.dart';
import '../plugins/host/plugin_host.dart';
import 'embedding_service.dart';

export 'note_service.dart';
export 'link_service.dart';
export 'search_service.dart';

enum NoteFilter { all, hasLinks, hasAttachments, hasTags }

class KnowledgeState with ActiveNoteMixin {
  @override
  final List<Note> notes;
  @override
  final String? activeNoteId;
  final List<Link> links;
  final Map<String, List<Link>> backlinksCache;
  final List<Map<String, dynamic>> searchResults;
  final bool isSearching;
  final List<String> selectedTags;
  final NoteFilter noteFilter;

  const KnowledgeState({
    this.notes = const [],
    this.activeNoteId,
    this.links = const [],
    this.backlinksCache = const {},
    this.searchResults = const [],
    this.isSearching = false,
    this.selectedTags = const [],
    this.noteFilter = NoteFilter.all,
  });

  KnowledgeState copyWith({
    List<Note>? notes,
    String? activeNoteId,
    List<Link>? links,
    Map<String, List<Link>>? backlinksCache,
    List<Map<String, dynamic>>? searchResults,
    bool? isSearching,
    List<String>? selectedTags,
    NoteFilter? noteFilter,
  }) {
    return KnowledgeState(
      notes: notes ?? this.notes,
      activeNoteId: activeNoteId ?? this.activeNoteId,
      links: links ?? this.links,
      backlinksCache: backlinksCache ?? this.backlinksCache,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      selectedTags: selectedTags ?? this.selectedTags,
      noteFilter: noteFilter ?? this.noteFilter,
    );
  }

  List<Link> get outlinks {
    if (activeNoteId == null) return [];
    return links.where((l) => l.sourceId == activeNoteId).toList();
  }

  List<Link> get backlinks {
    if (activeNoteId == null) return [];
    return links.where((l) => l.targetId == activeNoteId).toList();
  }
}

class KnowledgeNotifier extends Notifier<KnowledgeState> {
  @override
  KnowledgeState build() {
    _init();
    return KnowledgeState();
  }

  void _init() {
    loadAllNotes();
  }

  NoteNotifier get _noteSvc => ref.read(noteServiceProvider.notifier);
  LinkNotifier get _linkSvc => ref.read(linkServiceProvider.notifier);
  SearchNotifier get _searchSvc => ref.read(searchServiceProvider.notifier);

  void _syncLinks() {
    final linkState = ref.read(linkServiceProvider);
    state = state.copyWith(
      links: linkState.links,
      backlinksCache: linkState.backlinksCache,
    );
  }

  Future<void> loadAllNotes() async {
    await _noteSvc.loadAllNotes();
    final noteState = ref.read(noteServiceProvider);
    state = state.copyWith(notes: noteState.notes);
    if (noteState.notes.isNotEmpty) {
      _linkSvc.rebuildAllLinks(noteState.notes);
      _syncLinks();
      // Build TF-IDF corpus for better local semantic search
      ref.read(embeddingServiceProvider).buildTfidfFromNotes(noteState.notes);
      // Load persisted note vectors, then backfill missing ones in background.
      _loadEmbeddings(noteState.notes);
    }
  }

  /// Loads persisted embeddings into the in-memory HNSW index, then kicks off
  /// a background backfill for any notes that do not yet have a vector.
  Future<void> _loadEmbeddings(List<Note> notes) async {
    final embeddingService = ref.read(embeddingServiceProvider);
    try {
      await embeddingService.loadPersistedEmbeddings();
    } catch (e) {
      appLog.warning('Failed to load persisted embeddings', error: e);
    }
    // Backfill missing vectors in the background (may hit Ollama/ONNX).
    embeddingService.batchEmbedMissing(notes).catchError((e, st) {
      appLog.warning('Failed to backfill note embeddings',
          error: e, stackTrace: st);
      return 0;
    });
  }

  void setFilter(NoteFilter filter) {
    state = state.copyWith(noteFilter: filter);
  }

  Note? getNote(String id) => _noteSvc.getNote(id);

  Future<void> saveNote(Note note) async {
    await _noteSvc.saveNote(note);
    state = state.copyWith(notes: ref.read(noteServiceProvider).notes);
    _linkSvc.updateLinksForNote(note, state.notes);
    _syncLinks();
    // Update the semantic index (fire-and-forget; failures are logged).
    _indexNoteEmbedding(note);
  }

  /// Re-embeds a single note and persists its vector. Runs in the background
  /// so note saving is never blocked by the embedding backend.
  void _indexNoteEmbedding(Note note) {
    ref.read(embeddingServiceProvider).onNoteSaved(note).catchError((e, st) {
      appLog.warning('Failed to index embedding for note ${note.id}',
          error: e, stackTrace: st);
    });
  }

  Future<Note> createNote({required String title, String content = ''}) async {
    final note = await _noteSvc.createNote(title: title, content: content);
    state = state.copyWith(
      notes: ref.read(noteServiceProvider).notes,
      activeNoteId: note.id,
    );
    _linkSvc.updateLinksForNote(note, state.notes);
    _syncLinks();
    return note;
  }

  Future<void> deleteNote(String id) async {
    await _noteSvc.deleteNote(id);
    state = state.copyWith(notes: ref.read(noteServiceProvider).notes);
    _linkSvc.rebuildAllLinks(state.notes);
    _syncLinks();
    // Remove the note's vector from the semantic index and persistence.
    ref.read(embeddingServiceProvider).removeNoteEmbedding(id).catchError((e, st) {
      appLog.warning('Failed to remove embedding for $id',
          error: e, stackTrace: st);
    });
  }

  Future<Note> renameNote(String oldPath, String newName) async {
    final renamed = await _noteSvc.renameNote(oldPath, newName);
    state = state.copyWith(notes: ref.read(noteServiceProvider).notes);
    _linkSvc.updateLinksForNote(renamed, state.notes);
    _syncLinks();
    return renamed;
  }

  Future<String> getUniqueTitle(String baseTitle) =>
      _noteSvc.getUniqueTitle(baseTitle);

  Future<void> moveNote(String noteId, String folder) async {
    await _noteSvc.moveNote(noteId, folder);
    await loadAllNotes();
  }

  List<String> getAllTags() => _noteSvc.getAllTags();

  List<Note> getDailyNotes(int days) => _noteSvc.getDailyNotes(days);

  List<Note> getNotesByTag(String tag) => _noteSvc.getNotesByTag(tag);

  Future<Note> clipToNote({
    required String url,
    required String title,
    required String content,
    String? selectedText,
    String? rawHtmlPath,
    String? screenshotPath,
  }) async {
    final note = await _noteSvc.clipToNote(
      url: url,
      title: title,
      content: content,
      selectedText: selectedText,
      rawHtmlPath: rawHtmlPath,
      screenshotPath: screenshotPath,
    );
    state = state.copyWith(notes: ref.read(noteServiceProvider).notes);
    _linkSvc.updateLinksForNote(note, state.notes);
    _syncLinks();
    return note;
  }

  Future<Note> clipFullPage({
    required String url,
    required String title,
    required String htmlContent,
    required String textContent,
    String? tabId,
  }) async {
    final note = await _noteSvc.clipFullPage(
      url: url,
      title: title,
      htmlContent: htmlContent,
      textContent: textContent,
      tabId: tabId,
    );
    state = state.copyWith(notes: ref.read(noteServiceProvider).notes);
    _linkSvc.updateLinksForNote(note, state.notes);
    _syncLinks();
    return note;
  }

  Future<Note> clipSelection({
    required String url,
    required String title,
    required String selectedText,
  }) async {
    final note = await _noteSvc.clipSelection(
      url: url,
      title: title,
      selectedText: selectedText,
    );
    state = state.copyWith(notes: ref.read(noteServiceProvider).notes);
    _linkSvc.updateLinksForNote(note, state.notes);
    _syncLinks();
    return note;
  }

  Future<List<Skill>> getAllSkills() => _noteSvc.getAllSkills();

  Future<void> createSkill(Skill skill) => _noteSvc.createSkill(skill);

  Future<void> deleteSkill(String skillId) => _noteSvc.deleteSkill(skillId);
  Future<void> updateSkill(Skill skill) => _noteSvc.updateSkill(skill);

  List<Link> getNoteLinks(String noteId) => _linkSvc.getNoteLinks(noteId);

  List<Link> getBacklinks(String noteId) => _linkSvc.getBacklinks(noteId);

  List<UnlinkedMentionResult> getUnlinkedMentions(String noteId) =>
      _linkSvc.getUnlinkedMentions(noteId, state.notes);

  List<Map<String, dynamic>> getGraphData() =>
      _linkSvc.getGraphData(state.notes);

  LocalGraphResult getLocalGraph(String centerNoteId, {int depth = 1}) =>
      _linkSvc.getLocalGraph(centerNoteId, state.notes, depth: depth);

  Future<void> linkMention(
    String sourceNoteId,
    String targetTitle,
    int position,
  ) async {
    await _linkSvc.linkMention(
      sourceNoteId,
      targetTitle,
      position,
      state.notes,
    );
    _syncLinks();
  }

  void openNote(String noteId) {
    // Open in the active split pane (creates a pane if none exists).
    ref.read(splitPaneProvider.notifier).openNoteInActiveLeaf(noteId);
    // Skip the state update when the active note is already this one.
    // Otherwise every click on the already-active note would trigger a
    // knowledgeProvider rebuild (sidebar trie, backlinks panel, all
    // panes) for no reason — a noticeable hitch on large vaults.
    if (state.activeNoteId == noteId) return;
    state = state.copyWith(activeNoteId: noteId);
    ref.read(pluginHostProvider.notifier).dispatchHook('note.opened', {
      'noteId': noteId,
    });
  }

  /// Updates the in-memory content of the note identified by [noteId]
  /// without persisting. Used by individual panes' autosave buffers.
  void updateNoteContent(String noteId, String content) {
    final notes = state.notes.toList();
    final idx = notes.indexWhere((n) => n.id == noteId);
    if (idx < 0) return;
    final updated = notes[idx].copyWith(content: content);
    notes[idx] = updated;
    state = state.copyWith(notes: notes);
  }

  /// Persists the note identified by [noteId] using its current in-memory
  /// content. Used by panes that edit a note which may not be the global
  /// active note.
  Future<void> saveNoteById(String noteId) async {
    final note = _findNote(noteId);
    if (note == null) return;
    await saveNote(note);
  }

  /// Sets the global active note id (the focused note). Used by panes to
  /// signal that they received focus, so backlinks/AI context follow.
  void setActiveNoteId(String noteId) {
    if (state.activeNoteId == noteId) return;
    state = state.copyWith(activeNoteId: noteId);
  }

  Note? _findNote(String id) {
    for (final n in state.notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  void updateActiveNoteContent(String content) {
    final activeId = state.activeNoteId;
    if (activeId == null) return;
    final note = state.activeNote;
    if (note == null) return;
    final updated = note.copyWith(content: content);
    final notes = state.notes.toList();
    final idx = notes.indexWhere((n) => n.id == activeId);
    if (idx >= 0) notes[idx] = updated;
    state = state.copyWith(notes: notes);
  }

  Future<void> saveActiveNote() async {
    final note = state.activeNote;
    if (note != null) {
      await saveNote(note);
    }
  }

  Future<void> createDailyNote(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final relativePath = 'daily-notes/$dateStr.md';

    final existing = state.notes.where((n) => n.filePath == relativePath);
    if (existing.isNotEmpty) {
      state = state.copyWith(activeNoteId: existing.first.id);
      return;
    }

    final note = Note(
      title: dateStr,
      filePath: relativePath,
      content: '# $dateStr\n\n',
      tags: ['daily-note'],
    );

    final vaultState = ref.read(vaultProvider);
    if (vaultState.currentVault != null) {
      final file = File(p.join(vaultState.currentVault!.path, relativePath));
      final dir = Directory(p.dirname(file.path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsString(note.toMarkdown());
    }

    final idx = ref.read(indexStoreProvider);
    await idx.indexNote(note);

    final notes = state.notes.toList()..add(note);
    state = state.copyWith(notes: notes, activeNoteId: note.id);

    _linkSvc.rebuildAllLinks(state.notes);
    _syncLinks();
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final results = await _searchSvc.search(query);
    state = state.copyWith(searchResults: results, isSearching: false);
    return results;
  }

  Future<List<Map<String, dynamic>>> hybridSearch(String query) async {
    final results = await _searchSvc.hybridSearch(query);
    state = state.copyWith(searchResults: results, isSearching: false);
    return results;
  }

  void toggleTag(String tag) {
    _searchSvc.toggleTag(tag);
    final searchState = ref.read(searchServiceProvider);
    state = state.copyWith(selectedTags: searchState.selectedTags);
  }

  void clearTags() {
    _searchSvc.clearTags();
  }
}

final knowledgeProvider = NotifierProvider<KnowledgeNotifier, KnowledgeState>(
  KnowledgeNotifier.new,
);

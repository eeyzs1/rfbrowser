import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:html2md/html2md.dart' as html2md;
import '../core/logging/app_logger.dart';
import '../data/models/note.dart';
import '../data/models/skill.dart';
import '../data/models/web_clip.dart';
import '../data/builtin_skills.dart';
import '../data/repositories/note_repository.dart';
import '../data/stores/index_store.dart';
import '../plugins/plugin_registry.dart';
import '../plugins/host/plugin_host.dart';
import '../core/active_note_mixin.dart';
import 'browser_service.dart';

class NoteState with ActiveNoteMixin {
  @override
  final List<Note> notes;
  @override
  final String? activeNoteId;

  const NoteState({this.notes = const [], this.activeNoteId});

  NoteState copyWith({List<Note>? notes, String? activeNoteId}) {
    return NoteState(
      notes: notes ?? this.notes,
      activeNoteId: activeNoteId ?? this.activeNoteId,
    );
  }
}

class NoteNotifier extends Notifier<NoteState> {
  @override
  NoteState build() {
    _init();
    return const NoteState();
  }

  void _init() {
    loadAllNotes();
  }

  /// Returns the current [NoteRepository], or throws if no vault is open.
  NoteRepository _repo() {
    final repo = ref.read(noteRepositoryProvider);
    if (repo == null) throw StateError('No vault open');
    return repo;
  }

  Future<void> loadAllNotes() async {
    final repo = ref.read(noteRepositoryProvider);
    if (repo == null) return;
    try {
      final notes = await repo.getAllNotes();
      state = state.copyWith(notes: notes);
    } catch (e) {
      appLog.error('NoteService: failed to load notes', error: e);
    }
  }

  Note? getNote(String id) {
    try {
      return state.notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNote(Note note) async {
    final repo = _repo();
    await repo.saveNote(note);

    final idx = ref.read(indexStoreProvider);
    final updatedNote = note.copyWith(modified: DateTime.now());
    await idx.indexNote(updatedNote);

    final notes = state.notes.toList();
    final existingIdx = notes.indexWhere((n) => n.id == note.id);
    if (existingIdx >= 0) {
      notes[existingIdx] = updatedNote;
    } else {
      notes.add(updatedNote);
    }
    state = state.copyWith(notes: notes);
    ref.read(pluginHostProvider.notifier).dispatchHook('note.saved', {
      'noteId': note.id,
      'title': note.title,
    });
  }

  Future<Note> createNote({required String title, String content = ''}) async {
    final repo = _repo();
    final uniqueTitle = await getUniqueTitle(title);
    final note = await repo.createNote(title: uniqueTitle);

    // Overwrite the placeholder body with the requested content.
    final withContent = note.copyWith(
      content: '# $uniqueTitle\n\n$content',
    );
    await repo.saveNote(withContent);

    final idx = ref.read(indexStoreProvider);
    await idx.indexNote(withContent);

    final notes = state.notes.toList()..add(withContent);
    state = state.copyWith(notes: notes, activeNoteId: withContent.id);

    return withContent;
  }

  Future<void> deleteNote(String id) async {
    final repo = _repo();
    final note = getNote(id);
    if (note == null) return;

    await repo.deleteNote(note.filePath);

    final idx = ref.read(indexStoreProvider);
    await idx.removeNote(id);

    final notes = state.notes.where((n) => n.id != id).toList();
    final newActiveId = state.activeNoteId == id ? null : state.activeNoteId;
    state = state.copyWith(notes: notes, activeNoteId: newActiveId);
  }

  Future<Note> renameNote(String oldPath, String newName) async {
    final repo = _repo();
    final note = state.notes.firstWhere(
      (n) => n.filePath == oldPath,
      orElse: () => throw StateError('Note not found: $oldPath'),
    );

    final newPath = await repo.renameNoteFile(oldPath, newName);

    final renamed = note.copyWith(title: newName, filePath: newPath);
    final notes = state.notes.toList();
    final idx = notes.indexWhere((n) => n.filePath == oldPath);
    if (idx >= 0) notes[idx] = renamed;
    state = state.copyWith(notes: notes);

    return renamed;
  }

  Future<String> getUniqueTitle(String baseTitle) async {
    final existingTitles = state.notes.map((n) => n.title).toSet();
    if (!existingTitles.contains(baseTitle)) return baseTitle;
    for (var i = 1; i < 100; i++) {
      final candidate = '$baseTitle $i';
      if (!existingTitles.contains(candidate)) return candidate;
    }
    return '${baseTitle}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> moveNote(String noteId, String folder) async {
    final repo = _repo();
    final note = getNote(noteId);
    if (note == null) return;
    final newPath = await repo.moveNoteFile(note.filePath, folder);
    if (newPath == note.filePath) return;

    final updated = note.copyWith(filePath: newPath);
    final notes = state.notes.toList();
    final idx = notes.indexWhere((n) => n.id == noteId);
    if (idx >= 0) notes[idx] = updated;
    state = state.copyWith(notes: notes);

    final idxStore = ref.read(indexStoreProvider);
    await idxStore.indexNote(updated);
  }

  List<String> getAllTags() {
    final tags = <String>{};
    for (final note in state.notes) {
      tags.addAll(note.tags);
    }
    return tags.toList()..sort();
  }

  List<Note> getDailyNotes(int days) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    return state.notes
        .where(
          (n) => n.tags.contains('daily-note') && n.created.isAfter(cutoff),
        )
        .toList()
      ..sort((a, b) => b.created.compareTo(a.created));
  }

  List<Note> getNotesByTag(String tag) {
    return state.notes.where((n) => n.tags.contains(tag)).toList();
  }

  Future<Note> clipToNote({
    required String url,
    required String title,
    required String content,
    String? selectedText,
    String? rawHtmlPath,
    String? screenshotPath,
  }) async {
    final repo = _repo();
    final fileName = repo.sanitizeFileName(title);
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final relativePath = p.join('clippings', '$fileName-$dateStr.md');

    final body = StringBuffer();
    body.writeln('> 来源: [$title]($url)');
    body.writeln('>');
    body.writeln('> 剪辑于 $dateStr');
    if (rawHtmlPath != null) {
      body.writeln('> 📄 [查看原始页面]($rawHtmlPath)');
    }
    if (screenshotPath != null) {
      body.writeln('> 📷 [查看截图]($screenshotPath)');
    }
    body.writeln();
    body.writeln(content);
    if (selectedText != null && selectedText.isNotEmpty) {
      body.writeln();
      body.writeln('## 选中片段');
      body.writeln();
      body.writeln(selectedText);
    }

    final note = Note(
      title: title,
      filePath: relativePath,
      content: body.toString(),
      sourceUrl: url,
      sourceTitle: title,
      tags: ['clipping'],
      rawHtmlPath: rawHtmlPath,
      screenshotPath: screenshotPath,
    );

    await repo.saveNote(note);

    final idx = ref.read(indexStoreProvider);
    await idx.indexNote(note);

    final notes = state.notes.toList()..add(note);
    state = state.copyWith(notes: notes);

    return note;
  }

  Future<Note> clipFullPage({
    required String url,
    required String title,
    required String htmlContent,
    required String textContent,
    String? tabId,
  }) async {
    final repo = _repo();
    final fileName = repo.sanitizeFileName(title);

    String markdownContent;
    if (htmlContent.isNotEmpty) {
      try {
        markdownContent = html2md.convert(
          htmlContent,
          styleOptions: {
            'headingStyle': 'atx',
            'bulletListMarker': '-',
            'codeBlockStyle': 'fenced',
            'fence': '```',
            'emDelimiter': '*',
            'strongDelimiter': '**',
          },
          ignore: ['script', 'style', 'nav', 'footer', 'header', 'noscript'],
        );
      } catch (_) {
        markdownContent = textContent.isNotEmpty ? textContent : htmlContent;
      }
    } else {
      markdownContent = textContent;
    }

    String? rawHtmlRelPath;
    String? screenshotRelPath;

    if (htmlContent.isNotEmpty) {
      rawHtmlRelPath = await repo.saveRawHtml(htmlContent, fileName);
    }

    if (tabId != null) {
      try {
        final screenshotData = await ref
            .read(browserProvider.notifier)
            .takeScreenshot(tabId);
        if (screenshotData != null) {
          screenshotRelPath = await repo.saveScreenshot(
            screenshotData,
            fileName,
          );
        }
      } catch (e) {
        appLog.error('NoteService: screenshot capture failed', error: e);
      }
    }

    final note = await clipToNote(
      url: url,
      title: title,
      content: markdownContent,
      rawHtmlPath: rawHtmlRelPath,
      screenshotPath: screenshotRelPath,
    );

    final clip = WebClip(
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}',
      url: url,
      title: title,
      content: markdownContent,
      rawHtmlPath: rawHtmlRelPath,
      screenshotPath: screenshotRelPath,
      noteId: note.id,
    );
    await repo.saveWebClipMeta(clip);

    return note;
  }

  Future<Note> clipSelection({
    required String url,
    required String title,
    required String selectedText,
  }) async {
    return clipToNote(
      url: url,
      title: title,
      content: selectedText,
      selectedText: selectedText,
    );
  }

  Future<Note> clipBookmark({
    required String url,
    required String title,
  }) async {
    return clipToNote(
      url: url,
      title: title,
      content: '# $title\n\n> Source: [$title]($url)\n',
    );
  }

  Future<List<Skill>> getAllSkills() async {
    final skills = <Skill>[];
    skills.addAll(kBuiltinSkills);
    skills.addAll(PluginRegistry.getAllPluginSkills());

    final repo = ref.read(noteRepositoryProvider);
    if (repo == null) return skills;
    skills.addAll(await repo.loadVaultSkills());
    return skills;
  }

  Future<void> createSkill(Skill skill) async {
    await updateSkill(skill);
  }

  Future<void> deleteSkill(String skillId) async {
    final repo = ref.read(noteRepositoryProvider);
    if (repo == null) return;
    await repo.deleteSkill(skillId);
  }

  Future<void> updateSkill(Skill skill) async {
    final repo = ref.read(noteRepositoryProvider);
    if (repo == null) return;
    await repo.saveSkill(skill);
  }
}

final noteServiceProvider = NotifierProvider<NoteNotifier, NoteState>(
  NoteNotifier.new,
);

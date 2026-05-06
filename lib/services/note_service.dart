import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../data/models/note.dart';
import '../data/models/skill.dart';
import '../data/stores/index_store.dart';
import '../data/stores/vault_store.dart';

class NoteState {
  final List<Note> notes;
  final String? activeNoteId;

  const NoteState({this.notes = const [], this.activeNoteId});

  NoteState copyWith({List<Note>? notes, String? activeNoteId}) {
    return NoteState(
      notes: notes ?? this.notes,
      activeNoteId: activeNoteId ?? this.activeNoteId,
    );
  }

  Note? get activeNote {
    if (activeNoteId == null) return null;
    try {
      return notes.firstWhere((n) => n.id == activeNoteId);
    } catch (_) {
      return null;
    }
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

  Future<void> loadAllNotes() async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return;

    final dir = Directory(vault.path);
    if (!await dir.exists()) return;

    final notes = <Note>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        try {
          final content = await entity.readAsString();
          final relativePath = p.relative(entity.path, from: vault.path);
          final note = Note.fromMarkdown(relativePath, content);
          notes.add(note);
        } catch (_) {}
      }
    }
    state = state.copyWith(notes: notes);
  }

  Note? getNote(String id) {
    try {
      return state.notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNote(Note note) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return;

    final file = File(p.join(vault.path, note.filePath));
    final updatedNote = note.copyWith(modified: DateTime.now());
    await file.writeAsString(updatedNote.toMarkdown());

    final idx = ref.read(indexStoreProvider);
    await idx.indexNote(updatedNote);

    final notes = state.notes.toList();
    final existingIdx = notes.indexWhere((n) => n.id == note.id);
    if (existingIdx >= 0) {
      notes[existingIdx] = updatedNote;
    } else {
      notes.add(updatedNote);
    }
    state = state.copyWith(notes: notes);
  }

  Future<Note> createNote({
    required String title,
    String content = '',
  }) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) throw StateError('No vault open');

    final uniqueTitle = await getUniqueTitle(title);
    final fileName = _sanitizeFileName(uniqueTitle);
    final relativePath = '$fileName.md';

    final note = Note(
      title: uniqueTitle,
      filePath: relativePath,
      content: '# $uniqueTitle\n\n$content',
    );

    final file = File(p.join(vault.path, relativePath));
    final dir = Directory(p.dirname(file.path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsString(note.toMarkdown());

    final idx = ref.read(indexStoreProvider);
    await idx.indexNote(note);

    final notes = state.notes.toList()..add(note);
    state = state.copyWith(notes: notes, activeNoteId: note.id);

    return note;
  }

  Future<void> deleteNote(String id) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return;
    final note = getNote(id);
    if (note == null) return;

    final file = File(p.join(vault.path, note.filePath));
    if (await file.exists()) {
      await file.delete();
    }

    final idx = ref.read(indexStoreProvider);
    await idx.removeNote(id);

    final notes = state.notes.where((n) => n.id != id).toList();
    final newActiveId = state.activeNoteId == id ? null : state.activeNoteId;
    state = state.copyWith(notes: notes, activeNoteId: newActiveId);
  }

  Future<Note> renameNote(String oldPath, String newName) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) throw StateError('No vault open');

    final note = state.notes.firstWhere(
      (n) => n.filePath == oldPath,
      orElse: () => throw StateError('Note not found: $oldPath'),
    );

    final newFileName = _sanitizeFileName(newName);
    final dirName = p.dirname(oldPath);
    final newPath = dirName == '.' ? '$newFileName.md' : p.join(dirName, '$newFileName.md');

    final oldFile = File(p.join(vault.path, oldPath));
    final newFile = File(p.join(vault.path, newPath));
    if (await oldFile.exists() && !await newFile.exists()) {
      await oldFile.rename(newFile.path);
    }

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
    final note = getNote(noteId);
    if (note == null) return;
    final fileName = p.basename(note.filePath);
    final newPath = folder.isEmpty ? fileName : p.join(folder, fileName);
    final updated = note.copyWith(filePath: newPath);
    await saveNote(updated);
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
        .where((n) => n.tags.contains('daily-note') && n.created.isAfter(cutoff))
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
  }) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) throw StateError('No vault open');

    final fileName = _sanitizeFileName(title);
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final relativePath = p.join('clippings', '$fileName-$dateStr.md');

    final note = Note(
      title: title,
      filePath: relativePath,
      content: '# $title\n\n$content\n\n${selectedText != null ? '## Selected\n\n$selectedText\n' : ''}',
      sourceUrl: url,
      sourceTitle: title,
      tags: ['clipping'],
    );

    final file = File(p.join(vault.path, relativePath));
    final dir = Directory(p.dirname(file.path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsString(note.toMarkdown());

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
  }) async {
    return clipToNote(url: url, title: title, content: textContent);
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
    skills.addAll(_getBuiltinSkills());

    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return skills;

    final skillDir = Directory(p.join(vault.path, '.rfbrowser', 'skills'));
    if (await skillDir.exists()) {
      await for (final entity in skillDir.list()) {
        if (entity is File && entity.path.endsWith('.yaml')) {
          try {
            final content = await entity.readAsString();
            final yml = loadYaml(content);
            skills.add(
              Skill(
                id: yml['id'] ?? p.basenameWithoutExtension(entity.path),
                name: yml['name'] ?? 'Unnamed',
                description: yml['description'] ?? '',
                prompt: yml['prompt'] ?? '',
                isBuiltin: false,
              ),
            );
          } catch (_) {}
        }
      }
    }
    return skills;
  }

  Future<void> createSkill(Skill skill) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return;
    final skillDir = Directory(p.join(vault.path, '.rfbrowser', 'skills'));
    if (!await skillDir.exists()) {
      await skillDir.create(recursive: true);
    }
    final content =
        'id: ${skill.id}\nname: ${skill.name}\ndescription: ${skill.description}\nprompt: |\n  ${skill.prompt.split('\n').join('\n  ')}\n';
    final file = File(p.join(skillDir.path, '${skill.id}.yaml'));
    await file.writeAsString(content);
  }

  Future<void> deleteSkill(String skillId) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return;
    final file = File(
      p.join(vault.path, '.rfbrowser', 'skills', '$skillId.yaml'),
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll('..', '')
        .substring(0, name.length > 100 ? 100 : name.length);
  }

  List<Skill> _getBuiltinSkills() {
    return [
      Skill(
        id: 'summarize-page',
        name: 'Summarize Page',
        description: 'Summarize the current web page',
        prompt: 'Please summarize the following web page content:\n\n@web[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'summarize-note',
        name: 'Summarize Note',
        description: 'Summarize the current note',
        prompt: 'Please summarize the following note:\n\n@note[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'research-topic',
        name: 'Research Topic',
        description: 'Deep research on a topic',
        prompt:
            'Conduct thorough research on the following topic and provide a comprehensive summary with key findings:\n\n{{topic}}',
        params: {
          'topic': SkillParam(
            name: 'topic',
            type: 'string',
            description: 'Topic to research',
            required: true,
          ),
        },
        isBuiltin: true,
      ),
      Skill(
        id: 'extract-key-points',
        name: 'Extract Key Points',
        description: 'Extract key points from content',
        prompt:
            'Extract the key points from the following content and format them as a bullet list:\n\n@note[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'generate-outline',
        name: 'Generate Outline',
        description: 'Generate an outline for a topic',
        prompt: 'Generate a detailed outline for the following topic:\n\n{{topic}}',
        params: {
          'topic': SkillParam(
            name: 'topic',
            type: 'string',
            description: 'Topic for the outline',
            required: true,
          ),
        },
        isBuiltin: true,
      ),
      Skill(
        id: 'auto-tag',
        name: 'Auto Tag',
        description: 'Automatically suggest tags for the current note',
        prompt:
            'Analyze the following note and suggest relevant tags. Return only the tags as a comma-separated list:\n\n@note[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'daily-review',
        name: 'Daily Review',
        description: 'Generate a daily review summary',
        prompt:
            "Review today's daily note and generate a summary of accomplishments and pending tasks:\n\n@note[daily]",
        isBuiltin: true,
      ),
    ];
  }
}

final noteServiceProvider = NotifierProvider<NoteNotifier, NoteState>(
  NoteNotifier.new,
);

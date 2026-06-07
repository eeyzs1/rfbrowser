import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:html2md/html2md.dart' as html2md;
import '../data/models/note.dart';
import '../data/models/skill.dart';
import '../data/models/web_clip.dart';
import '../data/stores/index_store.dart';
import '../data/stores/vault_store.dart';
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
        } catch (e) {
          debugPrint('NoteService: failed to load ${entity.path}: $e');
        }
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
    ref.read(pluginHostProvider.notifier).dispatchHook('note.saved', {
      'noteId': note.id,
      'title': note.title,
    });
  }

  Future<Note> createNote({required String title, String content = ''}) async {
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
    final newPath = dirName == '.'
        ? '$newFileName.md'
        : p.join(dirName, '$newFileName.md');

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
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return;
    final note = getNote(noteId);
    if (note == null) return;
    final fileName = p.basename(note.filePath);
    final newPath = folder.isEmpty ? fileName : p.join(folder, fileName);
    if (newPath == note.filePath) return;

    final oldFile = File(p.join(vault.path, note.filePath));
    final newFile = File(p.join(vault.path, newPath));
    if (await oldFile.exists()) {
      final newDir = Directory(p.dirname(newFile.path));
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }
      await oldFile.rename(newFile.path);
    }

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
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) throw StateError('No vault open');

    final fileName = _sanitizeFileName(title);
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

  Future<Directory> _ensureAttachmentsDir(String vaultPath) async {
    final dir = Directory(p.join(vaultPath, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> _saveRawHtml(
    String vaultPath,
    String htmlContent,
    String fileName,
  ) async {
    if (htmlContent.isEmpty) return null;
    try {
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final attachDir = await _ensureAttachmentsDir(vaultPath);
      final htmlFileName = '$fileName-$dateStr.html';
      final htmlFile = File(p.join(attachDir.path, htmlFileName));
      await htmlFile.writeAsString(htmlContent);
      return 'attachments/$htmlFileName';
    } catch (e) {
      debugPrint('NoteService: failed to save raw HTML: $e');
      return null;
    }
  }

  Future<String?> _saveScreenshot(
    String vaultPath,
    Uint8List screenshotData,
    String fileName,
  ) async {
    try {
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final attachDir = await _ensureAttachmentsDir(vaultPath);
      final imgFileName = '$fileName-$dateStr.jpg';
      final imgFile = File(p.join(attachDir.path, imgFileName));
      await imgFile.writeAsBytes(screenshotData);
      return 'attachments/$imgFileName';
    } catch (e) {
      debugPrint('NoteService: failed to save screenshot: $e');
      return null;
    }
  }

  Future<void> _saveWebClipMeta(String vaultPath, WebClip clip) async {
    try {
      final clipDir = Directory(p.join(vaultPath, '.rfbrowser', 'clips'));
      if (!await clipDir.exists()) {
        await clipDir.create(recursive: true);
      }
      final metaFile = File(p.join(clipDir.path, '${clip.id}.json'));
      await metaFile.writeAsString(clip.toJsonString());
    } catch (e) {
      debugPrint('NoteService: failed to save web clip meta: $e');
    }
  }

  Future<Note> clipFullPage({
    required String url,
    required String title,
    required String htmlContent,
    required String textContent,
    String? tabId,
  }) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) throw StateError('No vault open');

    final fileName = _sanitizeFileName(title);

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
      rawHtmlRelPath = await _saveRawHtml(vault.path, htmlContent, fileName);
    }

    if (tabId != null) {
      try {
        final screenshotData = await ref
            .read(browserProvider.notifier)
            .takeScreenshot(tabId);
        if (screenshotData != null) {
          screenshotRelPath = await _saveScreenshot(
            vault.path,
            screenshotData,
            fileName,
          );
        }
      } catch (e) {
        debugPrint('NoteService: screenshot capture failed: $e');
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
    await _saveWebClipMeta(vault.path, clip);

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
    skills.addAll(_getBuiltinSkills());
    skills.addAll(PluginRegistry.getAllPluginSkills());

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
          } catch (e) {
            debugPrint('NoteService: failed to load skill ${entity.path}: $e');
          }
        }
      }
    }
    return skills;
  }

  Future<void> createSkill(Skill skill) async {
    await updateSkill(skill);
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

  Future<void> updateSkill(Skill skill) async {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return;
    final skillDir = Directory(p.join(vault.path, '.rfbrowser', 'skills'));
    if (!await skillDir.exists()) {
      await skillDir.create(recursive: true);
    }
    final buffer = StringBuffer();
    buffer.writeln('id: ${skill.id}');
    buffer.writeln('name: ${skill.name}');
    buffer.writeln('description: ${skill.description}');
    buffer.writeln('prompt: |');
    for (final line in skill.prompt.split('\n')) {
      buffer.writeln('  $line');
    }
    if (skill.params.isNotEmpty) {
      buffer.writeln('params:');
      for (final param in skill.params.values) {
        buffer.writeln('  ${param.name}:');
        buffer.writeln('    type: ${param.type}');
        buffer.writeln('    description: ${param.description}');
        buffer.writeln('    required: ${param.required}');
        if (param.defaultValue != null) {
          buffer.writeln('    default: ${param.defaultValue}');
        }
      }
    }
    final file = File(p.join(skillDir.path, '${skill.id}.yaml'));
    await file.writeAsString(buffer.toString());
  }

  String _sanitizeFileName(String name) {
    var sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '-');
    sanitized = p.basename(p.normalize(sanitized));
    if (sanitized.isEmpty || sanitized == '.') sanitized = 'untitled';
    if (sanitized.length > 100) sanitized = sanitized.substring(0, 100);
    return sanitized;
  }

  List<Skill> _getBuiltinSkills() {
    return [
      Skill(
        id: 'summarize-page',
        name: 'Summarize Page',
        description: 'Summarize the current web page',
        prompt:
            'Please summarize the following web page content:\n\n@web[current]',
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
        prompt:
            'Generate a detailed outline for the following topic:\n\n{{topic}}',
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

import 'dart:io';
import '../../core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../models/note.dart';
import '../models/skill.dart';
import '../models/web_clip.dart';
import '../stores/vault_store.dart';
import 'repository_base.dart';

export 'repository_base.dart' show PathTraversalException;

class NoteRepository extends RepositoryBase {
  NoteRepository(super.vaultPath);

  Future<List<Note>> getAllNotes() async {
    final notes = <Note>[];
    final dir = Directory(vaultPath);
    if (!await dir.exists()) return notes;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        try {
          final canonical = entity.absolute.path;
          final vaultCanonical = Directory(vaultPath).absolute.path;
          if (!canonical.startsWith(vaultCanonical)) continue;

          final content = await entity.readAsString();
          final relativePath = p.relative(entity.path, from: vaultPath);
          final note = Note.fromMarkdown(relativePath, content);
          notes.add(note);
        } catch (_) {
          appLog.warning('NoteRepo: failed to parse note file: ${entity.path}');
        }
      }
    }
    return notes;
  }

  Future<Note?> getNoteByPath(String relativePath) async {
    final safePath = safeRelativePath(relativePath);
    validatePath(safePath);
    final filePath = p.join(vaultPath, safePath);
    final file = File(filePath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return Note.fromMarkdown(safePath, content);
  }

  Future<Note> createNote({
    required String title,
    String folder = '',
    String? template,
  }) async {
    final fileName = _sanitizeFileName(title);
    final safeFolder = safeRelativePath(folder);
    final relativePath = safeFolder.isEmpty
        ? '$fileName.md'
        : p.join(safeFolder, '$fileName.md');
    validatePath(relativePath);
    final filePath = p.join(vaultPath, relativePath);

    final dir = Directory(p.dirname(filePath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final note = Note(
      title: title,
      filePath: relativePath,
      content: '# $title\n\n',
    );

    final file = File(filePath);
    await file.writeAsString(note.toMarkdown());
    return note;
  }

  Future<void> saveNote(Note note) async {
    validatePath(note.filePath);
    final filePath = p.join(vaultPath, note.filePath);
    final file = File(filePath);
    final updatedNote = note.copyWith(modified: DateTime.now());
    // Ensure parent directory exists (e.g. `clippings/`, `daily-notes/`).
    final parent = Directory(p.dirname(filePath));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(updatedNote.toMarkdown());
  }

  Future<void> deleteNote(String relativePath) async {
    final safePath = safeRelativePath(relativePath);
    validatePath(safePath);
    final filePath = p.join(vaultPath, safePath);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Note> createDailyNote(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final relativePath = p.join('daily-notes', '$dateStr.md');
    final existing = await getNoteByPath(relativePath);
    if (existing != null) return existing;

    final note = Note(
      title: dateStr,
      filePath: relativePath,
      content: '# $dateStr\n\n',
      tags: ['daily-note'],
    );

    final filePath = p.join(vaultPath, relativePath);
    validatePath(relativePath);
    final dir = Directory(p.dirname(filePath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(filePath);
    await file.writeAsString(note.toMarkdown());
    return note;
  }

  Future<Note> clipToNote({
    required String url,
    required String title,
    required String content,
    String? selectedText,
  }) async {
    final fileName = _sanitizeFileName(title);
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final relativePath = p.join('clippings', '$fileName-$dateStr.md');
    validatePath(relativePath);

    final note = Note(
      title: title,
      filePath: relativePath,
      content:
          '# $title\n\n$content\n\n${selectedText != null ? '## Selected\n\n$selectedText\n' : ''}',
      sourceUrl: url,
      sourceTitle: title,
      tags: ['clipping'],
    );

    final filePath = p.join(vaultPath, relativePath);
    final dir = Directory(p.dirname(filePath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(filePath);
    await file.writeAsString(note.toMarkdown());
    return note;
  }

  String _sanitizeFileName(String name) {
    var sanitized = p.basename(name).replaceAll('..', '');
    sanitized = sanitized
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '-');
    if (sanitized.isEmpty ||
        sanitized == '.' ||
        sanitized == '-' ||
        sanitized == '_') {
      sanitized = 'untitled';
    }
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }
    return sanitized;
  }

  /// Public wrapper around [_sanitizeFileName] for callers (e.g. [NoteNotifier])
  /// that need to derive a safe filename without writing a file.
  String sanitizeFileName(String name) => _sanitizeFileName(name);

  /// Renames the file backing [oldPath] to a new path derived from [newName],
  /// preserving the existing folder. Returns the new relative path.
  Future<String> renameNoteFile(String oldPath, String newName) async {
    final safeOld = safeRelativePath(oldPath);
    validatePath(safeOld);
    final newFileName = _sanitizeFileName(newName);
    final dirName = p.dirname(safeOld);
    final newPath = dirName == '.'
        ? '$newFileName.md'
        : p.join(dirName, '$newFileName.md');
    validatePath(newPath);

    final oldFile = File(p.join(vaultPath, safeOld));
    final newFile = File(p.join(vaultPath, newPath));
    if (await oldFile.exists() && !await newFile.exists()) {
      await oldFile.rename(newFile.path);
    }
    return newPath;
  }

  /// Moves the note file at [noteFilePath] into [folder], returning the new
  /// relative path. Does nothing and returns the original path if the move
  /// would be a no-op.
  Future<String> moveNoteFile(String noteFilePath, String folder) async {
    final safeOld = safeRelativePath(noteFilePath);
    validatePath(safeOld);
    final fileName = p.basename(safeOld);
    final safeFolder = safeRelativePath(folder);
    final newPath = safeFolder.isEmpty ? fileName : p.join(safeFolder, fileName);
    if (newPath == safeOld) return safeOld;
    validatePath(newPath);

    final oldFile = File(p.join(vaultPath, safeOld));
    final newFile = File(p.join(vaultPath, newPath));
    if (await oldFile.exists()) {
      final newDir = Directory(p.dirname(newFile.path));
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }
      await oldFile.rename(newFile.path);
    }
    return newPath;
  }

  /// Ensures the attachments directory exists and returns it.
  Future<Directory> ensureAttachmentsDir() async {
    final dir = Directory(p.join(vaultPath, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves raw HTML to the attachments directory, returning the relative path
  /// (or null on failure / empty input).
  Future<String?> saveRawHtml(String htmlContent, String fileName) async {
    if (htmlContent.isEmpty) return null;
    try {
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final attachDir = await ensureAttachmentsDir();
      final htmlFileName = '$fileName-$dateStr.html';
      final htmlFile = File(p.join(attachDir.path, htmlFileName));
      await htmlFile.writeAsString(htmlContent);
      return 'attachments/$htmlFileName';
    } catch (e) {
      appLog.warning('NoteRepo: failed to save raw HTML', error: e);
      return null;
    }
  }

  /// Saves screenshot bytes to the attachments directory, returning the
  /// relative path (or null on failure).
  Future<String?> saveScreenshot(
    Uint8List screenshotData,
    String fileName,
  ) async {
    try {
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final attachDir = await ensureAttachmentsDir();
      final imgFileName = '$fileName-$dateStr.jpg';
      final imgFile = File(p.join(attachDir.path, imgFileName));
      await imgFile.writeAsBytes(screenshotData);
      return 'attachments/$imgFileName';
    } catch (e) {
      appLog.warning('NoteRepo: failed to save screenshot', error: e);
      return null;
    }
  }

  /// Persists [clip] metadata as JSON under `.rfbrowser/clips/`.
  Future<void> saveWebClipMeta(WebClip clip) async {
    try {
      final clipDir = Directory(p.join(vaultPath, '.rfbrowser', 'clips'));
      if (!await clipDir.exists()) {
        await clipDir.create(recursive: true);
      }
      final metaFile = File(p.join(clipDir.path, '${clip.id}.json'));
      await metaFile.writeAsString(clip.toJsonString());
    } catch (e) {
      appLog.warning('NoteRepo: failed to save web clip meta', error: e);
    }
  }

  /// Loads all skill YAML files from `.rfbrowser/skills/`.
  Future<List<Skill>> loadVaultSkills() async {
    final skills = <Skill>[];
    final skillDir = Directory(p.join(vaultPath, '.rfbrowser', 'skills'));
    if (!await skillDir.exists()) return skills;
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
          appLog.warning('NoteRepo: failed to load skill ${entity.path}', error: e);
        }
      }
    }
    return skills;
  }

  /// Writes [skill] to `.rfbrowser/skills/<id>.yaml`.
  Future<void> saveSkill(Skill skill) async {
    final skillDir = Directory(p.join(vaultPath, '.rfbrowser', 'skills'));
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

  /// Deletes `.rfbrowser/skills/<skillId>.yaml` if it exists.
  Future<void> deleteSkill(String skillId) async {
    final file = File(
      p.join(vaultPath, '.rfbrowser', 'skills', '$skillId.yaml'),
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  @visibleForTesting
  String normalizeRelativePath(String relativePath) =>
      safeRelativePath(relativePath);
}

final noteRepositoryProvider = Provider<NoteRepository?>((ref) {
  final vaultState = ref.watch(vaultProvider);
  if (vaultState.currentVault == null) return null;
  return NoteRepository(vaultState.currentVault!.path);
});

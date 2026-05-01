import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/note.dart';
import '../stores/vault_store.dart';

class PathTraversalException implements Exception {
  final String message;
  PathTraversalException(this.message);
  @override
  String toString() => 'PathTraversalException: $message';
}

class NoteRepository {
  final String vaultPath;

  NoteRepository(this.vaultPath);

  void _validatePath(String relativePath) {
    final canonical = File(p.join(vaultPath, relativePath)).absolute.path;
    final vaultCanonical = Directory(vaultPath).absolute.path;
    if (!canonical.startsWith(vaultCanonical)) {
      throw PathTraversalException('Path traversal detected: $relativePath');
    }
  }

  String _sanitizeRelativePath(String relativePath) {
    return relativePath.replaceAll('..', '').replaceAll(RegExp(r'[/\\]+'), '/');
  }

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
        } catch (_) {}
      }
    }
    return notes;
  }

  Future<Note?> getNoteByPath(String relativePath) async {
    final safePath = _sanitizeRelativePath(relativePath);
    _validatePath(safePath);
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
    final safeFolder = _sanitizeRelativePath(folder);
    final relativePath = safeFolder.isEmpty
        ? '$fileName.md'
        : p.join(safeFolder, '$fileName.md');
    _validatePath(relativePath);
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
    _validatePath(note.filePath);
    final filePath = p.join(vaultPath, note.filePath);
    final file = File(filePath);
    final updatedNote = note.copyWith(modified: DateTime.now());
    await file.writeAsString(updatedNote.toMarkdown());
  }

  Future<void> deleteNote(String relativePath) async {
    final safePath = _sanitizeRelativePath(relativePath);
    _validatePath(safePath);
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
    _validatePath(relativePath);
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
    _validatePath(relativePath);

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
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll('..', '')
        .substring(0, name.length > 100 ? 100 : name.length);
  }
}

final noteRepositoryProvider = Provider<NoteRepository?>((ref) {
  final vaultState = ref.watch(vaultProvider);
  if (vaultState.currentVault == null) return null;
  return NoteRepository(vaultState.currentVault!.path);
});

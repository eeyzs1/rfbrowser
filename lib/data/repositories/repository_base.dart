import 'dart:io';
import 'package:path/path.dart' as p;

/// Exception thrown when a path traversal attack is detected.
///
/// Moved here from [NoteRepository] so all repositories sharing
/// [RepositoryBase] can throw the same exception type.
class PathTraversalException implements Exception {
  final String message;
  PathTraversalException(this.message);

  @override
  String toString() => 'PathTraversalException: $message';
}

/// Base class for file-system-backed repositories that live inside a vault.
///
/// Provides path-validation utilities that prevent directory-traversal
/// attacks (e.g. `../../etc/passwd`). Concrete repositories extend this
/// class and add their own domain-specific CRUD methods.
///
/// ```dart
/// class NoteRepository extends RepositoryBase {
///   NoteRepository(super.vaultPath);
///
///   Future<Note?> getByPath(String relativePath) async {
///     final safe = safeRelativePath(relativePath); // validates + normalizes
///     final file = File(p.join(vaultPath, safe));
///     // ...
///   }
/// }
/// ```
abstract class RepositoryBase {
  /// Absolute path to the vault root directory.
  final String vaultPath;

  RepositoryBase(this.vaultPath);

  /// Validates that [relativePath], when joined with [vaultPath], does not
  /// escape the vault directory. Throws [PathTraversalException] on violation.
  void validatePath(String relativePath) {
    final normalized = p.normalize(relativePath);
    final combined = p.normalize(p.join(vaultPath, normalized));
    final vaultCanonical = Directory(vaultPath).absolute.path;
    if (!combined.startsWith(vaultCanonical)) {
      throw PathTraversalException('Path traversal detected: $relativePath');
    }
  }

  /// Normalizes [relativePath] and validates it is relative and inside the
  /// vault. Returns the normalized path (without leading `./`).
  ///
  /// Throws [PathTraversalException] if the path is absolute, starts with
  /// `..`, or escapes the vault.
  String safeRelativePath(String relativePath) {
    var normalized = p.normalize(relativePath);
    if (normalized == '.' || normalized == './') normalized = '';
    if (normalized.startsWith('..') || p.isAbsolute(normalized)) {
      throw PathTraversalException('Invalid relative path: $relativePath');
    }
    return normalized;
  }

  /// Joins [vaultPath] with [relativePath] after validation.
  ///
  /// Convenience method — equivalent to
  /// `p.join(vaultPath, safeRelativePath(relativePath))`.
  String safeJoin(String relativePath) {
    final safe = safeRelativePath(relativePath);
    return safe.isEmpty ? vaultPath : p.join(vaultPath, safe);
  }
}

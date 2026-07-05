import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/repositories/repository_base.dart';

/// Minimal concrete subclass for testing [RepositoryBase] in isolation.
class _TestRepo extends RepositoryBase {
  _TestRepo(super.vaultPath);
}

void main() {
  late String vaultPath;
  late _TestRepo repo;

  setUp(() {
    // Use an absolute path that works on both Windows and Unix.
    vaultPath = p.absolute(p.join(Directory.systemTemp.path, 'test_vault'));
    repo = _TestRepo(vaultPath);
  });

  group('PathTraversalException', () {
    test('stores message and formats toString', () {
      final exc = PathTraversalException('bad path');
      expect(exc.message, 'bad path');
      expect(exc.toString(), 'PathTraversalException: bad path');
    });

    test('implements Exception', () {
      final exc = PathTraversalException('x');
      expect(exc, isA<Exception>());
    });
  });

  group('validatePath', () {
    test('accepts a simple relative path', () {
      expect(() => repo.validatePath('notes/hello.md'), returnsNormally);
    });

    test('accepts nested subdirectories', () {
      expect(() => repo.validatePath('a/b/c/deep.md'), returnsNormally);
    });

    test('rejects parent traversal (../outside)', () {
      expect(
        () => repo.validatePath('../outside.md'),
        throwsA(isA<PathTraversalException>()),
      );
    });

    test('rejects traversal hidden inside subdirectories', () {
      expect(
        () => repo.validatePath('subdir/../../etc/passwd'),
        throwsA(isA<PathTraversalException>()),
      );
    });

    test('rejects absolute path (platform-aware)', () {
      final absolutePath = Platform.isWindows
          ? r'C:\Windows\system32\config'
          : '/etc/passwd';
      expect(
        () => repo.validatePath(absolutePath),
        throwsA(isA<PathTraversalException>()),
      );
    });

    test('accepts dot (current directory)', () {
      expect(() => repo.validatePath('.'), returnsNormally);
    });

    test('accepts empty string', () {
      expect(() => repo.validatePath(''), returnsNormally);
    });
  });

  group('safeRelativePath', () {
    test('returns a clean relative path as-is', () {
      // p.normalize may convert / to \ on Windows.
      expect(
        repo.safeRelativePath('notes/hello.md'),
        p.join('notes', 'hello.md'),
      );
    });

    test('normalizes ./ prefix', () {
      expect(
        repo.safeRelativePath('./notes/hello.md'),
        p.join('notes', 'hello.md'),
      );
    });

    test('normalizes single dot to empty string', () {
      expect(repo.safeRelativePath('.'), '');
    });

    test('normalizes ./ to empty string', () {
      expect(repo.safeRelativePath('./'), '');
    });

    test('collapses internal .. that stay within vault', () {
      // subdir/../file.md normalizes to file.md, which is still inside vault.
      expect(repo.safeRelativePath('subdir/../file.md'), 'file.md');
    });

    test('rejects leading .. (escapes vault)', () {
      expect(
        () => repo.safeRelativePath('../escape.md'),
        throwsA(isA<PathTraversalException>()),
      );
    });

    test('rejects absolute path', () {
      final absolutePath = Platform.isWindows ? r'C:\secret' : '/etc/shadow';
      expect(
        () => repo.safeRelativePath(absolutePath),
        throwsA(isA<PathTraversalException>()),
      );
    });

    test('rejects path that escapes after normalization', () {
      expect(
        () => repo.safeRelativePath('a/../../../escape'),
        throwsA(isA<PathTraversalException>()),
      );
    });
  });

  group('safeJoin', () {
    test('joins vault path with a relative path', () {
      final joined = repo.safeJoin('notes/hello.md');
      expect(joined, p.join(vaultPath, 'notes', 'hello.md'));
    });

    test('returns vaultPath for empty relative path', () {
      expect(repo.safeJoin(''), vaultPath);
    });

    test('returns vaultPath for dot', () {
      expect(repo.safeJoin('.'), vaultPath);
    });

    test('returns vaultPath for ./', () {
      expect(repo.safeJoin('./'), vaultPath);
    });

    test('normalizes ./ prefix before joining', () {
      final joined = repo.safeJoin('./notes/file.md');
      expect(joined, p.join(vaultPath, 'notes', 'file.md'));
    });

    test('throws for traversal path', () {
      expect(
        () => repo.safeJoin('../escape.md'),
        throwsA(isA<PathTraversalException>()),
      );
    });

    test('throws for absolute path', () {
      final absolutePath = Platform.isWindows
          ? r'D:\stolen'
          : '/root/.ssh/id_rsa';
      expect(
        () => repo.safeJoin(absolutePath),
        throwsA(isA<PathTraversalException>()),
      );
    });
  });

  group('vaultPath field', () {
    test('is accessible to subclasses', () {
      expect(repo.vaultPath, vaultPath);
    });
  });
}

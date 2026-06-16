import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/services/git_sync_service.dart';

Future<bool> _hasGitInstalled() async {
  try {
    final result = await Process.run('git', ['--version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

void main() {
  group('GitSyncService', () {
    late String vaultDir;
    late GitSyncService service;

    setUp(() async {
      vaultDir = p.join(
        Directory.systemTemp.path,
        'rfbrowser_test_git_${DateTime.now().millisecondsSinceEpoch}',
      );
      await Directory(vaultDir).create(recursive: true);
      service = GitSyncService(vaultDir);
    });

    tearDown(() async {
      if (Directory(vaultDir).existsSync()) {
        await Directory(vaultDir).delete(recursive: true);
      }
    });

    group('isGitRepo', () {
      test('returns false for non-git directory', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        expect(await service.isGitRepo(), isFalse);
      });

      test('returns true after init', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        expect(await service.isGitRepo(), isTrue);
      });
    });

    group('init', () {
      test('creates .git directory', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        expect(Directory(p.join(vaultDir, '.git')).existsSync(), isTrue);
      });

      test('creates .gitignore with cache and plugin paths', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        final gitignore = File(p.join(vaultDir, '.gitignore'));
        expect(await gitignore.exists(), isTrue);
        final content = await gitignore.readAsString();
        expect(content, contains('.rfbrowser/cache/'));
        expect(content, contains('.rfbrowser/plugins/'));
      });

      test('does not recreate .gitignore if already exists', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await File(p.join(vaultDir, '.gitignore')).writeAsString('custom');
        await service.init(null);
        final content = await File(
          p.join(vaultDir, '.gitignore'),
        ).readAsString();
        expect(content, 'custom');
      });

      test('adds remote origin when remoteUrl is provided', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init('https://example.com/repo.git');
        final result = await Process.run('git', [
          'remote',
          'get-url',
          'origin',
        ], workingDirectory: vaultDir);
        expect(result.stdout.toString().trim(), 'https://example.com/repo.git');
      });
    });

    group('autoCommit', () {
      test('commits changes in vault', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        await File(p.join(vaultDir, 'note.md')).writeAsString('# Hello');
        final state = await service.autoCommit();
        expect(state.status, SyncStatus.success);
        final log = await service.getLog(count: 1);
        expect(log, contains('auto: update notes'));
        expect(log, isNotEmpty);
      });

      test('handles no changes gracefully', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        final state = await service.autoCommit();
        expect(state.status, SyncStatus.success);
      });

      test('returns error for non-git directory', () async {
        final state = await service.autoCommit();
        expect(state.status, SyncStatus.error);
        expect(state.message, contains('Not a git repo'));
      });
    });

    group('getStatus', () {
      test('returns "Not a git repo" for non-git directory', () async {
        final result = await service.getStatus();
        expect(result, 'Not a git repo');
      });

      test('shows empty after commit', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        await File(p.join(vaultDir, 'note.md')).writeAsString('# Hello');
        await service.autoCommit();
        final status = await service.getStatus();
        expect(status, isEmpty);
      });

      test('shows untracked files', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        await File(p.join(vaultDir, 'new_note.md')).writeAsString('# New');
        final status = await service.getStatus();
        expect(status, isNotEmpty);
      });
    });

    group('getLog', () {
      test('returns empty for non-git directory', () async {
        final result = await service.getLog();
        expect(result, isEmpty);
      });

      test('returns commits with correct count', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        await File(p.join(vaultDir, 'a.md')).writeAsString('# A');
        await service.autoCommit(message: 'commit A');
        await File(p.join(vaultDir, 'b.md')).writeAsString('# B');
        await service.autoCommit(message: 'commit B');

        final log = await service.getLog(count: 2);
        final lines = log.split('\n').where((l) => l.isNotEmpty).toList();
        expect(lines.length, 2);
        expect(log, contains('commit B'));
        expect(log, contains('commit A'));
      });
    });

    group('push and pull', () {
      late String bareRepoDir;
      String cloneDir = '';
      late String remoteUrl;

      setUp(() async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        bareRepoDir = p.join(
          Directory.systemTemp.path,
          'rfbrowser_test_bare_${DateTime.now().millisecondsSinceEpoch}',
        );
        await Directory(bareRepoDir).create(recursive: true);
        await Process.run('git', ['init', '--bare', bareRepoDir]);
        remoteUrl = bareRepoDir.replaceAll('\\', '/');
      });

      tearDown(() async {
        if (bareRepoDir.isNotEmpty && Directory(bareRepoDir).existsSync()) {
          await Directory(bareRepoDir).delete(recursive: true);
        }
        if (cloneDir.isNotEmpty && Directory(cloneDir).existsSync()) {
          await Directory(cloneDir).delete(recursive: true);
        }
      });

      test('push fails when no remote configured', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        await File(p.join(vaultDir, 'note.md')).writeAsString('# Hello');
        final state = await service.push();
        expect(state.status, SyncStatus.error);
      });

      test('push succeeds to local bare repo', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(remoteUrl);
        await File(p.join(vaultDir, 'note.md')).writeAsString('# Pushed');
        final state = await service.push();
        expect(state.status, SyncStatus.success);
      });

      test('push then clone verifies integration', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;

        // 1. init vault + push to bare repo
        await service.init(remoteUrl);
        await File(
          p.join(vaultDir, 'integration.md'),
        ).writeAsString('# Integration');
        final pushState = await service.push(message: 'integration test');
        expect(pushState.status, SyncStatus.success);

        // 2. clone the bare repo to another dir
        cloneDir = p.join(
          Directory.systemTemp.path,
          'rfbrowser_test_clone_${DateTime.now().millisecondsSinceEpoch + 2}',
        );
        await Process.run('git', ['clone', remoteUrl, cloneDir]);
        expect(Directory(p.join(cloneDir, '.git')).existsSync(), isTrue);
        final clonedFile = File(p.join(cloneDir, 'integration.md'));
        expect(await clonedFile.exists(), isTrue);

        // 3. make a change in clone, push back
        await File(p.join(cloneDir, 'clone_note.md')).writeAsString('# Clone');
        await Process.run('git', ['add', '-A'], workingDirectory: cloneDir);
        await Process.run('git', [
          'commit',
          '-m',
          'clone note',
        ], workingDirectory: cloneDir);
        await Process.run('git', ['push'], workingDirectory: cloneDir);

        // 4. pull into our vault
        final pullState = await service.pull();
        expect(pullState.status, SyncStatus.success);
        expect(await File(p.join(vaultDir, 'clone_note.md')).exists(), isTrue);
      });

      test('pull returns error for non-git directory', () async {
        final state = await service.pull();
        expect(state.status, SyncStatus.error);
        expect(state.message, contains('Not a git repo'));
      });

      test('full integration: init → autoCommit → push → pull', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;

        // 1. init + push from vault
        await service.init(remoteUrl);
        await File(p.join(vaultDir, 'note_a.md')).writeAsString('# Note A');
        final pushState = await service.push(message: 'add note A');
        expect(pushState.status, SyncStatus.success);

        // 2. another clone: simulate collaborator pushing changes
        cloneDir = p.join(
          Directory.systemTemp.path,
          'rfbrowser_test_other_${DateTime.now().millisecondsSinceEpoch + 1}',
        );
        await Process.run('git', ['clone', remoteUrl, cloneDir]);
        await File(p.join(cloneDir, 'note_b.md')).writeAsString('# Note B');
        await Process.run('git', ['add', '-A'], workingDirectory: cloneDir);
        await Process.run('git', [
          'commit',
          '-m',
          'add note B',
        ], workingDirectory: cloneDir);
        await Process.run('git', ['push'], workingDirectory: cloneDir);

        // 3. vault makes a local change (no conflict expected)
        await File(p.join(vaultDir, 'note_c.md')).writeAsString('# Note C');
        await service.autoCommit(message: 'add note C');

        // 4. pull collaborator's change
        final pullState = await service.pull();
        expect(pullState.status, SyncStatus.success);
        expect(await File(p.join(vaultDir, 'note_b.md')).exists(), isTrue);
        expect(await File(p.join(vaultDir, 'note_c.md')).exists(), isTrue);
      });
    });

    group('non-git repo edge cases', () {
      test('pull returns error state for non-git directory', () async {
        final state = await service.pull();
        expect(state.status, SyncStatus.error);
        expect(state.message, contains('Not a git repo'));
      });

      test('push returns error state for non-git directory', () async {
        final state = await service.push();
        expect(state.status, SyncStatus.error);
        expect(state.message, contains('Not a git repo'));
      });
    });

    group('getRemoteUrl (G9-1)', () {
      test('returns null for non-git directory', () async {
        expect(await service.getRemoteUrl(), isNull);
      });

      test('returns null after init() without remoteUrl', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init(null);
        expect(await service.getRemoteUrl(), isNull);
      });

      test('returns the configured remote URL after init(url)', () async {
        final hasGit = await _hasGitInstalled();
        if (!hasGit) return;
        await service.init('https://example.com/vault.git');
        expect(await service.getRemoteUrl(), 'https://example.com/vault.git');
      });
    });
  });
}

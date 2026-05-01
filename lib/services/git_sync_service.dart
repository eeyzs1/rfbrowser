import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../data/stores/vault_store.dart';

enum SyncStatus { idle, syncing, success, conflict, error }

class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSync;

  SyncState({this.status = SyncStatus.idle, this.message, this.lastSync});

  SyncState copyWith({SyncStatus? status, String? message, DateTime? lastSync}) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

class GitSyncService {
  final String vaultPath;

  GitSyncService(this.vaultPath);

  Future<bool> isGitRepo() async {
    final gitDir = Directory(p.join(vaultPath, '.git'));
    return gitDir.exists();
  }

  Future<void> init(String? remoteUrl) async {
    if (!await isGitRepo()) {
      await _runGit(['init']);
    }
    final gitignore = File(p.join(vaultPath, '.gitignore'));
    if (!await gitignore.exists()) {
      await gitignore.writeAsString('.rfbrowser/cache/\n.rfbrowser/plugins/\n');
    }
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      try {
        await _runGit(['remote', 'add', 'origin', remoteUrl]);
      } catch (_) {
        await _runGit(['remote', 'set-url', 'origin', remoteUrl]);
      }
    }
  }

  Future<SyncState> pull() async {
    try {
      if (!await isGitRepo()) return SyncState(status: SyncStatus.error, message: 'Not a git repo');
      final result = await _runGit(['pull', '--rebase']);
      return SyncState(
        status: result.exitCode == 0 ? SyncStatus.success : SyncStatus.conflict,
        message: result.stdout.toString().trim(),
        lastSync: DateTime.now(),
      );
    } catch (e) {
      return SyncState(status: SyncStatus.error, message: e.toString());
    }
  }

  Future<SyncState> push({String message = 'auto: update notes'}) async {
    try {
      if (!await isGitRepo()) return SyncState(status: SyncStatus.error, message: 'Not a git repo');
      await _runGit(['add', '-A']);
      await _runGit(['commit', '-m', message]);
      final result = await _runGit(['push']);
      return SyncState(
        status: result.exitCode == 0 ? SyncStatus.success : SyncStatus.error,
        message: result.stdout.toString().trim(),
        lastSync: DateTime.now(),
      );
    } catch (e) {
      return SyncState(status: SyncStatus.error, message: e.toString());
    }
  }

  Future<SyncState> autoCommit({String message = 'auto: update notes'}) async {
    try {
      if (!await isGitRepo()) return SyncState(status: SyncStatus.error, message: 'Not a git repo');
      await _runGit(['add', '-A']);
      try {
        await _runGit(['commit', '-m', message]);
      } catch (_) {}
      return SyncState(status: SyncStatus.success, lastSync: DateTime.now());
    } catch (e) {
      return SyncState(status: SyncStatus.error, message: e.toString());
    }
  }

  Future<String> getStatus() async {
    if (!await isGitRepo()) return 'Not a git repo';
    final result = await _runGit(['status', '--short']);
    return result.stdout.toString().trim();
  }

  Future<String> getLog({int count = 10}) async {
    if (!await isGitRepo()) return '';
    final result = await _runGit(['log', '--oneline', '-n', count.toString()]);
    return result.stdout.toString().trim();
  }

  Future<ProcessResult> _runGit(List<String> args) async {
    return Process.run('git', args, workingDirectory: vaultPath);
  }
}

final gitSyncProvider = Provider<GitSyncService?>((ref) {
  final vaultState = ref.watch(vaultProvider);
  if (vaultState.currentVault == null) return null;
  return GitSyncService(vaultState.currentVault!.path);
});

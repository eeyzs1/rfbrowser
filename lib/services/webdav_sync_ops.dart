part of 'webdav_sync_service.dart';

/// Sync operation methods for [WebDAVSyncNotifier].
///
/// Contains the core download/upload/resolve-conflict workflows. Declares
/// abstract bridges for the host class's private [_syncStore] and the
/// remote-file helpers so the mixin can invoke them without accessing
/// private members directly.
mixin _WebDAVSyncOpsMixin on Notifier<WebDAVSyncState> {
  /// Bridge to the host's private `SyncStore`.
  SyncStore get syncStore;

  // ── Remote-file helpers (implemented by the host class) ──────────
  Future<List<RemoteFileInfo>> listRemoteFiles(String remotePath);
  Future<String?> downloadFile(String remotePath);
  Future<void> uploadFile(String remotePath, String content);
  Future<void> ensureRemoteDir(String path);

  Future<SyncResult> downloadChanges({
    required String vaultPath,
    required String remoteBasePath,
  }) async {
    await syncStore.load();
    final remoteFiles = await listRemoteFiles(remoteBasePath);
    var downloaded = 0;
    final conflicts = <SyncConflict>[];

    state = state.copyWith(
      status: SyncStatus.syncing,
      progress: SyncProgress(
        totalFiles: remoteFiles.length,
        isUploading: false,
      ),
    );

    for (var i = 0; i < remoteFiles.length; i++) {
      final remote = remoteFiles[i];
      final fileName = _extractFileName(remote.href);
      final relativePath = '$remoteBasePath/$fileName';
      final localPath = '$vaultPath/$fileName';

      final storedEtag = syncStore.getEtag(relativePath);
      if (storedEtag != null && storedEtag == remote.etag) continue;

      final localFile = File(localPath);
      if (await localFile.exists()) {
        final localModified = await localFile.lastModified();
        final syncMeta = syncStore.getMeta(relativePath);
        final wasSyncedBefore = syncMeta?.lastSynced != null;
        final localChangedSinceSync =
            wasSyncedBefore && localModified.isAfter(syncMeta!.lastSynced!);

        if (localChangedSinceSync) {
          conflicts.add(
            SyncConflict(
              relativePath: relativePath,
              localModified: localModified,
              remoteModified: remote.lastModified,
            ),
          );
          continue;
        }
      }

      final content = await downloadFile(relativePath);
      if (content != null) {
        await File(localPath).writeAsString(content);
        await syncStore.setMeta(
          SyncMeta(
            relativePath: relativePath,
            etag: remote.etag,
            lastSynced: DateTime.now(),
          ),
        );
        downloaded++;
      }

      state = state.copyWith(
        progress: SyncProgress(
          filesProcessed: i + 1,
          totalFiles: remoteFiles.length,
          currentFile: fileName,
          isUploading: false,
        ),
      );
    }

    if (conflicts.isNotEmpty) {
      state = state.copyWith(status: SyncStatus.conflict, conflicts: conflicts);
    } else {
      state = state.copyWith(status: SyncStatus.success);
    }

    return SyncResult(downloaded: downloaded, conflicts: conflicts);
  }

  Future<SyncResult> uploadChanges({
    required String vaultPath,
    required String remoteBasePath,
  }) async {
    await syncStore.load();
    final dir = Directory(vaultPath);
    if (!await dir.exists()) {
      return SyncResult(downloaded: 0, conflicts: []);
    }

    final mdFiles = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        final relative = entity.path
            .replaceFirst(vaultPath, '')
            .replaceAll('\\', '/');
        if (relative.contains('.rfbrowser')) continue;
        mdFiles.add(entity);
      }
    }

    var uploaded = 0;
    state = state.copyWith(
      status: SyncStatus.syncing,
      progress: SyncProgress(totalFiles: mdFiles.length, isUploading: true),
    );

    await ensureRemoteDir(remoteBasePath);

    for (var i = 0; i < mdFiles.length; i++) {
      final file = mdFiles[i];
      final relative = file.path
          .replaceFirst(vaultPath, '')
          .replaceAll('\\', '/');
      final remotePath = '$remoteBasePath$relative';

      final lastSynced = syncStore.getLastSynced(relative);
      final localModified = await file.lastModified();

      if (lastSynced != null && !localModified.isAfter(lastSynced)) continue;

      final content = await file.readAsString();
      await uploadFile(remotePath, content);
      await syncStore.setMeta(
        SyncMeta(
          relativePath: relative,
          lastSynced: DateTime.now(),
          localModified: localModified,
        ),
      );
      uploaded++;

      state = state.copyWith(
        progress: SyncProgress(
          filesProcessed: i + 1,
          totalFiles: mdFiles.length,
          currentFile: relative,
          isUploading: true,
        ),
      );
    }

    state = state.copyWith(status: SyncStatus.success);
    return SyncResult(downloaded: uploaded, conflicts: []);
  }

  Future<void> resolveConflict(
    String relativePath,
    ConflictResolution resolution, {
    String? vaultPath,
    String? remoteBasePath,
  }) async {
    final conflict = state.conflicts
        .where((c) => c.relativePath == relativePath)
        .firstOrNull;
    if (conflict == null) return;

    switch (resolution) {
      case ConflictResolution.keepLocal:
        if (vaultPath != null && remoteBasePath != null) {
          final fileName = relativePath.split('/').last;
          final localFile = File('$vaultPath/$fileName');
          if (await localFile.exists()) {
            final content = await localFile.readAsString();
            await uploadFile(relativePath, content);
          }
        }
        break;
      case ConflictResolution.keepRemote:
        final content = await downloadFile(relativePath);
        if (content != null && vaultPath != null) {
          final fileName = relativePath.split('/').last;
          await File('$vaultPath/$fileName').writeAsString(content);
        }
        break;
      case ConflictResolution.keepBoth:
        if (vaultPath != null) {
          final fileName = relativePath.split('/').last;
          final baseName = fileName.replaceAll('.md', '');
          final conflictCopy = '$vaultPath/$baseName (conflict copy).md';
          final localFile = File('$vaultPath/$fileName');
          if (await localFile.exists()) {
            await localFile.copy(conflictCopy);
          }
          final remoteContent = await downloadFile(relativePath);
          if (remoteContent != null) {
            await localFile.writeAsString(remoteContent);
          }
        }
        break;
    }

    await syncStore.setMeta(
      SyncMeta(relativePath: relativePath, lastSynced: DateTime.now()),
    );

    final remaining = state.conflicts
        .where((c) => c.relativePath != relativePath)
        .toList();
    state = state.copyWith(
      conflicts: remaining,
      status: remaining.isEmpty ? SyncStatus.success : SyncStatus.conflict,
    );
  }
}

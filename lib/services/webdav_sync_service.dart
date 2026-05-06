import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/stores/sync_store.dart';
import '../data/models/sync_conflict.dart';

enum SyncStatus { idle, syncing, success, conflict, error }

class WebDAVSyncState {
  final SyncStatus status;
  final SyncProgress? progress;
  final List<SyncConflict> conflicts;
  final String? error;
  final String? serverUrl;
  final String? username;
  final bool isPasswordSet;
  final Duration autoSyncInterval;
  final bool autoSyncEnabled;

  WebDAVSyncState({
    this.status = SyncStatus.idle,
    this.progress,
    this.conflicts = const [],
    this.error,
    this.serverUrl,
    this.username,
    this.isPasswordSet = false,
    this.autoSyncInterval = const Duration(minutes: 5),
    this.autoSyncEnabled = false,
  });

  WebDAVSyncState copyWith({
    SyncStatus? status,
    SyncProgress? progress,
    List<SyncConflict>? conflicts,
    String? error,
    bool clearError = false,
    String? serverUrl,
    String? username,
    bool? isPasswordSet,
    Duration? autoSyncInterval,
    bool? autoSyncEnabled,
  }) {
    return WebDAVSyncState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      conflicts: conflicts ?? this.conflicts,
      error: clearError ? null : (error ?? this.error),
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      isPasswordSet: isPasswordSet ?? this.isPasswordSet,
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }
}

class WebDAVSyncNotifier extends Notifier<WebDAVSyncState> {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
  final SyncStore _syncStore = SyncStore();
  final _secureStorage = const FlutterSecureStorage();
  Timer? _autoSyncTimer;

  @override
  WebDAVSyncState build() {
    _secureStorage.read(key: 'webdav_password').then((pwd) {
      if (pwd != null && pwd.isNotEmpty) {
        _cachedPassword = pwd;
        state = state.copyWith(isPasswordSet: true);
      }
    });
    return WebDAVSyncState();
  }

  Options get _authOptions => Options(
    headers: {
      'Authorization':
          'Basic ${_encodeCredentials(state.username ?? '', _getPasswordSync())}',
    },
  );

  String _getPasswordSync() {
    return _cachedPassword ?? '';
  }

  String? _cachedPassword;

  String _encodeCredentials(String username, String password) {
    return base64Encode('$username:$password'.codeUnits);
  }

  void configure({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    _cachedPassword = password;
    _secureStorage.write(key: 'webdav_password', value: password);
    state = state.copyWith(
      serverUrl: serverUrl.replaceAll(RegExp(r'/$'), ''),
      username: username,
      isPasswordSet: password.isNotEmpty,
    );
  }

  Future<bool> testConnection() async {
    if (state.serverUrl == null) return false;
    try {
      await _dio.request(
        state.serverUrl!,
        options: Options(method: 'PROPFIND', headers: _authOptions.headers),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureRemoteDir(String path) async {
    if (state.serverUrl == null) return;
    try {
      await _dio.request(
        '${state.serverUrl}$path',
        options: Options(method: 'MKCOL', headers: _authOptions.headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 405) rethrow;
    }
  }

  Future<List<RemoteFileInfo>> listRemoteFiles(String remotePath) async {
    if (state.serverUrl == null) return [];
    try {
      final response = await _dio.request(
        '${state.serverUrl}$remotePath',
        options: Options(
          method: 'PROPFIND',
          headers: {
            ...?_authOptions.headers,
            'Depth': '1',
            'Content-Type': 'application/xml',
          },
        ),
        data: '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:getlastmodified/>
    <d:getetag/>
  </d:prop>
</d:propfind>''',
      );

      final files = <RemoteFileInfo>[];
      final body = response.data;
      if (body is! String) return files;

      final hrefRegex = RegExp(r'<d:href>([^<]+)</d:href>');
      final etagRegex = RegExp(r'<d:getetag>([^<]*)</d:getetag>');
      final modifiedRegex = RegExp(r'<d:getlastmodified>([^<]*)</d:getlastmodified>');

      final hrefs = hrefRegex.allMatches(body).toList();
      final etags = etagRegex.allMatches(body).toList();
      final modifieds = modifiedRegex.allMatches(body).toList();

      for (var i = 1; i < hrefs.length; i++) {
        final href = hrefs[i].group(1) ?? '';
        if (!href.endsWith('.md')) continue;
        final etag = i < etags.length ? etags[i].group(1) : null;
        final modified = i < modifieds.length ? modifieds[i].group(1) : null;
        files.add(RemoteFileInfo(
          href: href,
          etag: etag,
          lastModified: modified != null ? _parseHttpDate(modified) : null,
        ));
      }

      return files;
    } catch (_) {
      return [];
    }
  }

  DateTime? _parseHttpDate(String dateStr) {
    return DateTime.tryParse(dateStr);
  }

  Future<String?> downloadFile(String remotePath) async {
    if (state.serverUrl == null) return null;
    try {
      final response = await _dio.get(
        '${state.serverUrl}$remotePath',
        options: Options(headers: _authOptions.headers, responseType: ResponseType.plain),
      );
      return response.data?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadFile(String remotePath, String content) async {
    if (state.serverUrl == null) return;
    await _dio.put(
      '${state.serverUrl}$remotePath',
      data: content,
      options: Options(headers: _authOptions.headers),
    );
  }

  Future<SyncResult> downloadChanges({
    required String vaultPath,
    required String remoteBasePath,
  }) async {
    await _syncStore.load();
    final remoteFiles = await listRemoteFiles(remoteBasePath);
    var downloaded = 0;
    final conflicts = <SyncConflict>[];

    state = state.copyWith(
      status: SyncStatus.syncing,
      progress: SyncProgress(totalFiles: remoteFiles.length, isUploading: false),
    );

    for (var i = 0; i < remoteFiles.length; i++) {
      final remote = remoteFiles[i];
      final fileName = _extractFileName(remote.href);
      final relativePath = '$remoteBasePath/$fileName';
      final localPath = '$vaultPath/$fileName';

      final storedEtag = _syncStore.getEtag(relativePath);
      if (storedEtag != null && storedEtag == remote.etag) continue;

      final localFile = File(localPath);
      if (await localFile.exists()) {
        final localModified = await localFile.lastModified();
        final syncMeta = _syncStore.getMeta(relativePath);
        final wasSyncedBefore = syncMeta?.lastSynced != null;
        final localChangedSinceSync = wasSyncedBefore &&
            localModified.isAfter(syncMeta!.lastSynced!);

        if (localChangedSinceSync) {
          conflicts.add(SyncConflict(
            relativePath: relativePath,
            localModified: localModified,
            remoteModified: remote.lastModified,
          ));
          continue;
        }
      }

      final content = await downloadFile(relativePath);
      if (content != null) {
        await File(localPath).writeAsString(content);
        await _syncStore.setMeta(SyncMeta(
          relativePath: relativePath,
          etag: remote.etag,
          lastSynced: DateTime.now(),
        ));
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
    await _syncStore.load();
    final dir = Directory(vaultPath);
    if (!await dir.exists()) {
      return SyncResult(downloaded: 0, conflicts: []);
    }

    final mdFiles = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        final relative = entity.path.replaceFirst(vaultPath, '').replaceAll('\\', '/');
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
      final relative = file.path.replaceFirst(vaultPath, '').replaceAll('\\', '/');
      final remotePath = '$remoteBasePath$relative';

      final lastSynced = _syncStore.getLastSynced(relative);
      final localModified = await file.lastModified();

      if (lastSynced != null && !localModified.isAfter(lastSynced)) continue;

      final content = await file.readAsString();
      await uploadFile(remotePath, content);
      await _syncStore.setMeta(SyncMeta(
        relativePath: relative,
        lastSynced: DateTime.now(),
        localModified: localModified,
      ));
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
    final conflict = state.conflicts.where(
      (c) => c.relativePath == relativePath,
    ).firstOrNull;
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

    await _syncStore.setMeta(SyncMeta(
      relativePath: relativePath,
      lastSynced: DateTime.now(),
    ));

    final remaining = state.conflicts
        .where((c) => c.relativePath != relativePath)
        .toList();
    state = state.copyWith(
      conflicts: remaining,
      status: remaining.isEmpty ? SyncStatus.success : SyncStatus.conflict,
    );
  }

  void setAutoSync(bool enabled, {Duration? interval}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;

    state = state.copyWith(
      autoSyncEnabled: enabled,
      autoSyncInterval: interval ?? state.autoSyncInterval,
    );

    if (enabled) {
      _autoSyncTimer = Timer.periodic(state.autoSyncInterval, (_) {
        // Auto sync would trigger here
      });
    }
  }

  bool get isAutoSyncActive => _autoSyncTimer?.isActive ?? false;
}

class RemoteFileInfo {
  final String href;
  final String? etag;
  final DateTime? lastModified;

  RemoteFileInfo({required this.href, this.etag, this.lastModified});
}

class SyncResult {
  final int downloaded;
  final List<SyncConflict> conflicts;

  SyncResult({required this.downloaded, required this.conflicts});
}

final webdavSyncProvider = NotifierProvider<WebDAVSyncNotifier, WebDAVSyncState>(
  WebDAVSyncNotifier.new,
);

String _extractFileName(String href) {
  final parts = href.split('/');
  return parts.where((p) => p.isNotEmpty).lastOrNull ?? 'unknown.md';
}

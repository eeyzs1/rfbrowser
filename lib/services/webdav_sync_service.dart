import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/stores/sync_store.dart';
import '../data/models/sync_conflict.dart';
import 'sync/models/sync_status.dart';

export 'sync/models/sync_status.dart';

part 'webdav_sync_ops.dart';

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

class WebDAVSyncNotifier extends Notifier<WebDAVSyncState>
    with _WebDAVSyncOpsMixin {
  final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 30)),
  );
  final SyncStore _syncStore = SyncStore();
  final _secureStorage = const FlutterSecureStorage();
  Timer? _autoSyncTimer;

  @override
  SyncStore get syncStore => _syncStore;

  @override
  WebDAVSyncState build() {
    ref.onDispose(() {
      _autoSyncTimer?.cancel();
      _dio.close();
    });
    _secureStorage
        .read(key: 'webdav_password')
        .then((pwd) {
          if (pwd != null && pwd.isNotEmpty) {
            _cachedPassword = pwd;
            state = state.copyWith(isPasswordSet: true);
          }
        })
        .catchError((_) {
          // Secure storage read failure is non-fatal — password simply stays unset.
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

  @override
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

  @override
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
      final modifiedRegex = RegExp(
        r'<d:getlastmodified>([^<]*)</d:getlastmodified>',
      );

      final hrefs = hrefRegex.allMatches(body).toList();
      final etags = etagRegex.allMatches(body).toList();
      final modifieds = modifiedRegex.allMatches(body).toList();

      for (var i = 1; i < hrefs.length; i++) {
        final href = hrefs[i].group(1) ?? '';
        if (!href.endsWith('.md')) continue;
        final etag = i < etags.length ? etags[i].group(1) : null;
        final modified = i < modifieds.length ? modifieds[i].group(1) : null;
        files.add(
          RemoteFileInfo(
            href: href,
            etag: etag,
            lastModified: modified != null ? _parseHttpDate(modified) : null,
          ),
        );
      }

      return files;
    } catch (_) {
      return [];
    }
  }

  DateTime? _parseHttpDate(String dateStr) {
    return DateTime.tryParse(dateStr);
  }

  @override
  Future<String?> downloadFile(String remotePath) async {
    if (state.serverUrl == null) return null;
    try {
      final response = await _dio.get(
        '${state.serverUrl}$remotePath',
        options: Options(
          headers: _authOptions.headers,
          responseType: ResponseType.plain,
        ),
      );
      return response.data?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> uploadFile(String remotePath, String content) async {
    if (state.serverUrl == null) return;
    await _dio.put(
      '${state.serverUrl}$remotePath',
      data: content,
      options: Options(headers: _authOptions.headers),
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

final webdavSyncProvider =
    NotifierProvider<WebDAVSyncNotifier, WebDAVSyncState>(
      WebDAVSyncNotifier.new,
    );

String _extractFileName(String href) {
  final parts = href.split('/');
  return parts.where((p) => p.isNotEmpty).lastOrNull ?? 'unknown.md';
}

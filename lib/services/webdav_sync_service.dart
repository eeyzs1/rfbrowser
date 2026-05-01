import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/stores/vault_store.dart';

enum WebdavSyncStatus { idle, syncing, success, conflict, error }

class WebdavSyncState {
  final WebdavSyncStatus status;
  final String? message;
  final DateTime? lastSync;

  WebdavSyncState({
    this.status = WebdavSyncStatus.idle,
    this.message,
    this.lastSync,
  });

  WebdavSyncState copyWith({
    WebdavSyncStatus? status,
    String? message,
    DateTime? lastSync,
  }) {
    return WebdavSyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

class WebdavSyncService {
  final String vaultPath;
  final Dio _dio = Dio();

  String? _serverUrl;
  String? _username;
  String? _password;

  WebdavSyncService(this.vaultPath);

  void configure(String serverUrl, String username, String password) {
    _serverUrl = serverUrl.replaceAll(RegExp(r'/$'), '');
    _username = username;
    _password = password;
  }

  bool get isConfigured =>
      _serverUrl != null && _username != null && _password != null;

  Future<WebdavSyncState> sync() async {
    if (!isConfigured) {
      return WebdavSyncState(
        status: WebdavSyncStatus.error,
        message: 'WebDAV not configured',
      );
    }

    try {
      final remotePath = '$_serverUrl/rfbrowser-vault/';
      await _ensureRemoteDir(remotePath);
      await _uploadChanges(remotePath);
      await _downloadChanges(remotePath);
      return WebdavSyncState(
        status: WebdavSyncStatus.success,
        lastSync: DateTime.now(),
      );
    } catch (e) {
      return WebdavSyncState(
        status: WebdavSyncStatus.error,
        message: e.toString(),
      );
    }
  }

  Future<void> _ensureRemoteDir(String path) async {
    try {
      await _dio.request(
        path,
        options: Options(method: 'MKCOL', headers: _authHeaders()),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 405) rethrow;
    }
  }

  Future<void> _uploadChanges(String remotePath) async {
    final vaultDir = Directory(vaultPath);
    await for (final entity in vaultDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        final relativePath = entity.path
            .substring(vaultPath.length + 1)
            .replaceAll('\\', '/');
        if (relativePath.startsWith('.rfbrowser/')) continue;
        final url = '$remotePath$relativePath';
        final content = await entity.readAsString();
        await _dio.put(
          url,
          data: content,
          options: Options(
            headers: {..._authHeaders(), 'Content-Type': 'text/markdown'},
          ),
        );
      }
    }
  }

  Future<void> _downloadChanges(String remotePath) async {
    try {
      await _dio.request(
        remotePath,
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._authHeaders(),
            'Depth': '1',
            'Content-Type': 'application/xml',
          },
        ),
      );
    } catch (_) {}
  }

  Map<String, String> _authHeaders() {
    if (_username == null || _password == null) return {};
    final credentials = base64Encode('$_username:$_password'.codeUnits);
    return {'Authorization': 'Basic $credentials'};
  }
}

final webdavSyncProvider = Provider<WebdavSyncService?>((ref) {
  final vaultState = ref.watch(vaultProvider);
  if (vaultState.currentVault == null) return null;
  return WebdavSyncService(vaultState.currentVault!.path);
});

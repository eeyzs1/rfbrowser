import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncMeta {
  final String relativePath;
  final String? etag;
  final DateTime? lastSynced;
  final DateTime? localModified;

  SyncMeta({
    required this.relativePath,
    this.etag,
    this.lastSynced,
    this.localModified,
  });

  SyncMeta copyWith({
    String? relativePath,
    String? etag,
    DateTime? lastSynced,
    DateTime? localModified,
  }) {
    return SyncMeta(
      relativePath: relativePath ?? this.relativePath,
      etag: etag ?? this.etag,
      lastSynced: lastSynced ?? this.lastSynced,
      localModified: localModified ?? this.localModified,
    );
  }

  Map<String, dynamic> toJson() => {
    'relativePath': relativePath,
    'etag': etag,
    'lastSynced': lastSynced?.toIso8601String(),
    'localModified': localModified?.toIso8601String(),
  };

  factory SyncMeta.fromJson(Map<String, dynamic> json) => SyncMeta(
    relativePath: json['relativePath'] as String,
    etag: json['etag'] as String?,
    lastSynced: json['lastSynced'] != null
        ? DateTime.parse(json['lastSynced'] as String)
        : null,
    localModified: json['localModified'] != null
        ? DateTime.parse(json['localModified'] as String)
        : null,
  );
}

class SyncStore {
  SharedPreferences? _prefs;
  Map<String, SyncMeta> _meta = {};
  final bool _inMemoryOnly;

  SyncStore({bool inMemoryOnly = false}) : _inMemoryOnly = inMemoryOnly;

  Future<SharedPreferences> get prefs async {
    if (_inMemoryOnly) throw UnsupportedError('In-memory only store');
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> load() async {
    if (_inMemoryOnly) return;
    final p = await prefs;
    final json = p.getString('rfbrowser_sync_meta');
    if (json != null) {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _meta = decoded.map(
        (k, v) => MapEntry(k, SyncMeta.fromJson(v as Map<String, dynamic>)),
      );
    }
  }

  Future<void> save() async {
    if (_inMemoryOnly) return;
    final p = await prefs;
    final encoded = jsonEncode(_meta.map((k, v) => MapEntry(k, v.toJson())));
    await p.setString('rfbrowser_sync_meta', encoded);
  }

  SyncMeta? getMeta(String relativePath) => _meta[relativePath];

  Future<void> setMeta(SyncMeta meta) async {
    _meta[meta.relativePath] = meta;
    await save();
  }

  Future<void> removeMeta(String relativePath) async {
    _meta.remove(relativePath);
    await save();
  }

  String? getEtag(String relativePath) => _meta[relativePath]?.etag;

  DateTime? getLastSynced(String relativePath) =>
      _meta[relativePath]?.lastSynced;

  DateTime? getLocalModified(String relativePath) =>
      _meta[relativePath]?.localModified;
}

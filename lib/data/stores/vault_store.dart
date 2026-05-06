import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class VaultConfig {
  final String path;
  final String name;
  final DateTime lastOpened;

  VaultConfig({
    required this.path,
    required this.name,
    required this.lastOpened,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'lastOpened': lastOpened.toIso8601String(),
  };

  factory VaultConfig.fromJson(Map<String, dynamic> json) => VaultConfig(
    path: json['path'] as String,
    name: json['name'] as String,
    lastOpened: DateTime.parse(json['lastOpened'] as String),
  );
}

class VaultState {
  final VaultConfig? currentVault;
  final List<VaultConfig> recentVaults;
  final bool isLoading;
  final String? error;

  VaultState({
    this.currentVault,
    this.recentVaults = const [],
    this.isLoading = false,
    this.error,
  });

  VaultState copyWith({
    VaultConfig? currentVault,
    List<VaultConfig>? recentVaults,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearCurrentVault = false,
  }) {
    return VaultState(
      currentVault: clearCurrentVault
          ? null
          : (currentVault ?? this.currentVault),
      recentVaults: recentVaults ?? this.recentVaults,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VaultNotifier extends Notifier<VaultState> {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  VaultState build() => VaultState();

  static const _recentVaultsKey = 'recent_vaults';
  static const _currentVaultKey = 'current_vault';

  Future<void> loadRecentVaults() async {
    final prefs = await _ensurePrefs;
    final vaultsJson = prefs.getStringList(_recentVaultsKey) ?? [];
    final seen = <String>{};
    final vaults = vaultsJson
        .map((j) {
          try {
            return VaultConfig.fromJson(
              Map<String, dynamic>.from(jsonDecode(j)),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<VaultConfig>()
        .where((v) => seen.add(_normalizePath(v.path)))
        .toList();

    if (vaults.length != vaultsJson.length) {
      final dedupedJson = vaults.map((v) => jsonEncode(v.toJson())).toList();
      await prefs.setStringList(_recentVaultsKey, dedupedJson);
    }

    VaultConfig? currentVault;
    final currentVaultPath = prefs.getString(_currentVaultKey);
    if (currentVaultPath != null) {
      try {
        currentVault = vaults.firstWhere(
          (v) => _normalizePath(v.path) == _normalizePath(currentVaultPath),
        );
      } catch (_) {
        await prefs.remove(_currentVaultKey);
      }
    }

    state = state.copyWith(recentVaults: vaults, currentVault: currentVault);
  }

  String _normalizePath(String path) =>
      p.normalize(p.absolute(path));

  Future<void> openVault(String vaultPath) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dir = Directory(vaultPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final rfbrowserDir = Directory(p.join(vaultPath, '.rfbrowser'));
      if (!await rfbrowserDir.exists()) {
        await rfbrowserDir.create(recursive: true);
      }

      final subdirs = [
        'cache',
        'plugins',
        'skills',
        'templates',
        'themes',
        'sync',
      ];
      for (final subdir in subdirs) {
        final d = Directory(p.join(rfbrowserDir.path, subdir));
        if (!await d.exists()) {
          await d.create(recursive: true);
        }
      }

      final vaultName = p.basename(vaultPath);
      final config = VaultConfig(
        path: vaultPath,
        name: vaultName,
        lastOpened: DateTime.now(),
      );

      await _saveToRecent(config);

      state = state.copyWith(currentVault: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createVault(String vaultPath, {String name = ''}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dir = Directory(vaultPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final subdirs = ['daily-notes', 'clippings', 'attachments'];
      for (final subdir in subdirs) {
        final d = Directory(p.join(vaultPath, subdir));
        if (!await d.exists()) {
          await d.create(recursive: true);
        }
      }

      await openVault(vaultPath);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _saveToRecent(VaultConfig config) async {
    final prefs = await _ensurePrefs;
    final rawJson = prefs.getStringList(_recentVaultsKey) ?? [];
    final seen = <String>{};
    final existing = rawJson
        .map((j) {
          try {
            return VaultConfig.fromJson(
              Map<String, dynamic>.from(jsonDecode(j)),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<VaultConfig>()
        .where((v) => seen.add(_normalizePath(v.path)))
        .toList();

    existing.removeWhere(
      (v) => _normalizePath(v.path) == _normalizePath(config.path),
    );
    existing.insert(0, config);
    if (existing.length > 10) existing.removeRange(10, existing.length);

    final vaultsJson = existing.map((v) => jsonEncode(v.toJson())).toList();
    await prefs.setStringList(_recentVaultsKey, vaultsJson);
    await prefs.setString(_currentVaultKey, config.path);

    state = state.copyWith(recentVaults: existing);
  }

  Future<void> closeVault() async {
    final prefs = await _ensurePrefs;
    await prefs.remove(_currentVaultKey);
    state = state.copyWith(clearCurrentVault: true);
  }

  Future<void> removeFromRecent(String vaultPath) async {
    final prefs = await _ensurePrefs;
    final vaults = List<VaultConfig>.from(state.recentVaults)
      ..removeWhere((v) => _normalizePath(v.path) == _normalizePath(vaultPath));

    final vaultsJson = vaults.map((v) => jsonEncode(v.toJson())).toList();
    await prefs.setStringList(_recentVaultsKey, vaultsJson);

    if (_normalizePath(state.currentVault?.path ?? '') ==
        _normalizePath(vaultPath)) {
      await prefs.remove(_currentVaultKey);
      state = state.copyWith(clearCurrentVault: true, recentVaults: vaults);
    } else {
      state = state.copyWith(recentVaults: vaults);
    }
  }
}

final vaultProvider = NotifierProvider<VaultNotifier, VaultState>(
  VaultNotifier.new,
);

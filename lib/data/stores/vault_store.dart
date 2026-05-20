import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ignore_for_file: avoid_print

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
  @override
  VaultState build() => VaultState();

  Future<String> get _vaultConfigPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'vaults.json');
  }

  Future<Map<String, dynamic>> _loadVaultConfig() async {
    final path = await _vaultConfigPath;
    final file = File(path);
    if (await file.exists()) {
      try {
        return Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()) as Map,
        );
      } catch (_) {
        print('VaultStore: failed to read vaults.json');
      }
    }
    return {};
  }

  Future<void> _saveVaultConfig(Map<String, dynamic> config) async {
    final path = await _vaultConfigPath;
    final file = File(path);
    final dir = Directory(p.dirname(path));
    if (!await dir.exists()) await dir.create(recursive: true);
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(config));
  }

  static const _recentVaultsKey = 'recent_vaults';
  static const _currentVaultKey = 'current_vault';

  Future<void> loadRecentVaults() async {
    final config = await _loadVaultConfig();
    final vaultsJson = (config[_recentVaultsKey] as List?) ?? [];
    final seen = <String>{};
    final vaults = vaultsJson
        .map((j) {
          try {
            return VaultConfig.fromJson(Map<String, dynamic>.from(j as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<VaultConfig>()
        .where((v) => seen.add(_normalizePath(v.path)))
        .toList();

    VaultConfig? currentVault;
    final currentVaultPath = config[_currentVaultKey] as String?;
    if (currentVaultPath != null) {
      try {
        currentVault = vaults.firstWhere(
          (v) => _normalizePath(v.path) == _normalizePath(currentVaultPath),
        );
      } catch (_) {
        print('VaultStore: current vault not found in vault list');
      }
    }

    state = state.copyWith(recentVaults: vaults, currentVault: currentVault);
  }

  String _normalizePath(String path) => p.normalize(p.absolute(path));

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

  Future<void> _saveToRecent(VaultConfig vaultConfig) async {
    final config = await _loadVaultConfig();
    final vaultsJson = (config[_recentVaultsKey] as List?) ?? [];
    final seen = <String>{};
    final existing = vaultsJson
        .map((j) {
          try {
            return VaultConfig.fromJson(Map<String, dynamic>.from(j as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<VaultConfig>()
        .where((v) => seen.add(_normalizePath(v.path)))
        .toList();

    existing.removeWhere(
      (v) => _normalizePath(v.path) == _normalizePath(vaultConfig.path),
    );
    existing.insert(0, vaultConfig);
    if (existing.length > 10) existing.removeRange(10, existing.length);

    config[_recentVaultsKey] = existing.map((v) => v.toJson()).toList();
    config[_currentVaultKey] = vaultConfig.path;
    await _saveVaultConfig(config);

    state = state.copyWith(recentVaults: existing);
  }

  Future<void> closeVault() async {
    final config = await _loadVaultConfig();
    config.remove(_currentVaultKey);
    await _saveVaultConfig(config);
    state = state.copyWith(clearCurrentVault: true);
  }

  Future<void> removeFromRecent(String vaultPath) async {
    final vaults = List<VaultConfig>.from(state.recentVaults)
      ..removeWhere((v) => _normalizePath(v.path) == _normalizePath(vaultPath));

    final config = await _loadVaultConfig();
    config[_recentVaultsKey] = vaults.map((v) => v.toJson()).toList();

    if (_normalizePath(state.currentVault?.path ?? '') ==
        _normalizePath(vaultPath)) {
      config.remove(_currentVaultKey);
      await _saveVaultConfig(config);
      state = state.copyWith(clearCurrentVault: true, recentVaults: vaults);
    } else {
      await _saveVaultConfig(config);
      state = state.copyWith(recentVaults: vaults);
    }
  }
}

final vaultProvider = NotifierProvider<VaultNotifier, VaultState>(
  VaultNotifier.new,
);

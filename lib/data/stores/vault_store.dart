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
  }) {
    return VaultState(
      currentVault: currentVault ?? this.currentVault,
      recentVaults: recentVaults ?? this.recentVaults,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VaultNotifier extends Notifier<VaultState> {
  @override
  VaultState build() => VaultState();

  static const _recentVaultsKey = 'recent_vaults';
  static const _currentVaultKey = 'current_vault';

  Future<void> loadRecentVaults() async {
    final prefs = await SharedPreferences.getInstance();
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
        .where((v) => seen.add(v.path))
        .toList();
    state = state.copyWith(recentVaults: vaults);
  }

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
    final prefs = await SharedPreferences.getInstance();
    final vaults = List<VaultConfig>.from(state.recentVaults);
    vaults.removeWhere((v) => v.path == config.path);
    vaults.insert(0, config);
    if (vaults.length > 10) vaults.removeRange(10, vaults.length);

    final vaultsJson = vaults.map((v) => jsonEncode(v.toJson())).toList();
    await prefs.setStringList(_recentVaultsKey, vaultsJson);
    await prefs.setString(_currentVaultKey, config.path);

    state = state.copyWith(recentVaults: vaults);
  }

  Future<void> closeVault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentVaultKey);
    state = state.copyWith(currentVault: null);
  }

  Future<void> removeFromRecent(String vaultPath) async {
    final prefs = await SharedPreferences.getInstance();
    final vaults = List<VaultConfig>.from(state.recentVaults)
      ..removeWhere((v) => v.path == vaultPath);

    final vaultsJson = vaults.map((v) => jsonEncode(v.toJson())).toList();
    await prefs.setStringList(_recentVaultsKey, vaultsJson);

    if (state.currentVault?.path == vaultPath) {
      await prefs.remove(_currentVaultKey);
      state = state.copyWith(currentVault: null, recentVaults: vaults);
    } else {
      state = state.copyWith(recentVaults: vaults);
    }
  }
}

final vaultProvider = NotifierProvider<VaultNotifier, VaultState>(
  VaultNotifier.new,
);

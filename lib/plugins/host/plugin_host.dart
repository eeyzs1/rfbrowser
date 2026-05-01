import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../data/models/skill.dart';
import '../../data/stores/vault_store.dart';

class PluginManifest {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String minAppVersion;
  final List<String> permissions;
  final List<Skill> skills;

  PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    this.author = '',
    this.description = '',
    this.minAppVersion = '0.1.0',
    this.permissions = const [],
    this.skills = const [],
  });
}

class Plugin {
  final PluginManifest manifest;
  final bool isEnabled;
  final String path;

  Plugin({required this.manifest, this.isEnabled = true, required this.path});

  Plugin copyWith({bool? isEnabled}) {
    return Plugin(
      manifest: manifest,
      isEnabled: isEnabled ?? this.isEnabled,
      path: path,
    );
  }
}

class PluginHost {
  final String vaultPath;

  PluginHost(this.vaultPath);

  Future<List<Plugin>> getInstalledPlugins() async {
    final plugins = <Plugin>[];
    final pluginDir = Directory(p.join(vaultPath, '.rfbrowser', 'plugins'));
    if (!await pluginDir.exists()) return plugins;

    await for (final entity in pluginDir.list()) {
      if (entity is Directory) {
        final manifestFile = File(p.join(entity.path, 'manifest.yaml'));
        if (await manifestFile.exists()) {
          try {
            final content = await manifestFile.readAsString();
            final manifest = _parseManifest(content);
            plugins.add(Plugin(
              manifest: manifest,
              path: entity.path,
            ));
          } catch (_) {}
        }
      }
    }
    return plugins;
  }

  Future<void> installPlugin(String sourcePath) async {
    final pluginDir = Directory(p.join(vaultPath, '.rfbrowser', 'plugins'));
    if (!await pluginDir.exists()) {
      await pluginDir.create(recursive: true);
    }
    final sourceDir = Directory(sourcePath);
    final name = p.basename(sourcePath);
    final destDir = Directory(p.join(pluginDir.path, name));
    if (await destDir.exists()) {
      await destDir.delete(recursive: true);
    }
    await _copyDirectory(sourceDir, destDir);
  }

  Future<void> uninstallPlugin(String pluginId) async {
    final pluginDir = Directory(p.join(vaultPath, '.rfbrowser', 'plugins', pluginId));
    if (await pluginDir.exists()) {
      await pluginDir.delete(recursive: true);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  PluginManifest _parseManifest(String content) {
    String id = 'unknown';
    String name = 'Unknown';
    String version = '0.0.1';
    String author = '';
    String description = '';

    for (final line in content.split('\n')) {
      final colonIdx = line.indexOf(':');
      if (colonIdx > 0) {
        final key = line.substring(0, colonIdx).trim();
        final value = line.substring(colonIdx + 1).trim().replaceAll('"', '');
        switch (key) {
          case 'id':
            id = value;
          case 'name':
            name = value;
          case 'version':
            version = value;
          case 'author':
            author = value;
          case 'description':
            description = value;
        }
      }
    }

    return PluginManifest(
      id: id,
      name: name,
      version: version,
      author: author,
      description: description,
    );
  }
}

final pluginHostProvider = Provider<PluginHost?>((ref) {
  final vaultState = ref.watch(vaultProvider);
  if (vaultState.currentVault == null) return null;
  return PluginHost(vaultState.currentVault!.path);
});

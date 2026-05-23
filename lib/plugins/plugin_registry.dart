import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';
import '../data/models/skill.dart';
import 'builtin/builtin_plugin.dart';
import 'builtin/hello_world/hello_world_plugin.dart';
import 'host/plugin_host.dart';

class PluginRegistry {
  static final List<BuiltinPlugin> _builtinPlugins = [HelloWorldPlugin()];

  static List<BuiltinPlugin> get builtinPlugins =>
      List.unmodifiable(_builtinPlugins);

  static BuiltinPlugin? findById(String pluginId) {
    try {
      return _builtinPlugins.firstWhere((p) => p.manifest.id == pluginId);
    } catch (_) {
      return null;
    }
  }

  static List<Skill> getAllPluginSkills() {
    final allSkills = <Skill>[];
    for (final plugin in _builtinPlugins) {
      allSkills.addAll(plugin.skills);
    }
    return allSkills;
  }

  static Future<void> loadAllBuiltinPlugins(PluginHostNotifier host) async {
    for (final plugin in _builtinPlugins) {
      await host.registerManifestAndEnable(
        plugin.manifest,
        enabledByDefault: true,
        onEnable: (manifest, h) {
          plugin.onEnable(h);
          if (plugin.hooks.isNotEmpty) {
            h.registerHookHandler(manifest.id, (event, data) {
              plugin.onHookEvent(event, data);
            });
          }
        },
        onDisable: (manifest, h) {
          plugin.onDisable(h);
        },
      );
    }
  }

  static Future<void> unloadAllBuiltinPlugins(PluginHostNotifier host) async {
    for (final plugin in _builtinPlugins) {
      await plugin.onDisable(host);
      await host.disablePlugin(plugin.manifest.id);
    }
  }

  static Future<List<PluginManifest>> scanExternalPlugins(
    String vaultPath,
  ) async {
    final pluginsDir = Directory(
      '$vaultPath${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugins',
    );
    if (!await pluginsDir.exists()) return [];

    final manifests = <PluginManifest>[];
    await for (final entity in pluginsDir.list()) {
      if (entity is Directory) {
        final yamlFile = File(
          '${entity.path}${Platform.pathSeparator}manifest.yaml',
        );
        if (await yamlFile.exists()) {
          try {
            final content = await yamlFile.readAsString();
            final yaml = loadYaml(content) as Map;
            final manifest = PluginManifest.fromMap({
              'id': yaml['id'] ?? '',
              'name': yaml['name'] ?? '',
              'version': yaml['version'] ?? '0.1.0',
              'author': yaml['author'] ?? '',
              'description': yaml['description'] ?? '',
              'permissions': yaml['permissions'] ?? [],
            });
            if (manifest.id.isNotEmpty) {
              manifests.add(manifest);
            }
          } catch (e) {
            debugPrint('PluginRegistry: failed to load ${yamlFile.path}: $e');
          }
        }
      }
    }

    return manifests;
  }

  static Future<void> loadExternalPlugins(
    PluginHostNotifier host,
    String vaultPath,
  ) async {
    final manifests = await scanExternalPlugins(vaultPath);
    for (final manifest in manifests) {
      await host.registerManifestAndEnable(manifest, enabledByDefault: false);
    }
  }

  static Future<PluginManifest?> installFromGit(
    String url,
    String vaultPath,
  ) async {
    final pluginName = url.split('/').last.replaceAll('.git', '');
    final pluginsDir = Directory(
      '$vaultPath${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugins',
    );
    if (!await pluginsDir.exists()) {
      await pluginsDir.create(recursive: true);
    }

    final targetDir = Directory(
      '${pluginsDir.path}${Platform.pathSeparator}$pluginName',
    );
    if (await targetDir.exists()) {
      throw Exception('Plugin directory already exists: $pluginName');
    }

    final result = await Process.run('git', [
      'clone',
      '--depth',
      '1',
      url,
      targetDir.path,
    ], runInShell: true);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString();
      throw Exception('Git clone failed: $stderr');
    }

    final yamlFile = File(
      '${targetDir.path}${Platform.pathSeparator}manifest.yaml',
    );
    if (!await yamlFile.exists()) {
      throw Exception('manifest.yaml not found in plugin directory');
    }

    final content = await yamlFile.readAsString();
    final yaml = loadYaml(content) as Map;
    final manifest = PluginManifest.fromMap({
      'id': yaml['id'] ?? pluginName,
      'name': yaml['name'] ?? pluginName,
      'version': yaml['version'] ?? '0.1.0',
      'author': yaml['author'] ?? '',
      'description': yaml['description'] ?? '',
      'permissions': yaml['permissions'] ?? [],
    });

    return manifest;
  }
}

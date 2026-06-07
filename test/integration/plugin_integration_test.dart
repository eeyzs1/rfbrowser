import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';
import 'package:rfbrowser/plugins/plugin_registry.dart';

void main() {
  group('Plugin Host Integration', () {
    late ProviderContainer container;
    late PluginHostNotifier host;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      host = container.read(pluginHostProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no manifests', () {
      final state = container.read(pluginHostProvider);
      expect(state.manifests, isEmpty);
    });

    test('registerManifest adds plugin manifest', () async {
      final manifest = PluginManifest(
        id: 'test-plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        permissions: [Permission.knowledgeRead],
      );

      await host.registerManifest(manifest);
      final state = container.read(pluginHostProvider);
      expect(state.manifests.length, 1);
      expect(state.manifests.containsKey('test-plugin'), isTrue);
      expect(state.manifests['test-plugin']!.name, 'Test Plugin');
    });

    test('registerManifest does not duplicate', () async {
      final manifest = PluginManifest(id: 'test-plugin', name: 'Test Plugin');

      await host.registerManifest(manifest);
      await host.registerManifest(manifest);

      final state = container.read(pluginHostProvider);
      expect(state.manifests.length, 1);
    });

    test('disablePlugin stops plugin', () async {
      final manifest = PluginManifest(id: 'test-plugin', name: 'Test Plugin');
      await host.registerManifest(manifest);
      await host.enablePlugin(manifest);

      await host.disablePlugin('test-plugin');
      final state = container.read(pluginHostProvider);
      expect(state.running.containsKey('test-plugin'), isFalse);
    });

    test('enablePlugin starts plugin sandbox', () async {
      final manifest = PluginManifest(id: 'test-plugin', name: 'Test Plugin');
      await host.registerManifest(manifest);

      await host.enablePlugin(manifest);
      final state = container.read(pluginHostProvider);
      expect(state.running['test-plugin'], isTrue);
    });

    test('disablePlugin after enablePlugin', () async {
      final manifest = PluginManifest(id: 'test-plugin', name: 'Test Plugin');
      await host.registerManifest(manifest);
      await host.enablePlugin(manifest);

      await host.disablePlugin('test-plugin');
      final state = container.read(pluginHostProvider);
      expect(state.running['test-plugin'], isNull);
    });

    test('registerCommand adds command to plugin', () async {
      final manifest = PluginManifest(id: 'test-plugin', name: 'Test Plugin');
      await host.registerManifest(manifest);

      final command = PluginCommand(
        id: 'cmd1',
        label: 'Do Something',
        pluginId: 'test-plugin',
      );
      host.registerCommand(command);
      final state = container.read(pluginHostProvider);
      final commands = state.commands['test-plugin'];
      expect(commands, isNotNull);
      expect(commands!.length, 1);
      expect(commands.first.label, 'Do Something');
    });

    test('full plugin lifecycle: register, enable, disable', () async {
      final manifest = PluginManifest(
        id: 'lifecycle',
        name: 'Lifecycle Plugin',
        version: '1.0.0',
        permissions: [Permission.knowledgeRead, Permission.aiChat],
      );

      await host.registerManifest(manifest);
      expect(container.read(pluginHostProvider).manifests.length, 1);

      await host.enablePlugin(manifest);
      expect(container.read(pluginHostProvider).running['lifecycle'], isTrue);

      await host.disablePlugin('lifecycle');
      expect(container.read(pluginHostProvider).running['lifecycle'], isNull);

      // Manifest should still be registered even after disable
      expect(container.read(pluginHostProvider).manifests.length, 1);
    });
  });

  group('Plugin Registry Integration', () {
    test('loadAllBuiltinPlugins registers builtin plugins', () async {
      final container = ProviderContainer();
      final host = container.read(pluginHostProvider.notifier);

      await PluginRegistry.loadAllBuiltinPlugins(host);

      final state = container.read(pluginHostProvider);
      expect(state.manifests, isNotEmpty);
      expect(state.manifests.containsKey('hello-world'), isTrue);

      container.dispose();
    });
  });

  group('Plugin Manifest', () {
    test('PluginManifest fromMap and toMap roundtrip', () {
      final original = PluginManifest(
        id: 'test',
        name: 'Test Plugin',
        version: '2.0.0',
        author: 'Tester',
        description: 'A test plugin',
        permissions: [Permission.knowledgeRead, Permission.knowledgeWrite],
      );

      final map = original.toMap();
      final restored = PluginManifest.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.version, original.version);
      expect(restored.author, original.author);
      expect(restored.description, original.description);
      expect(restored.permissions.length, original.permissions.length);
    });

    test('PluginManifest defaults', () {
      final manifest = PluginManifest(id: 'minimal', name: 'Minimal');

      expect(manifest.version, '0.1.0');
      expect(manifest.author, '');
      expect(manifest.description, '');
      expect(manifest.permissions, isEmpty);
    });
  });
}
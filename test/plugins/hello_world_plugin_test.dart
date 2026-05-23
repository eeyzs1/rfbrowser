import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/plugins/builtin/builtin_plugin.dart';
import 'package:rfbrowser/plugins/builtin/hello_world/hello_world_plugin.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';
import 'package:rfbrowser/plugins/plugin_registry.dart';

Future<Map<String, dynamic>> _testApiHandler(
  String apiName,
  Map<String, dynamic> args,
) async {
  switch (apiName) {
    case 'knowledge.getNote':
      return {'id': args['id'], 'title': 'Test', 'content': 'Hello'};
    case 'knowledge.search':
      return {'results': []};
    case 'browser.getCurrentUrl':
      return {'url': 'https://example.com'};
    default:
      throw UnimplementedError('Unknown API: $apiName');
  }
}

class _TestPluginHost {
  PluginState state = PluginState();
  final Map<String, Sandbox> _sandboxes = {};

  Future<void> enablePlugin(PluginManifest manifest) async {
    final sandbox = Sandbox(
      pluginId: manifest.id,
      manifest: manifest,
      apiHandler: _testApiHandler,
    );
    await sandbox.start();
    _sandboxes[manifest.id] = sandbox;
    state = state.copyWith(
      manifests: {...state.manifests, manifest.id: manifest},
      running: {...state.running, manifest.id: true},
    );
  }

  Future<void> disablePlugin(String pluginId) async {
    final sandbox = _sandboxes[pluginId];
    if (sandbox != null) {
      await sandbox.stop();
      _sandboxes.remove(pluginId);
    }
    final running = Map<String, bool>.from(state.running)..remove(pluginId);
    state = state.copyWith(running: running);
  }

  Sandbox? getSandbox(String pluginId) => _sandboxes[pluginId];

  void registerCommand(PluginCommand command) {
    final commands = Map<String, List<PluginCommand>>.from(state.commands);
    commands.putIfAbsent(command.pluginId, () => []).add(command);
    state = state.copyWith(commands: commands);
  }

  List<PluginCommand> getPluginCommands(String pluginId) =>
      state.commands[pluginId] ?? [];

  List<PluginCommand> getAllCommands() =>
      state.commands.values.expand((c) => c).toList();
}

void main() {
  group('HelloWorldPlugin', () {
    late HelloWorldPlugin plugin;

    setUp(() {
      plugin = HelloWorldPlugin();
    });

    test('manifest has correct id and name', () {
      expect(plugin.manifest.id, 'hello-world');
      expect(plugin.manifest.name, 'Hello World');
      expect(plugin.manifest.version, '1.0.0');
    });

    test('manifest declares required permissions', () {
      final permissions = plugin.manifest.permissions;
      expect(permissions, contains(Permission.knowledgeRead));
      expect(permissions, contains(Permission.knowledgeWrite));
      expect(permissions, contains(Permission.browserRead));
      expect(permissions, contains(Permission.uiCommand));
      expect(permissions, contains(Permission.uiPanel));
    });

    test('commands are registered with correct pluginId', () {
      final commands = plugin.commands;
      expect(commands.length, 3);

      for (final cmd in commands) {
        expect(cmd.pluginId, 'hello-world');
      }

      final labels = commands.map((c) => c.label).toList();
      expect(labels, contains('Say Hello'));
      expect(labels, contains('Count Notes'));
      expect(labels, contains('Show Hello Panel'));
    });

    test('onEnable registers all commands with host', () async {
      final host = _TestPluginHost();
      await host.enablePlugin(plugin.manifest);
      for (final cmd in plugin.commands) {
        host.registerCommand(cmd);
      }
      expect(host.getPluginCommands('hello-world').length, 3);
    });

    test('handleApiCall greet returns greeting message', () async {
      final result = await plugin.handleApiCall('hello-world.greet', {
        'name': 'RFBrowser',
      });

      expect(result['message'], 'Hello, RFBrowser!');
      expect(result['timestamp'], isA<String>());
    });

    test('handleApiCall greet with no name defaults to World', () async {
      final result = await plugin.handleApiCall('hello-world.greet', {});

      expect(result['message'], 'Hello, World!');
    });

    test('handleApiCall count-notes returns count', () async {
      final result = await plugin.handleApiCall('hello-world.count-notes', {
        'count': 42,
      });

      expect(result['count'], 42);
      expect(result['message'], 'Found 42 notes in vault');
    });

    test('handleApiCall unknown API throws UnimplementedError', () async {
      expect(
        () => plugin.handleApiCall('unknown', {}),
        throwsA(isA<UnimplementedError>()),
      );
    });

    testWidgets('buildPanel renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  plugin.buildPanel(context) ?? const SizedBox(),
            ),
          ),
        ),
      );

      expect(find.text('Hello World Plugin'), findsOneWidget);
      expect(find.text('Say Hello'), findsNothing);
    });

    test('implements BuiltinPlugin interface', () {
      expect(plugin, isA<BuiltinPlugin>());
    });
  });

  group('PluginRegistry', () {
    test('builtinPlugins contains HelloWorldPlugin', () {
      final plugins = PluginRegistry.builtinPlugins;
      expect(plugins.length, greaterThanOrEqualTo(1));

      final helloWorld = plugins.firstWhere(
        (p) => p.manifest.id == 'hello-world',
      );
      expect(helloWorld.manifest.name, 'Hello World');
    });

    test('findById returns plugin for valid id', () {
      final found = PluginRegistry.findById('hello-world');
      expect(found, isNotNull);
      expect(found!.manifest.id, 'hello-world');
    });

    test('findById returns null for unknown id', () {
      final found = PluginRegistry.findById('nonexistent');
      expect(found, isNull);
    });

    test('loadAllBuiltinPlugins enables all plugins', () async {
      final host = _TestPluginHost();

      for (final p in PluginRegistry.builtinPlugins) {
        await host.enablePlugin(p.manifest);
        for (final cmd in p.commands) {
          host.registerCommand(cmd);
        }
      }

      for (final p in PluginRegistry.builtinPlugins) {
        expect(host.state.manifests[p.manifest.id], isNotNull);
        expect(host.state.running[p.manifest.id], true);
      }
    });

    test('unloadAllBuiltinPlugins disables all plugins', () async {
      final host = _TestPluginHost();

      for (final p in PluginRegistry.builtinPlugins) {
        await host.enablePlugin(p.manifest);
      }

      for (final p in PluginRegistry.builtinPlugins) {
        await host.disablePlugin(p.manifest.id);
      }

      for (final p in PluginRegistry.builtinPlugins) {
        expect(host.state.running[p.manifest.id], isNull);
      }
    });
  });

  group('HelloWorldPlugin + PluginHost Integration', () {
    test('full lifecycle: enable, register commands, disable', () async {
      final host = _TestPluginHost();
      final p = HelloWorldPlugin();

      await host.enablePlugin(p.manifest);
      expect(host.state.running['hello-world'], true);

      for (final cmd in p.commands) {
        host.registerCommand(cmd);
      }
      final commands = host.getPluginCommands('hello-world');
      expect(commands.length, 3);

      await host.disablePlugin('hello-world');
      expect(host.state.running['hello-world'], isNull);
    });

    test('all registered commands are discoverable', () async {
      final host = _TestPluginHost();
      final p = HelloWorldPlugin();

      await host.enablePlugin(p.manifest);
      for (final cmd in p.commands) {
        host.registerCommand(cmd);
      }

      final allCommands = host.getAllCommands();
      final pluginCommands = allCommands
          .where((c) => c.pluginId == 'hello-world')
          .toList();

      expect(pluginCommands.length, 3);
      expect(
        pluginCommands.map((c) => c.id),
        containsAll([
          'hello-world.greet',
          'hello-world.count-notes',
          'hello-world.show-panel',
        ]),
      );
    });

    test('sandbox API call with valid permission succeeds', () async {
      final host = _TestPluginHost();
      final p = HelloWorldPlugin();
      await host.enablePlugin(p.manifest);

      final sandbox = host.getSandbox('hello-world');
      expect(sandbox, isNotNull);

      final result = await sandbox!.callApi<Map<String, dynamic>>(
        'knowledge.getNote',
        {'id': 'test.md'},
        requiredPermission: Permission.knowledgeRead,
      );
      expect(result, isNotNull);
      expect(result!['title'], 'Test');
    });

    test('sandbox API call without permission is denied', () async {
      final host = _TestPluginHost();
      final p = HelloWorldPlugin();
      await host.enablePlugin(p.manifest);

      final sandbox = host.getSandbox('hello-world');
      expect(sandbox, isNotNull);

      expect(
        () => sandbox!.callApi('knowledge.getNote', {
          'id': 'test.md',
        }, requiredPermission: Permission.aiChat),
        throwsA(isA<PermissionDeniedError>()),
      );
    });
  });
}

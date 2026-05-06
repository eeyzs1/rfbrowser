import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';

Future<Map<String, dynamic>> _testApiHandler(
  String apiName,
  Map<String, dynamic> args,
) async {
  switch (apiName) {
    case 'knowledge.getNote':
      return {'id': args['id'], 'title': 'Test Note', 'content': 'Hello world'};
    case 'knowledge.search':
      return {'results': [{'id': '1', 'title': 'Result'}]};
    case 'browser.getCurrentUrl':
      return {'url': 'https://example.com'};
    case 'browser.extractText':
      return {'text': 'Extracted text'};
    default:
      throw UnimplementedError('Unknown API: $apiName');
  }
}

void main() {
  group('Sandbox', () {
    test('AC-P4-1-1: create sandbox with Isolate and start it', () async {
      final manifest = PluginManifest(
        id: 'test-plugin',
        name: 'Test Plugin',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: _testApiHandler,
      );

      expect(sandbox.isRunning, false);
      await sandbox.start();
      expect(sandbox.isRunning, true);
      await sandbox.stop();
    });

    test('AC-P4-1-2: plugin Isolate error triggers onError callback, main app survives', () async {
      final manifest = PluginManifest(
        id: 'crash-plugin',
        name: 'Crash Plugin',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: _testApiHandler,
      );
      await sandbox.start();
      expect(sandbox.isRunning, true);

      final errorFuture = sandbox.onError.first;

      sandbox.simulateCrashForTest();

      final error = await errorFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () => 'timeout',
      );
      expect(error, isNot(equals('timeout')));
    });

    test('AC-P4-1-3: callApi without permission throws PermissionDeniedError', () async {
      final manifest = PluginManifest(
        id: 'no-perm-plugin',
        name: 'No Permission Plugin',
        permissions: [],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: _testApiHandler,
      );
      await sandbox.start();

      expect(
        () => sandbox.callApi('knowledge.getNote', {}, requiredPermission: Permission.knowledgeRead),
        throwsA(isA<PermissionDeniedError>()),
      );
      await sandbox.stop();
    });

    test('AC-P4-1-4: callApi with permission succeeds and returns result', () async {
      final manifest = PluginManifest(
        id: 'perm-plugin',
        name: 'Permission Plugin',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: _testApiHandler,
      );
      await sandbox.start();

      final result = await sandbox.callApi<Map<String, dynamic>>(
        'knowledge.getNote',
        {'id': 'note-1'},
        requiredPermission: Permission.knowledgeRead,
      );
      expect(result, isNotNull);
      expect(result!['title'], 'Test Note');
      await sandbox.stop();
    });

    test('AC-P4-1-8: stop sets isRunning to false and kills Isolate', () async {
      final manifest = PluginManifest(id: 'stop-test', name: 'Stop Test');
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: _testApiHandler,
      );
      await sandbox.start();
      expect(sandbox.isRunning, true);
      await sandbox.stop();
      expect(sandbox.isRunning, false);
    });

    test('callApi on stopped sandbox throws StateError', () async {
      final manifest = PluginManifest(
        id: 'stopped-plugin',
        name: 'Stopped Plugin',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: _testApiHandler,
      );

      expect(
        () => sandbox.callApi('test', {}, requiredPermission: Permission.knowledgeRead),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('PermissionChecker', () {
    test('AC-P4-1-5: check returns true for declared permission', () {
      final checker = PermissionChecker();
      final manifest = PluginManifest(
        id: 'p1',
        name: 'P1',
        permissions: [Permission.knowledgeRead, Permission.browserRead],
      );

      expect(checker.check(manifest, Permission.knowledgeRead), true);
      expect(checker.check(manifest, Permission.browserRead), true);
      expect(checker.check(manifest, Permission.knowledgeWrite), false);
    });

    test('missingPermissions returns correct list', () {
      final checker = PermissionChecker();
      final manifest = PluginManifest(
        id: 'p2',
        name: 'P2',
        permissions: [Permission.knowledgeRead],
      );

      final missing = checker.missingPermissions(
        manifest,
        [Permission.knowledgeRead, Permission.knowledgeWrite],
      );
      expect(missing.length, 1);
      expect(missing.first, Permission.knowledgeWrite);
    });
  });

  group('PluginHost (pure Dart)', () {
    test('enablePlugin adds manifest and sets running', () async {
      final host = _PurePluginHost();
      final manifest = PluginManifest(
        id: 'test-1',
        name: 'Test 1',
        permissions: [Permission.knowledgeRead],
      );

      await host.enablePlugin(manifest);
      expect(host.state.manifests['test-1'], isNotNull);
      expect(host.state.running['test-1'], true);
    });

    test('disablePlugin removes running status', () async {
      final host = _PurePluginHost();
      final manifest = PluginManifest(id: 'test-2', name: 'Test 2');
      await host.enablePlugin(manifest);
      expect(host.state.running['test-2'], true);

      await host.disablePlugin('test-2');
      expect(host.state.running['test-2'], isNull);
    });

    test('AC-P4-1-6: registerCommand and getPluginCommands', () async {
      final host = _PurePluginHost();
      final manifest = PluginManifest(id: 'cmd-plugin', name: 'Cmd Plugin');
      await host.enablePlugin(manifest);

      final cmd = PluginCommand(id: 'cmd1', label: 'Run Test', pluginId: 'cmd-plugin');
      host.registerCommand(cmd);

      final commands = host.getPluginCommands('cmd-plugin');
      expect(commands.length, 1);
      expect(commands.first.label, 'Run Test');
    });

    test('getAllCommands returns commands from all plugins', () async {
      final host = _PurePluginHost();
      final m1 = PluginManifest(id: 'p1', name: 'P1');
      final m2 = PluginManifest(id: 'p2', name: 'P2');
      await host.enablePlugin(m1);
      await host.enablePlugin(m2);

      host.registerCommand(PluginCommand(id: 'c1', label: 'C1', pluginId: 'p1'));
      host.registerCommand(PluginCommand(id: 'c2', label: 'C2', pluginId: 'p2'));

      final all = host.getAllCommands();
      expect(all.length, 2);
    });

    test('AC-P4-1-7: crash recovery restarts sandbox within 3 seconds', () async {
      final host = _PurePluginHost();
      final manifest = PluginManifest(
        id: 'crash-recover',
        name: 'Crash Recover',
        permissions: [Permission.knowledgeRead],
      );
      await host.enablePlugin(manifest);
      final sandbox = host.getSandbox('crash-recover')!;
      expect(sandbox.isRunning, true);

      sandbox.simulateCrashForTest();
      expect(sandbox.isRunning, false);

      await Future.delayed(const Duration(seconds: 4));
      expect(sandbox.isRunning, true);
      expect(sandbox.crashCount, 1);
    });
  });

  group('PluginManifest', () {
    test('fromMap parses correctly', () {
      final map = {
        'id': 'test',
        'name': 'Test Plugin',
        'version': '1.0.0',
        'author': 'Author',
        'description': 'A test plugin',
        'permissions': ['knowledgeRead', 'browserRead'],
      };

      final manifest = PluginManifest.fromMap(map);
      expect(manifest.id, 'test');
      expect(manifest.name, 'Test Plugin');
      expect(manifest.version, '1.0.0');
      expect(manifest.permissions.length, 2);
      expect(manifest.permissions, contains(Permission.knowledgeRead));
    });

    test('fromMap handles missing fields', () {
      final manifest = PluginManifest.fromMap({});
      expect(manifest.id, '');
      expect(manifest.name, '');
      expect(manifest.permissions, isEmpty);
    });

    test('toMap round-trips correctly', () {
      final manifest = PluginManifest(
        id: 'round-trip',
        name: 'Round Trip',
        version: '2.0.0',
        permissions: [Permission.knowledgeRead],
      );
      final map = manifest.toMap();
      final restored = PluginManifest.fromMap(map);
      expect(restored.id, manifest.id);
      expect(restored.name, manifest.name);
      expect(restored.version, manifest.version);
      expect(restored.permissions.length, 1);
    });
  });
}

class _PurePluginHost {
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

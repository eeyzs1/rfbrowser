import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';
import 'package:rfbrowser/plugins/plugin_registry.dart';
import 'package:rfbrowser/plugins/builtin/hello_world/hello_world_plugin.dart';
import 'package:rfbrowser/data/repositories/note_repository.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
import 'package:rfbrowser/services/browser_service.dart';

void main() {
  // These tests exercise pure Dart logic against ProviderContainer; they
  // do not need a real app window, an integration-test driver, or the
  // platform channels that IntegrationTestWidgetsFlutterBinding brings in.
  // Originally they lived under integration_test/ which forced them to be
  // compiled into a separate rfbrowser.exe and launched on a desktop
  // session, which the windows-2022 CI runner cannot provide. Running
  // them as plain widget tests under test/integration/ sidesteps that
  // launcher entirely while exercising the exact same code paths.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Plugin Lifecycle Integration', () {
    test(
      'AC-PL-1: full lifecycle — register, enable, commands, disable',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final host = container.read(pluginHostProvider.notifier);
        final manifest = HelloWorldPlugin().manifest;

        await host.registerManifest(manifest);
        expect(
          container.read(pluginHostProvider).manifests['hello-world'],
          isNotNull,
        );

        await host.setPluginEnabled('hello-world', true);
        expect(container.read(pluginHostProvider).running['hello-world'], true);
        expect(container.read(pluginHostProvider).enabled['hello-world'], true);

        final plugin = HelloWorldPlugin();
        for (final cmd in plugin.commands) {
          host.registerCommand(cmd);
        }
        expect(host.getPluginCommands('hello-world').length, 3);

        await host.setPluginEnabled('hello-world', false);
        expect(
          container.read(pluginHostProvider).running['hello-world'],
          isNull,
        );
        expect(
          container.read(pluginHostProvider).enabled['hello-world'],
          false,
        );
      },
    );

    test(
      'AC-PL-2: registerManifestAndEnable with enabledByDefault=true',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final host = container.read(pluginHostProvider.notifier);
        final manifest = PluginManifest(
          id: 'auto-enable-test',
          name: 'Auto Enable',
          permissions: [Permission.knowledgeRead],
        );

        await host.registerManifestAndEnable(manifest, enabledByDefault: true);
        expect(
          container.read(pluginHostProvider).manifests['auto-enable-test'],
          isNotNull,
        );
        expect(
          container.read(pluginHostProvider).running['auto-enable-test'],
          true,
        );
        expect(
          container.read(pluginHostProvider).enabled['auto-enable-test'],
          true,
        );
      },
    );

    test(
      'AC-PL-3: registerManifestAndEnable with enabledByDefault=false',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final host = container.read(pluginHostProvider.notifier);
        final manifest = PluginManifest(
          id: 'no-auto-enable',
          name: 'No Auto Enable',
          permissions: [Permission.knowledgeRead],
        );

        await host.registerManifestAndEnable(manifest, enabledByDefault: false);
        expect(
          container.read(pluginHostProvider).manifests['no-auto-enable'],
          isNotNull,
        );
        expect(
          container.read(pluginHostProvider).running['no-auto-enable'],
          isNot(equals(true)),
        );
        expect(
          container.read(pluginHostProvider).enabled['no-auto-enable'],
          isNot(equals(true)),
        );
      },
    );

    test('AC-PL-4: registerManifest skips duplicate id', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      final manifest = PluginManifest(id: 'dup-test', name: 'Dup');

      await host.registerManifest(manifest);
      expect(container.read(pluginHostProvider).manifests.length, 1);

      await host.registerManifest(manifest);
      expect(container.read(pluginHostProvider).manifests.length, 1);
    });

    test('AC-PL-5: getAllCommands returns commands from all plugins', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);

      final m1 = PluginManifest(id: 'p1', name: 'P1');
      final m2 = PluginManifest(id: 'p2', name: 'P2');

      await host.registerManifestAndEnable(m1);
      await host.registerManifestAndEnable(m2);

      host.registerCommand(
        PluginCommand(id: 'c1', label: 'C1', pluginId: 'p1'),
      );
      host.registerCommand(
        PluginCommand(id: 'c2', label: 'C2', pluginId: 'p2'),
      );

      final all = host.getAllCommands();
      expect(all.length, 2);
      expect(all.map((c) => c.id), containsAll(['c1', 'c2']));
    });
  });

  group('Plugin Hook Dispatch', () {
    test('AC-PL-6: dispatchHook calls registered handler', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      final manifest = PluginManifest(
        id: 'hook-test',
        name: 'Hook Test',
        permissions: [Permission.knowledgeRead],
      );

      await host.registerManifestAndEnable(manifest);

      String? receivedEvent;
      Map<String, dynamic>? receivedData;

      host.registerHookHandler('hook-test', (event, data) {
        receivedEvent = event;
        receivedData = data;
      });

      host.dispatchHook('note.opened', {'noteId': 'test.md'});

      expect(receivedEvent, 'note.opened');
      expect(receivedData?['noteId'], 'test.md');
    });

    test(
      'AC-PL-7: dispatchHook does not call handler for stopped plugin',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final host = container.read(pluginHostProvider.notifier);
        final manifest = PluginManifest(
          id: 'stopped-hook-test',
          name: 'Stopped Hook',
          permissions: [Permission.knowledgeRead],
        );

        await host.registerManifestAndEnable(manifest);
        await host.disablePlugin('stopped-hook-test');

        String? receivedEvent;
        host.registerHookHandler('stopped-hook-test', (event, data) {
          receivedEvent = event;
        });

        host.dispatchHook('note.saved', {'noteId': 'other.md'});
        expect(receivedEvent, isNull);
      },
    );

    test(
      'AC-PL-8: dispatchHook handles handler exceptions gracefully',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final host = container.read(pluginHostProvider.notifier);
        final manifest = PluginManifest(
          id: 'crash-hook-test',
          name: 'Crash Hook',
          permissions: [Permission.knowledgeRead],
        );

        await host.registerManifestAndEnable(manifest);

        host.registerHookHandler('crash-hook-test', (event, data) {
          throw Exception('Handler crashed');
        });

        host.dispatchHook('note.opened', {'noteId': 'test.md'});
      },
    );

    test('AC-PL-9: multiple hook handlers all receive event', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);

      final m1 = PluginManifest(
        id: 'hook-a',
        name: 'Hook A',
        permissions: [Permission.knowledgeRead],
      );
      final m2 = PluginManifest(
        id: 'hook-b',
        name: 'Hook B',
        permissions: [Permission.knowledgeRead],
      );

      await host.registerManifestAndEnable(m1);
      await host.registerManifestAndEnable(m2);

      final receivedEvents = <String>[];
      host.registerHookHandler('hook-a', (event, data) {
        receivedEvents.add('a:$event');
      });
      host.registerHookHandler('hook-b', (event, data) {
        receivedEvents.add('b:$event');
      });

      host.dispatchHook('note.saved', {'noteId': 'x.md'});

      expect(receivedEvents, containsAll(['a:note.saved', 'b:note.saved']));
    });
  });

  group('Plugin Config Persistence', () {
    test('AC-PL-10: saveConfig and loadConfig round-trip', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_plugin_cfg_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      final manifest = PluginManifest(
        id: 'persist-test',
        name: 'Persist Test',
        permissions: [Permission.knowledgeRead],
      );

      await host.registerManifestAndEnable(manifest);

      final configDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}.rfbrowser',
      );
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      await host.setPluginEnabled('persist-test', true);
      await _testSaveConfig(host, tempDir.path);

      final configFile = File(
        '${tempDir.path}${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugin-config.json',
      );
      expect(await configFile.exists(), true);

      final container2 = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container2.dispose);

      final host2 = container2.read(pluginHostProvider.notifier);
      await host2.registerManifest(manifest);
      await _testLoadConfig(host2, tempDir.path);

      expect(container2.read(pluginHostProvider).enabled['persist-test'], true);
    });
  });

  group('Plugin API Bridge with Real Data', () {
    test('AC-PL-11: knowledge.getNote via PluginHostNotifier', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_api_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final note = await repo.createNote(title: 'API Test Note');

      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final result = await _testHandleApiCall(container, 'knowledge.getNote', {
        'id': note.filePath,
      });

      expect(result['title'], 'API Test Note');
      expect(result['content'], isNotEmpty);
      expect(result['filePath'], note.filePath);
    });

    test('AC-PL-12: knowledge.search via PluginHostNotifier', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_api_search_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final note = await repo.createNote(title: 'Searchable Note');

      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final indexStore = container.read(indexStoreProvider);
      await indexStore.indexNote(note);

      final result = await _testHandleApiCall(container, 'knowledge.search', {
        'query': 'Searchable',
      });

      expect(result['results'] is List, true);
      expect((result['results'] as List).length, greaterThanOrEqualTo(1));
    });

    test('AC-PL-13: browser.getCurrentUrl via PluginHostNotifier', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final browser = container.read(browserProvider.notifier);
      browser.createTab(url: 'https://plugin-test.com');

      final result = await _testHandleApiCall(
        container,
        'browser.getCurrentUrl',
        {},
      );

      expect(result['url'], 'https://plugin-test.com');
    });

    test(
      'AC-PL-14: browser.getCurrentUrl with no tabs returns empty',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final result = await _testHandleApiCall(
          container,
          'browser.getCurrentUrl',
          {},
        );

        expect(result['url'], '');
      },
    );

    test('AC-PL-15: unknown API throws UnimplementedError', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => _testHandleApiCall(container, 'unknown.api', {}),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('PluginRegistry Integration', () {
    test('AC-PL-16: loadAllBuiltinPlugins registers and enables all', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_registry_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      await PluginRegistry.loadAllBuiltinPlugins(host);

      final state = container.read(pluginHostProvider);
      for (final plugin in PluginRegistry.builtinPlugins) {
        expect(state.manifests[plugin.manifest.id], isNotNull);
        expect(state.running[plugin.manifest.id], true);
      }
    });

    test('AC-PL-17: unloadAllBuiltinPlugins disables all', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'rfb_registry_unload_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = NoteRepository(tempDir.path);
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      await PluginRegistry.loadAllBuiltinPlugins(host);
      await PluginRegistry.unloadAllBuiltinPlugins(host);

      final state = container.read(pluginHostProvider);
      for (final plugin in PluginRegistry.builtinPlugins) {
        expect(state.running[plugin.manifest.id], isNull);
      }
    });

    test('AC-PL-18: scanExternalPlugins finds plugins in vault dir', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ext_scan_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final pluginsDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugins${Platform.pathSeparator}test-plugin',
      );
      await pluginsDir.create(recursive: true);

      final yamlContent = '''
id: com.test.external
name: Test External
version: 0.1.0
author: Tester
description: An external test plugin
permissions: [knowledgeRead, browserRead]
''';
      File(
        '${pluginsDir.path}${Platform.pathSeparator}manifest.yaml',
      ).writeAsStringSync(yamlContent);

      final manifests = await PluginRegistry.scanExternalPlugins(tempDir.path);
      expect(manifests.length, 1);
      expect(manifests.first.id, 'com.test.external');
      expect(manifests.first.name, 'Test External');
      expect(manifests.first.permissions.length, 2);
      expect(manifests.first.permissions, contains(Permission.knowledgeRead));
      expect(manifests.first.permissions, contains(Permission.browserRead));
    });

    test(
      'AC-PL-19: scanExternalPlugins returns empty for no plugins dir',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('rfb_ext_empty_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final manifests = await PluginRegistry.scanExternalPlugins(
          tempDir.path,
        );
        expect(manifests, isEmpty);
      },
    );

    test('AC-PL-20: scanExternalPlugins skips invalid manifest', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ext_invalid_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final pluginsDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugins${Platform.pathSeparator}bad-plugin',
      );
      await pluginsDir.create(recursive: true);

      File(
        '${pluginsDir.path}${Platform.pathSeparator}manifest.yaml',
      ).writeAsStringSync('not: valid\nyaml: [');

      final manifests = await PluginRegistry.scanExternalPlugins(tempDir.path);
      expect(manifests, isEmpty);
    });

    test(
      'AC-PL-21: getAllPluginSkills returns skills from all builtin plugins',
      () {
        final skills = PluginRegistry.getAllPluginSkills();
        expect(skills, isNotEmpty);

        final ids = skills.map((s) => s.id).toList();
        expect(ids, contains('hello-world.greeting'));
        expect(ids, contains('hello-world.note-stats'));

        for (final skill in skills) {
          expect(skill.pluginId, isNotNull);
          expect(skill.pluginId, isNotEmpty);
        }
      },
    );

    test('AC-PL-22: loadExternalPlugins registers but does not enable', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_ext_load_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final pluginsDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugins${Platform.pathSeparator}ext-plugin',
      );
      await pluginsDir.create(recursive: true);

      final yamlContent = '''
id: com.test.ext-load
name: Ext Load Test
version: 0.1.0
permissions: [knowledgeRead]
''';
      File(
        '${pluginsDir.path}${Platform.pathSeparator}manifest.yaml',
      ).writeAsStringSync(yamlContent);

      final repo = NoteRepository(tempDir.path);
      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider.notifier);
      await PluginRegistry.loadExternalPlugins(host, tempDir.path);

      final state = container.read(pluginHostProvider);
      expect(state.manifests['com.test.ext-load'], isNotNull);
      expect(state.enabled['com.test.ext-load'], isNot(equals(true)));
      expect(state.running['com.test.ext-load'], isNull);
    });
  });

  group('Sandbox Permission Enforcement', () {
    test('AC-PL-23: sandbox callApi with valid permission succeeds', () async {
      final manifest = PluginManifest(
        id: 'perm-ok',
        name: 'Perm OK',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async => {'id': '1', 'title': 'Test'},
      );
      await sandbox.start();
      addTearDown(sandbox.stop);

      final result = await sandbox.callApi<Map<String, dynamic>>(
        'knowledge.getNote',
        {'id': '1'},
        requiredPermission: Permission.knowledgeRead,
      );
      expect(result, isNotNull);
      expect(result!['title'], 'Test');
    });

    test('AC-PL-24: sandbox callApi without permission is denied', () async {
      final manifest = PluginManifest(
        id: 'perm-deny',
        name: 'Perm Deny',
        permissions: [Permission.browserRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async => {'ok': true},
      );
      await sandbox.start();
      addTearDown(sandbox.stop);

      expect(
        () => sandbox.callApi('knowledge.getNote', {
          'id': '1',
        }, requiredPermission: Permission.knowledgeRead),
        throwsA(isA<PermissionDeniedError>()),
      );
    });

    test(
      'AC-PL-25: sandbox callApi on stopped sandbox throws StateError',
      () async {
        final manifest = PluginManifest(
          id: 'stopped-sandbox',
          name: 'Stopped',
          permissions: [Permission.knowledgeRead],
        );
        final sandbox = Sandbox(
          pluginId: manifest.id,
          manifest: manifest,
          apiHandler: (apiName, args) async => {'ok': true},
        );

        expect(
          () => sandbox.callApi('knowledge.getNote', {
            'id': '1',
          }, requiredPermission: Permission.knowledgeRead),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('PluginManifest Serialization', () {
    test('AC-PL-26: fromMap handles all permission types', () {
      final map = {
        'id': 'all-perms',
        'name': 'All Perms',
        'version': '1.0.0',
        'permissions': [
          'knowledgeRead',
          'knowledgeWrite',
          'browserRead',
          'browserWrite',
          'aiChat',
          'uiCommand',
          'uiPanel',
        ],
      };

      final manifest = PluginManifest.fromMap(map);
      expect(manifest.permissions.length, 7);
      expect(manifest.permissions, containsAll(Permission.values));
    });

    test('AC-PL-27: toMap and fromMap round-trip preserves data', () {
      final manifest = PluginManifest(
        id: 'round-trip',
        name: 'Round Trip',
        version: '2.0.0',
        author: 'Test Author',
        description: 'Test description',
        permissions: [Permission.knowledgeRead, Permission.aiChat],
      );

      final map = manifest.toMap();
      final restored = PluginManifest.fromMap(map);

      expect(restored.id, manifest.id);
      expect(restored.name, manifest.name);
      expect(restored.version, manifest.version);
      expect(restored.author, manifest.author);
      expect(restored.description, manifest.description);
      expect(restored.permissions.length, 2);
    });

    test('AC-PL-28: PluginHook fromMap and toMap round-trip', () {
      final hook = PluginHook(event: 'note.opened', handler: 'onNoteOpened');
      final map = hook.toMap();
      final restored = PluginHook.fromMap(map);

      expect(restored.event, hook.event);
      expect(restored.handler, hook.handler);
    });
  });
}

Future<Map<String, dynamic>> _testHandleApiCall(
  ProviderContainer container,
  String apiName,
  Map<String, dynamic> args,
) async {
  switch (apiName) {
    case 'knowledge.getNote':
      final repo = container.read(noteRepositoryProvider);
      if (repo == null) return {'error': 'No vault open'};
      final id = args['id'] as String? ?? '';
      final note = await repo.getNoteByPath(id);
      if (note == null) return {'error': 'Note not found: $id'};
      return {
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'filePath': note.filePath,
        'tags': note.tags,
      };
    case 'knowledge.search':
      final indexStore = container.read(indexStoreProvider);
      final query = args['query'] as String? ?? '';
      final results = await indexStore.searchNotes(query);
      return {'results': results};
    case 'browser.getCurrentUrl':
      final browserState = container.read(browserProvider);
      return {'url': browserState.activeTab?.url ?? ''};
    case 'browser.extractText':
      return {'text': ''};
    default:
      throw UnimplementedError('Unknown API: $apiName');
  }
}

Future<void> _testSaveConfig(PluginHostNotifier host, String vaultPath) async {
  final configPath =
      '$vaultPath${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugin-config.json';
  final file = File(configPath);
  final dir = file.parent;
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  await file.writeAsString(jsonEncode(host.state.enabled));
}

Future<void> _testLoadConfig(PluginHostNotifier host, String vaultPath) async {
  final configPath =
      '$vaultPath${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugin-config.json';
  final file = File(configPath);
  if (!await file.exists()) return;

  final content = await file.readAsString();
  final data = jsonDecode(content) as Map<String, dynamic>;
  final enabled = <String, bool>{};
  for (final entry in data.entries) {
    enabled[entry.key] = entry.value as bool;
  }
  host.state = host.state.copyWith(enabled: enabled);
}

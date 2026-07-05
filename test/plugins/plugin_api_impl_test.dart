// Covers acceptance criteria:
// - G14-A: Capability checker enforces permissions on every plugin API call
// - AC-P4-2-1: PluginApiImpl.dispatch routes string API names to typed methods
// - AC-P4-2-2: Five sub-APIs (Knowledge/Browser/AI/UI/Agent) delegate to host services
// - AC-P4-2-3: Unknown API names throw UnimplementedError
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/plugins/api/plugin_api_impl.dart';
import 'package:rfbrowser/plugins/api/plugin_ui_notifier.dart';
import 'package:rfbrowser/plugins/host/capability_checker.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';
import 'package:rfbrowser/services/browser_service.dart';

/// Provider that exposes its own [Ref] so tests can construct a
/// [PluginApiImpl] without a full widget tree.
final _testRefProvider = Provider<Ref>((ref) => ref);

PluginManifest _manifest(List<Permission> perms) =>
    PluginManifest(id: 'test-plugin', name: 'Test Plugin', permissions: perms);

PluginApiImpl _createApi(ProviderContainer container, List<Permission> perms) {
  final ref = container.read(_testRefProvider);
  return PluginApiImpl(
    ref: ref,
    pluginId: 'test-plugin',
    manifest: _manifest(perms),
  );
}

void main() {
  group('PluginApiImpl.dispatch routing', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('knowledge.getNote returns error when note not found', () async {
      final api = _createApi(container, [Permission.knowledgeRead]);
      final result = await api.dispatch('knowledge.getNote', {'id': 'x.md'});
      expect(result['error'], 'Note not found');
    });

    test('knowledge.queryNotes returns empty list when no vault', () async {
      final api = _createApi(container, [Permission.knowledgeRead]);
      final result = await api.dispatch('knowledge.queryNotes', {});
      expect(result['results'], isEmpty);
    });

    test('knowledge.createNote returns error when no vault', () async {
      final api = _createApi(container, [Permission.knowledgeWrite]);
      final result = await api.dispatch('knowledge.createNote', {
        'title': 'New Note',
      });
      expect(result['error'], 'No vault open');
    });

    test('knowledge.updateNote returns updated true when no vault', () async {
      final api = _createApi(container, [Permission.knowledgeWrite]);
      final result = await api.dispatch('knowledge.updateNote', {
        'id': 'x.md',
        'content': 'new content',
      });
      expect(result['updated'], true);
    });

    test('browser.getCurrentUrl returns empty url when no tabs', () async {
      final api = _createApi(container, [Permission.browserRead]);
      final result = await api.dispatch('browser.getCurrentUrl', {});
      expect(result['url'], '');
    });

    test('browser.extractText returns empty text when no active tab', () async {
      final api = _createApi(container, [Permission.browserRead]);
      final result = await api.dispatch('browser.extractText', {});
      expect(result['text'], '');
    });

    test('browser.getPageContent alias returns empty text', () async {
      final api = _createApi(container, [Permission.browserRead]);
      final result = await api.dispatch('browser.getPageContent', {});
      expect(result['text'], '');
    });

    test(
      'browser.navigateTo creates a tab and returns navigated true',
      () async {
        final api = _createApi(container, [Permission.browserWrite]);
        final result = await api.dispatch('browser.navigateTo', {
          'url': 'https://example.com',
        });
        expect(result['navigated'], true);

        final browserState = container.read(browserProvider);
        expect(browserState.tabs, isNotEmpty);
        expect(browserState.activeTab?.url, 'https://example.com');
      },
    );

    test(
      'ui.showNotification adds a notification and returns shown true',
      () async {
        final api = _createApi(container, [Permission.uiCommand]);
        final result = await api.dispatch('ui.showNotification', {
          'message': 'Hello from plugin',
        });
        expect(result['shown'], true);

        final uiState = container.read(pluginUiProvider);
        expect(uiState.notifications, isNotEmpty);
        expect(uiState.notifications.last.message, 'Hello from plugin');
        expect(uiState.notifications.last.pluginId, 'test-plugin');
      },
    );

    test(
      'ui.registerCommand registers a command and returns registered true',
      () async {
        final api = _createApi(container, [Permission.uiCommand]);
        final result = await api.dispatch('ui.registerCommand', {
          'id': 'cmd1',
          'name': 'Run Test',
        });
        expect(result['registered'], true);

        final hostState = container.read(pluginHostProvider);
        expect(hostState.commands['test-plugin'], isNotEmpty);
        expect(hostState.commands['test-plugin']!.first.label, 'Run Test');
      },
    );

    test('ui.showPanel adds a panel and returns shown true', () async {
      final api = _createApi(container, [Permission.uiPanel]);
      final result = await api.dispatch('ui.showPanel', {
        'id': 'panel1',
        'title': 'My Panel',
        'content': 'Panel content',
      });
      expect(result['shown'], true);

      final uiState = container.read(pluginUiProvider);
      expect(uiState.panels['panel1'], isNotNull);
      expect(uiState.panels['panel1']!.title, 'My Panel');
    });

    test('ai.chat route enforces aiChat permission (G14-A)', () async {
      final api = _createApi(container, []);
      expect(
        () => api.dispatch('ai.chat', {'message': 'hi'}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('ai.complete route enforces aiChat permission (G14-A)', () async {
      final api = _createApi(container, []);
      expect(
        () => api.dispatch('ai.complete', {'prompt': 'hi'}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('agent.listTools route enforces aiChat permission (G14-A)', () async {
      final api = _createApi(container, []);
      expect(
        () => api.dispatch('agent.listTools', {}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test(
      'agent.executeTask route enforces aiChat permission (G14-A)',
      () async {
        final api = _createApi(container, []);
        expect(
          () => api.dispatch('agent.executeTask', {'name': 'task'}),
          throwsA(isA<PluginCapabilityDeniedError>()),
        );
      },
    );

    test('agent.listTasks route enforces aiChat permission (G14-A)', () async {
      final api = _createApi(container, []);
      expect(
        () => api.dispatch('agent.listTasks', {}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('unknown API name throws UnimplementedError', () async {
      final api = _createApi(container, [Permission.knowledgeRead]);
      expect(
        () => api.dispatch('unknown.api', {}),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test(
      'agent.toolExecute is not a known dispatch route (throws UnimplementedError)',
      () async {
        final api = _createApi(container, [Permission.aiChat]);
        expect(
          () => api.dispatch('agent.toolExecute', {
            'toolName': 'test',
            'args': {},
          }),
          throwsA(isA<UnimplementedError>()),
        );
      },
    );
  });

  group('PluginApiImpl sub-APIs', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    group('KnowledgeAPI', () {
      test('getNote returns null when no vault', () async {
        final api = _createApi(container, [Permission.knowledgeRead]);
        final result = await api.knowledge.getNote('x.md');
        expect(result, isNull);
      });

      test('queryNotes returns empty list when no vault', () async {
        final api = _createApi(container, [Permission.knowledgeRead]);
        final result = await api.knowledge.queryNotes({});
        expect(result, isEmpty);
      });

      test('createNote returns error when no vault', () async {
        final api = _createApi(container, [Permission.knowledgeWrite]);
        final result = await api.knowledge.createNote({'title': 'New'});
        expect(result['error'], 'No vault open');
      });

      test('updateNote does nothing when no vault', () async {
        final api = _createApi(container, [Permission.knowledgeWrite]);
        await api.knowledge.updateNote('x.md', 'content');
        // Completes without exception
      });
    });

    group('BrowserAPI', () {
      test('getCurrentUrl returns null when no tabs', () async {
        final api = _createApi(container, [Permission.browserRead]);
        final result = await api.browser.getCurrentUrl();
        expect(result, isNull);
      });

      test('getPageContent returns empty string when no active tab', () async {
        final api = _createApi(container, [Permission.browserRead]);
        final result = await api.browser.getPageContent();
        expect(result, '');
      });

      test('navigateTo creates a new tab', () async {
        final api = _createApi(container, [Permission.browserWrite]);
        await api.browser.navigateTo('https://example.com');
        final browserState = container.read(browserProvider);
        expect(browserState.tabs, isNotEmpty);
        expect(browserState.activeTab?.url, 'https://example.com');
      });
    });

    group('UIAPI', () {
      test('showNotification adds a notification', () {
        final api = _createApi(container, [Permission.uiCommand]);
        api.ui.showNotification('Test notification');
        final uiState = container.read(pluginUiProvider);
        expect(uiState.notifications, hasLength(1));
        expect(uiState.notifications.first.message, 'Test notification');
        expect(uiState.notifications.first.pluginId, 'test-plugin');
      });

      test('showPanel adds a panel', () {
        final api = _createApi(container, [Permission.uiPanel]);
        api.ui.showPanel('p1', 'Panel Title', 'content');
        final uiState = container.read(pluginUiProvider);
        expect(uiState.panels['p1'], isNotNull);
        expect(uiState.panels['p1']!.title, 'Panel Title');
        expect(uiState.panels['p1']!.pluginId, 'test-plugin');
      });

      test('registerCommand registers a command with the host', () {
        final api = _createApi(container, [Permission.uiCommand]);
        api.ui.registerCommand('cmd1', 'Command 1', () {});
        final hostState = container.read(pluginHostProvider);
        expect(hostState.commands['test-plugin'], hasLength(1));
        expect(hostState.commands['test-plugin']!.first.id, 'cmd1');
        expect(hostState.commands['test-plugin']!.first.label, 'Command 1');
      });
    });

    group('AIAPI', () {
      test('chat throws PluginCapabilityDeniedError without aiChat', () async {
        final api = _createApi(container, []);
        expect(
          () => api.ai.chat('hi'),
          throwsA(isA<PluginCapabilityDeniedError>()),
        );
      });

      test(
        'complete throws PluginCapabilityDeniedError without aiChat',
        () async {
          final api = _createApi(container, []);
          expect(
            () => api.ai.complete('prompt'),
            throwsA(isA<PluginCapabilityDeniedError>()),
          );
        },
      );
    });

    group('AgentAPI', () {
      test(
        'listTools throws PluginCapabilityDeniedError without aiChat',
        () async {
          final api = _createApi(container, []);
          expect(
            () => api.agent.listTools(),
            throwsA(isA<PluginCapabilityDeniedError>()),
          );
        },
      );

      test(
        'registerTool throws PluginCapabilityDeniedError without aiChat',
        () async {
          final api = _createApi(container, []);
          expect(
            () => api.agent.registerTool({}),
            throwsA(isA<PluginCapabilityDeniedError>()),
          );
        },
      );

      test(
        'unregisterTool throws PluginCapabilityDeniedError without aiChat',
        () async {
          final api = _createApi(container, []);
          expect(
            () => api.agent.unregisterTool('test'),
            throwsA(isA<PluginCapabilityDeniedError>()),
          );
        },
      );

      test(
        'executeTask throws PluginCapabilityDeniedError without aiChat',
        () async {
          final api = _createApi(container, []);
          expect(
            () => api.agent.executeTask({}),
            throwsA(isA<PluginCapabilityDeniedError>()),
          );
        },
      );

      test(
        'getTaskStatus throws PluginCapabilityDeniedError without aiChat',
        () async {
          final api = _createApi(container, []);
          expect(
            () => api.agent.getTaskStatus('x'),
            throwsA(isA<PluginCapabilityDeniedError>()),
          );
        },
      );

      test(
        'listTasks throws PluginCapabilityDeniedError without aiChat',
        () async {
          final api = _createApi(container, []);
          expect(
            () => api.agent.listTasks(),
            throwsA(isA<PluginCapabilityDeniedError>()),
          );
        },
      );
    });
  });

  group('PluginApiImpl permission checks (G14-A)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('knowledge.getNote throws without knowledgeRead', () async {
      final api = _createApi(container, []);
      expect(
        () => api.knowledge.getNote('x'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('knowledge.queryNotes throws without knowledgeRead', () async {
      final api = _createApi(container, []);
      expect(
        () => api.knowledge.queryNotes({}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('knowledge.searchNotes throws without knowledgeRead', () async {
      final api = _createApi(container, []);
      expect(
        () => api.knowledge.searchNotes('query'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('knowledge.createNote throws without knowledgeWrite', () async {
      final api = _createApi(container, [Permission.knowledgeRead]);
      expect(
        () => api.knowledge.createNote({}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('knowledge.updateNote throws without knowledgeWrite', () async {
      final api = _createApi(container, [Permission.knowledgeRead]);
      expect(
        () => api.knowledge.updateNote('x', 'c'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('browser.getCurrentUrl throws without browserRead', () async {
      final api = _createApi(container, []);
      expect(
        () => api.browser.getCurrentUrl(),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('browser.getPageContent throws without browserRead', () async {
      final api = _createApi(container, []);
      expect(
        () => api.browser.getPageContent(),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('browser.navigateTo throws without browserWrite', () async {
      final api = _createApi(container, [Permission.browserRead]);
      expect(
        () => api.browser.navigateTo('https://example.com'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('ai.chat throws without aiChat', () async {
      final api = _createApi(container, []);
      expect(
        () => api.ai.chat('hi'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('ai.complete throws without aiChat', () async {
      final api = _createApi(container, []);
      expect(
        () => api.ai.complete('hi'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('ui.showNotification throws without uiCommand', () {
      final api = _createApi(container, []);
      expect(
        () => api.ui.showNotification('hi'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('ui.registerCommand throws without uiCommand', () {
      final api = _createApi(container, []);
      expect(
        () => api.ui.registerCommand('id', 'name', () {}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('ui.showPanel throws without uiPanel', () {
      final api = _createApi(container, [Permission.uiCommand]);
      expect(
        () => api.ui.showPanel('id', 'title', 'content'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('agent.listTools throws without aiChat', () async {
      final api = _createApi(container, []);
      expect(
        () => api.agent.listTools(),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('agent.registerTool throws without aiChat', () async {
      final api = _createApi(container, []);
      expect(
        () => api.agent.registerTool({}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('agent.unregisterTool throws without aiChat', () async {
      final api = _createApi(container, []);
      expect(
        () => api.agent.unregisterTool('test'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('agent.executeTask throws without aiChat', () async {
      final api = _createApi(container, []);
      expect(
        () => api.agent.executeTask({}),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('agent.getTaskStatus throws without aiChat', () async {
      final api = _createApi(container, []);
      expect(
        () => api.agent.getTaskStatus('x'),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('agent.listTasks throws without aiChat', () async {
      final api = _createApi(container, []);
      expect(
        () => api.agent.listTasks(),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test('permission error contains correct pluginId and permission', () async {
      final api = _createApi(container, []);
      try {
        await api.knowledge.getNote('x');
        fail('Should have thrown');
      } on PluginCapabilityDeniedError catch (e) {
        expect(e.pluginId, 'test-plugin');
        expect(e.permission, Permission.knowledgeRead);
      }
    });
  });
}

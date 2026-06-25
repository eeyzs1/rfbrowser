import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent_task.dart';
import '../../data/models/note.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/stores/index_store.dart';
import '../../services/agent/agent_tool.dart';
import '../../services/agent_service.dart';
import '../../services/ai_service.dart';
import '../../services/browser_service.dart';
import '../host/capability_checker.dart';
import '../host/plugin_host.dart';
import 'plugin_api.dart';
import 'plugin_ui_notifier.dart';

/// Callback invoked when a plugin-registered agent tool is executed by the
/// agent runtime. The host routes this back into the plugin sandbox so the
/// plugin can fulfil the tool call. See [_AgentAPIImpl.registerTool].
typedef PluginToolExecutor =
    Future<Map<String, dynamic>> Function(
      String toolName,
      Map<String, dynamic> toolArgs,
    );

/// Concrete [PluginAPI] implementation backed by the host's Riverpod
/// services.
///
/// Each capability-protected call flows through [CapabilityChecker]
/// first (G14-A), then delegates to the real service. This is the typed
/// surface used by the JS plugin runtime (isolate side) via the sandbox
/// message protocol, and by [PluginHostNotifier._handleApiCall] on the
/// host side.
class PluginApiImpl implements PluginAPI {
  final Ref _ref;
  final String _pluginId;
  final CapabilityChecker _checker;
  final PluginToolExecutor? _onToolExecute;

  @override
  late final KnowledgeAPI knowledge;
  @override
  late final BrowserAPI browser;
  @override
  late final AIAPI ai;
  @override
  late final UIAPI ui;
  @override
  late final AgentAPI agent;

  PluginApiImpl({
    required Ref ref,
    required String pluginId,
    required PluginManifest manifest,
    PluginToolExecutor? onToolExecute,
  })  : _ref = ref,
        _pluginId = pluginId,
        _checker = CapabilityChecker(pluginId: pluginId, manifest: manifest),
        _onToolExecute = onToolExecute {
    knowledge = _KnowledgeAPIImpl(_checker, _ref);
    browser = _BrowserAPIImpl(_checker, _ref);
    ai = _AIAPIImpl(_checker, _ref);
    ui = _UIAPIImpl(_checker, _ref, _pluginId);
    agent = _AgentAPIImpl(_checker, _ref, _pluginId, _onToolExecute);
  }

  /// Dispatch a string API name (as used by the sandbox message protocol)
  /// to the corresponding typed method. Keeps the wire protocol backward
  /// compatible while routing through the capability-checked API surface.
  Future<Map<String, dynamic>> dispatch(
    String apiName,
    Map<String, dynamic> args,
  ) async {
    switch (apiName) {
      case 'knowledge.getNote':
        final note = await knowledge.getNote(args['id'] as String? ?? '');
        return note ?? {'error': 'Note not found'};
      case 'knowledge.queryNotes':
        return {'results': await knowledge.queryNotes(args)};
      case 'knowledge.search':
        return {
          'results': await knowledge.searchNotes(
            args['query'] as String? ?? '',
          ),
        };
      case 'knowledge.createNote':
        return await knowledge.createNote(args);
      case 'knowledge.updateNote':
        await knowledge.updateNote(
          args['id'] as String? ?? '',
          args['content'] as String? ?? '',
        );
        return {'updated': true};
      case 'browser.getCurrentUrl':
        return {'url': await browser.getCurrentUrl() ?? ''};
      case 'browser.extractText':
      case 'browser.getPageContent':
        return {'text': await browser.getPageContent()};
      case 'browser.navigateTo':
        await browser.navigateTo(args['url'] as String? ?? '');
        return {'navigated': true};
      case 'ai.chat':
        return {
          'reply': await ai.chat(
            args['message'] as String? ?? '',
            systemPrompt: args['systemPrompt'] as String?,
          ),
        };
      case 'ai.complete':
        return {'text': await ai.complete(args['prompt'] as String? ?? '')};
      case 'ui.showNotification':
        ui.showNotification(args['message'] as String? ?? '');
        return {'shown': true};
      case 'ui.registerCommand':
        ui.registerCommand(
          args['id'] as String? ?? '',
          args['name'] as String? ?? '',
          () {},
        );
        return {'registered': true};
      case 'ui.showPanel':
        ui.showPanel(
          args['id'] as String? ?? '',
          args['title'] as String? ?? '',
          args['content'],
        );
        return {'shown': true};
      case 'agent.createTask':
      case 'agent.executeTask':
        return await agent.executeTask(args);
      case 'agent.getStatus':
      case 'agent.getTaskStatus':
        final status = await agent.getTaskStatus(args['id'] as String? ?? '');
        return status ?? {'error': 'Task not found'};
      case 'agent.listTools':
        return {'tools': await agent.listTools()};
      case 'agent.registerTool':
        await agent.registerTool(
          (args['tool'] as Map<String, dynamic>?) ?? {},
        );
        return {'registered': true};
      case 'agent.unregisterTool':
        await agent.unregisterTool(args['toolName'] as String? ?? '');
        return {'unregistered': true};
      case 'agent.listTasks':
        return {'tasks': await agent.listTasks()};
      default:
        throw UnimplementedError('Unknown API: $apiName');
    }
  }
}

class _KnowledgeAPIImpl implements KnowledgeAPI {
  final CapabilityChecker _checker;
  final Ref _ref;

  _KnowledgeAPIImpl(this._checker, this._ref);

  @override
  Future<Map<String, dynamic>?> getNote(String id) async {
    _checker.assertCapability(Permission.knowledgeRead);
    final repo = _ref.read(noteRepositoryProvider);
    if (repo == null) return null;
    final note = await repo.getNoteByPath(id);
    return note?._toMap();
  }

  @override
  Future<List<Map<String, dynamic>>> queryNotes(Map<String, dynamic> spec) async {
    _checker.assertCapability(Permission.knowledgeRead);
    final query = spec['query'] as String?;
    if (query != null && query.isNotEmpty) {
      return _ref.read(indexStoreProvider).searchNotes(query);
    }
    final repo = _ref.read(noteRepositoryProvider);
    if (repo == null) return [];
    final notes = await repo.getAllNotes();
    return notes.map((n) => n._toMap()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    _checker.assertCapability(Permission.knowledgeRead);
    return _ref.read(indexStoreProvider).searchNotes(query);
  }

  @override
  Future<Map<String, dynamic>> createNote(Map<String, dynamic> spec) async {
    _checker.assertCapability(Permission.knowledgeWrite);
    final repo = _ref.read(noteRepositoryProvider);
    if (repo == null) return {'error': 'No vault open'};
    final note = await repo.createNote(
      title: spec['title'] as String? ?? 'Untitled',
      folder: spec['folder'] as String? ?? '',
    );
    return note._toMap();
  }

  @override
  Future<void> updateNote(String id, String content) async {
    _checker.assertCapability(Permission.knowledgeWrite);
    final repo = _ref.read(noteRepositoryProvider);
    if (repo == null) return;
    final note = await repo.getNoteByPath(id);
    if (note == null) return;
    note.content = content;
    await repo.saveNote(note);
  }
}

class _BrowserAPIImpl implements BrowserAPI {
  final CapabilityChecker _checker;
  final Ref _ref;

  _BrowserAPIImpl(this._checker, this._ref);

  @override
  Future<String?> getCurrentUrl() async {
    _checker.assertCapability(Permission.browserRead);
    return _ref.read(browserProvider).activeTab?.url;
  }

  @override
  Future<String> getPageContent() async {
    _checker.assertCapability(Permission.browserRead);
    final activeId = _ref.read(browserProvider).activeTabId;
    if (activeId == null) return '';
    final content = await _ref
        .read(browserProvider.notifier)
        .fetchPageContent(activeId);
    return content?.text ?? '';
  }

  @override
  Future<void> navigateTo(String url) async {
    _checker.assertCapability(Permission.browserWrite);
    _ref.read(browserProvider.notifier).createTab(url: url);
  }
}

class _AIAPIImpl implements AIAPI {
  final CapabilityChecker _checker;
  final Ref _ref;

  _AIAPIImpl(this._checker, this._ref);

  @override
  Future<String> chat(String message, {String? systemPrompt}) async {
    _checker.assertCapability(Permission.aiChat);
    final ai = _ref.read(aiProvider.notifier);
    await ai.sendMessage(message, systemPrompt: systemPrompt);
    final messages = _ref.read(aiProvider).messages;
    for (final m in messages.reversed) {
      if (m.role == 'assistant' && !m.isStreaming) {
        return m.content;
      }
    }
    return '';
  }

  @override
  Future<String> complete(String prompt) => chat(prompt);
}

class _UIAPIImpl implements UIAPI {
  final CapabilityChecker _checker;
  final Ref _ref;
  final String _pluginId;

  _UIAPIImpl(this._checker, this._ref, this._pluginId);

  @override
  void showNotification(String message) {
    _checker.assertCapability(Permission.uiCommand);
    _ref.read(pluginUiProvider.notifier).notify(_pluginId, message);
  }

  @override
  void registerCommand(
    String id,
    String name,
    void Function() handler,
  ) {
    _checker.assertCapability(Permission.uiCommand);
    // handler cannot cross the isolate boundary; the host records the
    // command metadata so the UI can surface it. The plugin receives tool
    // invocations via the agent.toolExecute API when the command is run.
    _ref.read(pluginHostProvider.notifier).registerCommand(
          PluginCommand(id: id, label: name, pluginId: _pluginId),
        );
  }

  @override
  void showPanel(String id, String title, dynamic content) {
    _checker.assertCapability(Permission.uiPanel);
    _ref.read(pluginUiProvider.notifier).showPanel(
          _pluginId,
          id,
          title,
          content,
        );
  }
}

class _AgentAPIImpl implements AgentAPI {
  final CapabilityChecker _checker;
  final Ref _ref;
  final String _pluginId;
  final PluginToolExecutor? _onToolExecute;

  _AgentAPIImpl(this._checker, this._ref, this._pluginId, this._onToolExecute);

  @override
  Future<List<Map<String, dynamic>>> listTools() async {
    _checker.assertCapability(Permission.aiChat);
    return _ref
        .read(agentProvider.notifier)
        .toolRegistry
        .allToolDefinitions();
  }

  @override
  Future<void> registerTool(Map<String, dynamic> toolDefinition) async {
    _checker.assertCapability(Permission.aiChat);
    final agent = _ref.read(agentProvider.notifier);
    final pluginTool = _PluginAgentTool(
      name: toolDefinition['name'] as String? ?? '',
      description: toolDefinition['description'] as String? ?? '',
      parametersSchema:
          (toolDefinition['parameters'] as Map<String, dynamic>?) ?? {},
      isDestructive: toolDefinition['isDestructive'] as bool? ?? false,
      source: toolDefinition['source'] as String? ?? 'plugin:$_pluginId',
      onToolExecute: _onToolExecute,
    );
    agent.registerPluginTool(pluginTool);
  }

  @override
  Future<void> unregisterTool(String toolName) async {
    _checker.assertCapability(Permission.aiChat);
    _ref.read(agentProvider.notifier).unregisterPluginTool(toolName);
  }

  @override
  Future<Map<String, dynamic>> executeTask(Map<String, dynamic> taskSpec) async {
    _checker.assertCapability(Permission.aiChat);
    final agent = _ref.read(agentProvider.notifier);
    final modeStr = taskSpec['mode'] as String? ?? 'manual';
    final mode = TaskMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => TaskMode.manual,
    );
    final task = AgentTask(
      id: 'plugin_${DateTime.now().millisecondsSinceEpoch}',
      name: taskSpec['name'] as String? ?? 'Plugin Task',
      description: taskSpec['description'] as String? ?? '',
      mode: mode,
      steps:
          (taskSpec['steps'] as List?)
              ?.map((s) {
                if (s is Map<String, dynamic>) {
                  return AgentStep(
                    description: s['description'] as String? ?? '',
                    toolName: s['tool'] as String?,
                    args: (s['args'] as Map<String, dynamic>?) ?? {},
                  );
                }
                return AgentStep(description: s.toString());
              })
              .toList() ??
              [],
    );
    await agent.executeTask(task);
    return {'taskId': task.id, 'status': task.status.name};
  }

  @override
  Future<Map<String, dynamic>?> getTaskStatus(String taskId) async {
    _checker.assertCapability(Permission.aiChat);
    final task = _ref.read(agentProvider.notifier).getTask(taskId);
    if (task == null) return null;
    return {
      'id': task.id,
      'status': task.status.name,
      'result': task.result,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listTasks() async {
    _checker.assertCapability(Permission.aiChat);
    return _ref
        .read(agentProvider)
        .tasks
        .map((t) => {
              'id': t.id,
              'name': t.name,
              'status': t.status.name,
              'mode': t.mode.name,
            })
        .toList();
  }
}

/// Agent tool whose execution is delegated back to the plugin sandbox via
/// [PluginToolExecutor]. Mirrors the legacy `_PluginAgentTool` that lived
/// in `plugin_host_notifier.dart`; kept here so the typed API surface is
/// self-contained.
class _PluginAgentTool extends AgentTool {
  final PluginToolExecutor? _onToolExecute;

  _PluginAgentTool({
    required super.name,
    required super.description,
    required super.parametersSchema,
    required super.isDestructive,
    required super.source,
    PluginToolExecutor? onToolExecute,
  }) : _onToolExecute = onToolExecute;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    if (_onToolExecute == null) {
      return ToolResult.failure(
        'Plugin tool "$name" has no executor (plugin not running)',
      );
    }
    try {
      final result = await _onToolExecute(name, args);
      return ToolResult(
        success: result['success'] as bool? ?? false,
        output: result['output'] as String? ?? '',
        error: result['error'] as String?,
      );
    } catch (e) {
      return ToolResult.failure(e.toString());
    }
  }
}

/// Serialise a [Note] to the wire format expected by plugin API consumers.
extension _NoteToMap on Note {
  Map<String, dynamic> _toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'filePath': filePath,
        'tags': tags,
      };
}

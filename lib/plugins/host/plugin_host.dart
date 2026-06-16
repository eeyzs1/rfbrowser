// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/stores/index_store.dart';
import '../../services/agent/agent_tool.dart';
import '../../services/browser_service.dart';
import '../../services/agent_service.dart';
import '../../data/models/agent_task.dart';

enum Permission {
  knowledgeRead,
  knowledgeWrite,
  browserRead,
  browserWrite,
  aiChat,
  uiCommand,
  uiPanel,
}

class PluginManifest {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final List<Permission> permissions;

  PluginManifest({
    required this.id,
    required this.name,
    this.version = '0.1.0',
    this.author = '',
    this.description = '',
    this.permissions = const [],
  });

  factory PluginManifest.fromMap(Map<String, dynamic> map) => PluginManifest(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    version: map['version'] as String? ?? '0.1.0',
    author: map['author'] as String? ?? '',
    description: map['description'] as String? ?? '',
    permissions:
        (map['permissions'] as List?)
            ?.map(
              (p) => Permission.values.firstWhere(
                (e) => e.name == p,
                orElse: () => Permission.knowledgeRead,
              ),
            )
            .toList() ??
        [],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'permissions': permissions.map((p) => p.name).toList(),
  };
}

class PluginCommand {
  final String id;
  final String label;
  final String pluginId;

  PluginCommand({
    required this.id,
    required this.label,
    required this.pluginId,
  });
}

class PluginHook {
  final String event;
  final String handler;

  PluginHook({required this.event, required this.handler});

  factory PluginHook.fromMap(Map<String, dynamic> map) => PluginHook(
    event: map['event'] as String? ?? '',
    handler: map['handler'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {'event': event, 'handler': handler};
}

class PluginState {
  final Map<String, PluginManifest> manifests;
  final Map<String, bool> enabled;
  final Map<String, bool> running;
  final Map<String, List<PluginCommand>> commands;
  final String? error;

  PluginState({
    this.manifests = const {},
    this.enabled = const {},
    this.running = const {},
    this.commands = const {},
    this.error,
  });

  PluginState copyWith({
    Map<String, PluginManifest>? manifests,
    Map<String, bool>? enabled,
    Map<String, bool>? running,
    Map<String, List<PluginCommand>>? commands,
    String? error,
    bool clearError = false,
  }) {
    return PluginState(
      manifests: manifests ?? this.manifests,
      enabled: enabled ?? this.enabled,
      running: running ?? this.running,
      commands: commands ?? this.commands,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PermissionChecker {
  bool check(PluginManifest manifest, Permission permission) {
    return manifest.permissions.contains(permission);
  }

  List<Permission> missingPermissions(
    PluginManifest manifest,
    List<Permission> required,
  ) {
    return required.where((p) => !manifest.permissions.contains(p)).toList();
  }
}

class _ApiRequest {
  final String id;
  final String apiName;
  final Map<String, dynamic> args;
  final Permission requiredPermission;

  _ApiRequest({
    required this.id,
    required this.apiName,
    required this.args,
    required this.requiredPermission,
  });

  Map<String, dynamic> toMap() => {
    'type': 'apiRequest',
    'id': id,
    'apiName': apiName,
    'args': args,
    'requiredPermission': requiredPermission.name,
  };
}

class _ApiResponse {
  final String id;
  final bool success;
  final dynamic result;
  final String? error;

  _ApiResponse({
    required this.id,
    required this.success,
    this.result,
    this.error,
  });

  factory _ApiResponse.fromMap(Map<String, dynamic> map) => _ApiResponse(
    id: map['id'] as String? ?? '',
    success: map['success'] as bool? ?? false,
    result: map['result'],
    error: map['error'] as String?,
  );
}

typedef ApiHandler =
    Future<Map<String, dynamic>> Function(
      String apiName,
      Map<String, dynamic> args,
    );

class Sandbox {
  final String pluginId;
  final PluginManifest manifest;
  final PermissionChecker _permissionChecker = PermissionChecker();
  final _errorController = StreamController<String>.broadcast();
  final ApiHandler _apiHandler;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _pluginSendPort;
  bool _isRunning = false;
  int _requestId = 0;
  final Map<String, Completer<_ApiResponse>> _pendingRequests = {};
  StreamSubscription? _receiveSubscription;
  Timer? _crashRecoveryTimer;
  int _crashCount = 0;
  static const int _maxCrashRecovery = 3;
  static const Duration _crashRecoveryDelay = Duration(seconds: 3);
  Completer<void>? _sendPortReady;

  Sandbox({
    required this.pluginId,
    required this.manifest,
    required ApiHandler apiHandler,
  }) : _apiHandler = apiHandler;

  bool get isRunning => _isRunning;

  Stream<String> get onError => _errorController.stream;

  int get crashCount => _crashCount;

  Future<void> start() async {
    _receivePort = ReceivePort();
    _sendPortReady = Completer<void>();
    _receiveSubscription = _receivePort!.listen(_handleMessage);

    try {
      _isolate = await Isolate.spawn(
        _pluginEntryPoint,
        _PluginStartMessage(
          sendPort: _receivePort!.sendPort,
          manifestMap: manifest.toMap(),
        ),
        errorsAreFatal: false,
        onError: _receivePort!.sendPort,
        onExit: _receivePort!.sendPort,
      );
      _isRunning = true;
      await _sendPortReady!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    } catch (e) {
      _isRunning = false;
      _errorController.add('Failed to start isolate: $e');
      rethrow;
    }
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      _pluginSendPort = message;
      if (_sendPortReady != null && !_sendPortReady!.isCompleted) {
        _sendPortReady!.complete();
      }
      return;
    }

    if (message is List && message.length == 2) {
      final errorCode = message[0];
      final errorStack = message[1];
      _handleIsolateError(errorCode, errorStack);
      return;
    }

    if (message == null) {
      _handleIsolateExit();
      return;
    }

    if (message is Map<String, dynamic>) {
      final type = message['type'];
      if (type == 'apiRequest') {
        _handleApiRequest(message);
      } else if (type == 'apiResponse') {
        final response = _ApiResponse.fromMap(message);
        _pendingRequests.remove(response.id)?.complete(response);
      } else if (type == 'error') {
        _errorController.add(
          message['message'] as String? ?? 'Unknown plugin error',
        );
      }
    }
  }

  void _handleIsolateError(dynamic code, dynamic stack) {
    _isRunning = false;
    final errorMsg = 'Plugin isolate error: $code\n$stack';
    _errorController.add(errorMsg);
    _crashCount++;

    if (_crashCount <= _maxCrashRecovery) {
      _crashRecoveryTimer?.cancel();
      _crashRecoveryTimer = Timer(_crashRecoveryDelay, () async {
        try {
          await start();
        } catch (_) {
          print('PluginHost: failed to restart after crash recovery');
        }
      });
    }
  }

  void _handleIsolateExit() {
    _isRunning = false;
    if (_crashCount < _maxCrashRecovery) {
      _crashRecoveryTimer?.cancel();
      _crashRecoveryTimer = Timer(_crashRecoveryDelay, () async {
        try {
          await start();
        } catch (_) {
          print('PluginHost: failed to restart after isolate exit');
        }
      });
    }
  }

  Future<void> _handleApiRequest(Map<String, dynamic> requestMap) async {
    final requestId = requestMap['id'] as String? ?? '';
    final apiName = requestMap['apiName'] as String? ?? '';
    final args = requestMap['args'] as Map<String, dynamic>? ?? {};
    final permName = requestMap['requiredPermission'] as String? ?? '';

    final permission = Permission.values.firstWhere(
      (e) => e.name == permName,
      orElse: () => Permission.knowledgeRead,
    );

    _ApiResponse response;

    if (!_permissionChecker.check(manifest, permission)) {
      response = _ApiResponse(
        id: requestId,
        success: false,
        error:
            'PermissionDeniedError: Plugin "${manifest.name}" lacks permission: ${permission.name}',
      );
    } else {
      try {
        final result = await _apiHandler(apiName, args);
        response = _ApiResponse(id: requestId, success: true, result: result);
      } catch (e) {
        response = _ApiResponse(
          id: requestId,
          success: false,
          error: e.toString(),
        );
      }
    }

    _pluginSendPort?.send({
      'type': 'apiResponse',
      'id': response.id,
      'success': response.success,
      'result': response.result,
      'error': response.error,
    });
  }

  Future<T?> callApi<T>(
    String apiName,
    Map<String, dynamic> args, {
    required Permission requiredPermission,
  }) async {
    if (!_isRunning) throw StateError('Sandbox is not running');

    if (!_permissionChecker.check(manifest, requiredPermission)) {
      throw PermissionDeniedError(
        'Plugin "${manifest.name}" lacks permission: ${requiredPermission.name}',
      );
    }

    final requestId = '${pluginId}_${_requestId++}';
    final completer = Completer<_ApiResponse>();
    _pendingRequests[requestId] = completer;

    final request = _ApiRequest(
      id: requestId,
      apiName: apiName,
      args: args,
      requiredPermission: requiredPermission,
    );

    _pluginSendPort?.send(request.toMap());

    final response = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return _ApiResponse(
          id: requestId,
          success: false,
          error: 'API call timeout',
        );
      },
    );

    _pendingRequests.remove(requestId);

    if (!response.success) {
      if (response.error?.contains('PermissionDeniedError') == true) {
        throw PermissionDeniedError(response.error!);
      }
      throw Exception(response.error ?? 'API call failed');
    }

    return response.result as T?;
  }

  void reportError(String error) {
    _errorController.add(error);
  }

  void simulateCrashForTest() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _handleIsolateError('test_crash', 'simulated crash for testing');
  }

  Future<void> stop() async {
    _crashRecoveryTimer?.cancel();
    _crashRecoveryTimer = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isRunning = false;
    _pluginSendPort = null;
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    _receivePort?.close();
    _receivePort = null;
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Sandbox stopped');
      }
    }
    _pendingRequests.clear();
    await _errorController.close();
  }

  static void _pluginEntryPoint(_PluginStartMessage message) {
    final receivePort = ReceivePort();
    message.sendPort.send(receivePort.sendPort);

    receivePort.listen((dynamic msg) {
      if (msg is Map<String, dynamic> && msg['type'] == 'apiRequest') {
        final requestId = msg['id'] as String? ?? '';
        final apiName = msg['apiName'] as String? ?? '';
        final args = msg['args'] as Map<String, dynamic>? ?? {};

        message.sendPort.send({
          'type': 'apiRequest',
          'id': requestId,
          'apiName': apiName,
          'args': args,
          'requiredPermission': msg['requiredPermission'] ?? '',
        });
      } else if (msg is Map<String, dynamic> && msg['type'] == 'apiResponse') {
        final response = _ApiResponse.fromMap(msg);
        message.sendPort.send({
          'type': 'apiResponse',
          'id': response.id,
          'success': response.success,
          'result': response.result,
          'error': response.error,
        });
      }
    });
  }
}

class _PluginStartMessage {
  final SendPort sendPort;
  final Map<String, dynamic> manifestMap;

  _PluginStartMessage({required this.sendPort, required this.manifestMap});
}

class PermissionDeniedError implements Exception {
  final String message;
  PermissionDeniedError(this.message);

  @override
  String toString() => 'PermissionDeniedError: $message';
}

class PluginHostNotifier extends Notifier<PluginState> {
  final Map<String, Sandbox> _sandboxes = {};
  final Map<String, void Function(String event, Map<String, dynamic> data)>
  _hookHandlers = {};
  String? _vaultPath;

  @override
  PluginState build() => PluginState();

  Sandbox? getSandbox(String pluginId) => _sandboxes[pluginId];

  String _configPath() {
    final path = _vaultPath ?? ref.read(noteRepositoryProvider)?.vaultPath;
    if (path == null) return '';
    return '$path${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugin-config.json';
  }

  Future<void> loadConfig() async {
    final configPath = _configPath();
    if (configPath.isEmpty) return;
    final file = File(configPath);
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final enabled = <String, bool>{};
      for (final entry in data.entries) {
        enabled[entry.key] = entry.value as bool;
      }
      state = state.copyWith(enabled: enabled);

      for (final entry in enabled.entries) {
        if (entry.value && state.manifests.containsKey(entry.key)) {
          _startPluginSafely(entry.key);
        }
      }
    } catch (e) {
      debugPrint('PluginHost: failed to load plugin config: $e');
    }
  }

  Future<void> _saveConfig() async {
    final configPath = _configPath();
    if (configPath.isEmpty) return;
    final file = File(configPath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    try {
      await file.writeAsString(jsonEncode(state.enabled));
    } catch (e) {
      debugPrint('PluginHost: failed to save plugin config: $e');
    }
  }

  Future<void> registerManifest(PluginManifest manifest) async {
    if (state.manifests.containsKey(manifest.id)) return;

    state = state.copyWith(
      manifests: {...state.manifests, manifest.id: manifest},
    );
  }

  Future<void> setPluginEnabled(
    String pluginId,
    bool value, {
    void Function(PluginManifest manifest, PluginHostNotifier host)? onEnable,
    void Function(PluginManifest manifest, PluginHostNotifier host)? onDisable,
  }) async {
    final manifest = state.manifests[pluginId];
    if (manifest == null) return;

    final currentlyRunning = state.running[pluginId] == true;

    if (value && !currentlyRunning) {
      try {
        await _startSandbox(manifest);
        if (onEnable != null) onEnable(manifest, this);
        state = state.copyWith(
          enabled: {...state.enabled, pluginId: true},
          running: {...state.running, pluginId: true},
        );
      } catch (e) {
        state = state.copyWith(error: e.toString());
        return;
      }
    } else if (!value && currentlyRunning) {
      if (onDisable != null) onDisable(manifest, this);
      await _stopSandbox(pluginId);
      state = state.copyWith(
        enabled: {...state.enabled, pluginId: false},
        running: {...state.running}..remove(pluginId),
      );
    } else {
      state = state.copyWith(enabled: {...state.enabled, pluginId: value});
    }

    await _saveConfig();
  }

  Future<void> registerManifestAndEnable(
    PluginManifest manifest, {
    bool enabledByDefault = true,
    void Function(PluginManifest manifest, PluginHostNotifier host)? onEnable,
    void Function(PluginManifest manifest, PluginHostNotifier host)? onDisable,
  }) async {
    await registerManifest(manifest);

    final savedEnabled = state.enabled[manifest.id];
    final shouldEnable = savedEnabled ?? enabledByDefault;

    if (shouldEnable) {
      await setPluginEnabled(
        manifest.id,
        true,
        onEnable: onEnable,
        onDisable: onDisable,
      );
    }
  }

  Future<void> _startSandbox(PluginManifest manifest) async {
    final sandbox = Sandbox(
      pluginId: manifest.id,
      manifest: manifest,
      apiHandler: _handleApiCall,
    );
    await sandbox.start();
    _sandboxes[manifest.id] = sandbox;
    sandbox.onError.listen((error) {
      state = state.copyWith(error: error);
    });
  }

  Future<void> _stopSandbox(String pluginId) async {
    final sandbox = _sandboxes[pluginId];
    if (sandbox != null) {
      await sandbox.stop();
      _sandboxes.remove(pluginId);
    }
  }

  void _startPluginSafely(String pluginId) {
    final manifest = state.manifests[pluginId];
    if (manifest == null) return;
    _startSandbox(manifest)
        .then((_) {
          state = state.copyWith(running: {...state.running, pluginId: true});
        })
        .catchError((e) {
          state = state.copyWith(error: e.toString());
        });
  }

  Future<void> enablePlugin(PluginManifest manifest) async {
    final sandbox = Sandbox(
      pluginId: manifest.id,
      manifest: manifest,
      apiHandler: _handleApiCall,
    );

    try {
      await sandbox.start();
      _sandboxes[manifest.id] = sandbox;

      sandbox.onError.listen((error) {
        state = state.copyWith(error: error);
      });

      state = state.copyWith(
        manifests: {...state.manifests, manifest.id: manifest},
        running: {...state.running, manifest.id: true},
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Map<String, dynamic>> _handleApiCall(
    String apiName,
    Map<String, dynamic> args,
  ) async {
    switch (apiName) {
      case 'knowledge.getNote':
        final repo = ref.read(noteRepositoryProvider);
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
        final indexStore = ref.read(indexStoreProvider);
        final query = args['query'] as String? ?? '';
        final results = await indexStore.searchNotes(query);
        return {'results': results};
      case 'browser.getCurrentUrl':
        final browserState = ref.read(browserProvider);
        final activeTab = browserState.activeTab;
        return {'url': activeTab?.url ?? ''};
      case 'browser.extractText':
        final browserNotifier = ref.read(browserProvider.notifier);
        final activeId = ref.read(browserProvider).activeTabId;
        if (activeId == null) return {'text': ''};
        final content = await browserNotifier.fetchPageContent(activeId);
        return {'text': content?.text ?? ''};
      case 'agent.createTask':
        final agent = ref.read(agentProvider.notifier);
        final modeStr = args['mode'] as String? ?? 'manual';
        final mode = TaskMode.values.firstWhere(
          (e) => e.name == modeStr,
          orElse: () => TaskMode.manual,
        );
        final task = AgentTask(
          id: 'plugin_${DateTime.now().millisecondsSinceEpoch}',
          name: args['name'] as String? ?? 'Plugin Task',
          description: args['description'] as String? ?? '',
          mode: mode,
          steps:
              (args['steps'] as List?)?.map((s) {
                if (s is Map<String, dynamic>) {
                  return AgentStep(
                    description: s['description'] as String? ?? '',
                    toolName: s['tool'] as String?,
                    args: (s['args'] as Map<String, dynamic>?) ?? {},
                  );
                }
                return AgentStep(description: s.toString());
              }).toList() ??
              [],
        );
        await agent.executeTask(task);
        return {'taskId': task.id, 'status': task.status.name};
      case 'agent.getStatus':
        final agent = ref.read(agentProvider.notifier);
        final taskId = args['id'] as String? ?? '';
        final task = agent.getTask(taskId);
        if (task == null) return {'error': 'Task not found'};
        return {
          'id': task.id,
          'status': task.status.name,
          'result': task.result,
        };
      case 'agent.listTools':
        final agent = ref.read(agentProvider.notifier);
        return {'tools': agent.toolRegistry.allToolDefinitions()};
      case 'agent.registerTool':
        final agent = ref.read(agentProvider.notifier);
        final toolDef = args['tool'] as Map<String, dynamic>?;
        if (toolDef == null) return {'error': 'tool definition required'};
        final pluginTool = _PluginAgentTool(
          name: toolDef['name'] as String? ?? '',
          description: toolDef['description'] as String? ?? '',
          parametersSchema:
              (toolDef['parameters'] as Map<String, dynamic>?) ?? {},
          isDestructive: toolDef['isDestructive'] as bool? ?? false,
          source: toolDef['source'] as String? ?? 'plugin',
          executeFn: (toolArgs) async {
            final result = await callPluginApi(
              args['pluginId'] as String? ?? '',
              'agent.toolExecute',
              {'toolName': toolDef['name'], 'args': toolArgs},
              requiredPermission: Permission.aiChat,
            );
            return ToolResult(
              success: result?['success'] as bool? ?? false,
              output: result?['output'] as String? ?? '',
              error: result?['error'] as String?,
            );
          },
        );
        agent.registerPluginTool(pluginTool);
        return {'registered': true};
      case 'agent.unregisterTool':
        final agent = ref.read(agentProvider.notifier);
        final toolName = args['toolName'] as String? ?? '';
        agent.unregisterPluginTool(toolName);
        return {'unregistered': true};
      case 'agent.listTasks':
        final agent = ref.read(agentProvider.notifier);
        final tasks = agent.state.tasks
            .map(
              (t) => {
                'id': t.id,
                'name': t.name,
                'status': t.status.name,
                'mode': t.mode.name,
              },
            )
            .toList();
        return {'tasks': tasks};
      default:
        throw UnimplementedError('Unknown API: $apiName');
    }
  }

  Future<void> disablePlugin(String pluginId) async {
    final sandbox = _sandboxes[pluginId];
    if (sandbox != null) {
      await sandbox.stop();
      _sandboxes.remove(pluginId);
    }

    state = state.copyWith(running: {...state.running}..remove(pluginId));
  }

  void registerCommand(PluginCommand command) {
    final commands = Map<String, List<PluginCommand>>.from(state.commands);
    commands.putIfAbsent(command.pluginId, () => []).add(command);
    state = state.copyWith(commands: commands);
  }

  List<PluginCommand> getPluginCommands(String pluginId) {
    return state.commands[pluginId] ?? [];
  }

  List<PluginCommand> getAllCommands() {
    return state.commands.values.expand((c) => c).toList();
  }

  Future<T?> callPluginApi<T>(
    String pluginId,
    String apiName,
    Map<String, dynamic> args, {
    required Permission requiredPermission,
  }) async {
    final sandbox = _sandboxes[pluginId];
    if (sandbox == null) throw StateError('Plugin $pluginId not found');
    return sandbox.callApi<T>(
      apiName,
      args,
      requiredPermission: requiredPermission,
    );
  }

  void registerHookHandler(
    String pluginId,
    void Function(String event, Map<String, dynamic> data) handler,
  ) {
    _hookHandlers[pluginId] = handler;
  }

  void dispatchHook(String event, Map<String, dynamic> data) {
    for (final pluginId in state.running.keys) {
      final handler = _hookHandlers[pluginId];
      if (handler != null) {
        try {
          handler(event, data);
        } catch (e) {
          debugPrint('PluginHost: hook $event for $pluginId failed: $e');
        }
      }
    }
  }
}

final pluginHostProvider = NotifierProvider<PluginHostNotifier, PluginState>(
  PluginHostNotifier.new,
);

class _PluginAgentTool extends AgentTool {
  final Future<ToolResult> Function(Map<String, dynamic> args) _executeFn;

  _PluginAgentTool({
    required super.name,
    required super.description,
    required super.parametersSchema,
    required super.isDestructive,
    required super.source,
    required Future<ToolResult> Function(Map<String, dynamic> args) executeFn,
  }) : _executeFn = executeFn;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) => _executeFn(args);
}

// ignore_for_file: unused_element, unused_element_parameter
part of 'plugin_host.dart';

class PluginHostNotifier extends Notifier<PluginState> {
  final Map<String, Sandbox> _sandboxes = {};
  final Map<String, void Function(String event, Map<String, dynamic> data)>
  _hookHandlers = {};
  String? _vaultPath;

  @override
  PluginState build() {
    ref.onDispose(() {
      for (final sandbox in _sandboxes.values) {
        sandbox.stop();
      }
    });
    return PluginState();
  }

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
      appLog.error('PluginHost: failed to load plugin config', error: e);
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
      appLog.error('PluginHost: failed to save plugin config', error: e);
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
    final entryPointCode = await _readEntryPointCode(manifest);
    final sandbox = Sandbox(
      pluginId: manifest.id,
      manifest: manifest,
      apiHandler: _createApiImpl(manifest).dispatch,
      entryPointCode: entryPointCode,
    );
    await sandbox.start();
    _sandboxes[manifest.id] = sandbox;
    sandbox.onError.listen((error) {
      state = state.copyWith(error: error);
    });
  }

  /// Reads the JS entry-point file content for [manifest] if one is declared.
  /// Returns null when no entry point is set or the file cannot be read.
  Future<String?> _readEntryPointCode(PluginManifest manifest) async {
    final entryPath = manifest.entryPoint;
    if (entryPath == null || entryPath.isEmpty) return null;

    final vaultPath = _vaultPath ?? ref.read(noteRepositoryProvider)?.vaultPath;
    if (vaultPath == null) return null;

    final pluginDir =
        '$vaultPath${Platform.pathSeparator}.rfbrowser${Platform.pathSeparator}plugins${Platform.pathSeparator}${manifest.id}';
    final jsFile = File('$pluginDir${Platform.pathSeparator}$entryPath');
    if (!await jsFile.exists()) {
      appLog.warning('PluginHost: entry point not found: ${jsFile.path}');
      return null;
    }
    try {
      return await jsFile.readAsString();
    } catch (e) {
      appLog.error('PluginHost: failed to read entry point', error: e);
      return null;
    }
  }

  /// Builds the per-plugin typed API surface used as the sandbox's
  /// [ApiHandler]. Each call flows through [CapabilityChecker] (G14-A)
  /// before reaching the host services.
  PluginApiImpl _createApiImpl(PluginManifest manifest) {
    return PluginApiImpl(
      ref: ref,
      pluginId: manifest.id,
      manifest: manifest,
      onToolExecute: (toolName, toolArgs) async {
        final result = await callPluginApi<Map<String, dynamic>>(
          manifest.id,
          'agent.toolExecute',
          {'toolName': toolName, 'args': toolArgs},
          requiredPermission: Permission.aiChat,
        );
        return result ?? {};
      },
    );
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
    final entryPointCode = await _readEntryPointCode(manifest);
    final sandbox = Sandbox(
      pluginId: manifest.id,
      manifest: manifest,
      apiHandler: _createApiImpl(manifest).dispatch,
      entryPointCode: entryPointCode,
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
          appLog.error(
            'PluginHost: hook $event for $pluginId failed',
            error: e,
          );
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

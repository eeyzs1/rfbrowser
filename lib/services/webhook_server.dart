import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logging/app_logger.dart';
import '../data/models/agent_task.dart';
import '../services/agent_service.dart';
import '../services/ai_service.dart';
import '../services/browser_service.dart';
import '../services/knowledge_service.dart';
import '../data/stores/index_store.dart';

class WebhookServer {
  HttpServer? _server;
  final Ref _ref;
  String _apiKey;
  int port;
  bool _isRunning = false;

  WebhookServer({required Ref ref, String? apiKey, this.port = 18765})
    : _ref = ref,
      _apiKey = apiKey ?? _generateApiKey();

  bool get isRunning => _isRunning;
  String get apiKey => _apiKey;
  String get baseUrl => 'http://localhost:$port';

  static String _generateApiKey() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return 'rfb_${random.toRadixString(36)}';
  }

  void setApiKey(String key) {
    _apiKey = key;
  }

  Future<void> start() async {
    if (_isRunning) return;

    final app = Router();

    app.get('/api/status', _handleStatus);
    app.get('/api/tools', _handleListTools);
    app.get('/api/notes', _handleSearchNotes);
    app.post('/api/notes', _handleCreateNote);
    app.get('/api/browser/url', _handleGetBrowserUrl);
    app.post('/api/browser/navigate', _handleBrowserNavigate);
    app.post('/api/ai/chat', _handleAiChat);
    app.get('/api/agent/tasks', _handleListTasks);
    app.post('/api/agent/execute', _handleAgentExecute);
    app.post('/api/agent/plan', _handleAgentPlan);

    final handler = const Pipeline()
        .addMiddleware(
          logRequests(
            logger: (msg, isError) {
              if (isError) {
                appLog.error('WebhookServer: $msg');
              }
            },
          ),
        )
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addHandler(app.call);

    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        port,
      );
      // When port is 0, the OS assigns a free port; reflect the actual
      // port so callers (and tests) can connect.
      port = _server!.port;
      _isRunning = true;
      appLog.debug('WebhookServer running on $baseUrl (API key: $_apiKey)');
    } catch (e) {
      appLog.error('WebhookServer failed to start', error: e);
      _isRunning = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    appLog.debug('WebhookServer stopped');
  }

  Middleware _authMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || authHeader != 'Bearer $_apiKey') {
          return Response.forbidden(jsonEncode({'error': 'Unauthorized'}));
        }
        return innerHandler(request);
      };
    };
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders());
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  Map<String, String> _corsHeaders() => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };

  Response _jsonResponse(dynamic data, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _handleStatus(Request request) {
    return _jsonResponse({
      'status': 'ok',
      'version': '0.3.0',
      'tools': _ref.read(agentProvider.notifier).toolRegistry.tools.length,
    });
  }

  Future<Response> _handleListTools(Request request) async {
    final tools = _ref
        .read(agentProvider.notifier)
        .toolRegistry
        .allToolDefinitions();
    return _jsonResponse({'tools': tools});
  }

  Future<Response> _handleSearchNotes(Request request) async {
    final query = request.url.queryParameters['q'] ?? '';
    if (query.isEmpty) {
      return _jsonResponse({'notes': []});
    }
    final indexStore = _ref.read(indexStoreProvider);
    final results = await indexStore.searchNotes(query);
    return _jsonResponse({'notes': results});
  }

  Future<Response> _handleCreateNote(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final title = body['title'] as String? ?? 'Untitled';
      final content = body['content'] as String? ?? '';

      final note = await _ref
          .read(knowledgeProvider.notifier)
          .createNote(title: title);
      _ref.read(knowledgeProvider.notifier).updateActiveNoteContent(content);
      await _ref.read(knowledgeProvider.notifier).saveActiveNote();

      return _jsonResponse({
        'success': true,
        'note': {'id': note.id, 'title': note.title, 'filePath': note.filePath},
      });
    } catch (e) {
      return _jsonResponse({
        'success': false,
        'error': e.toString(),
      }, status: 500);
    }
  }

  Response _handleGetBrowserUrl(Request request) {
    final browserState = _ref.read(browserProvider);
    final activeTab = browserState.activeTab;
    return _jsonResponse({'url': activeTab?.url ?? ''});
  }

  Future<Response> _handleBrowserNavigate(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final url = body['url'] as String?;
      if (url == null) {
        return _jsonResponse({'error': 'url is required'}, status: 400);
      }
      _ref.read(browserProvider.notifier).createTab(url: url);
      return _jsonResponse({'success': true, 'url': url});
    } catch (e) {
      return _jsonResponse({
        'success': false,
        'error': e.toString(),
      }, status: 500);
    }
  }

  Future<Response> _handleAiChat(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final message = body['message'] as String?;
      if (message == null) {
        return _jsonResponse({'error': 'message is required'}, status: 400);
      }
      final systemPrompt = body['system_prompt'] as String?;
      await _ref
          .read(aiProvider.notifier)
          .sendMessage(message, systemPrompt: systemPrompt);
      final messages = _ref.read(aiProvider).messages;
      final lastAssistant = messages.lastWhere(
        (m) => m.role == 'assistant' && !m.isStreaming,
        orElse: () => ChatMessage(role: 'assistant', content: ''),
      );
      return _jsonResponse({'response': lastAssistant.content});
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 500);
    }
  }

  Response _handleListTasks(Request request) {
    final tasks = _ref
        .read(agentProvider)
        .tasks
        .map(
          (t) => {
            'id': t.id,
            'name': t.name,
            'status': t.status.name,
            'mode': t.mode.name,
            'steps': t.steps.length,
            'created': t.created.toIso8601String(),
          },
        )
        .toList();
    return _jsonResponse({'tasks': tasks});
  }

  Future<Response> _handleAgentExecute(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final name = body['name'] as String? ?? 'API Task';
      final description = body['description'] as String? ?? '';
      final modeStr = body['mode'] as String? ?? 'manual';
      final mode = TaskMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => TaskMode.manual,
      );
      final steps =
          (body['steps'] as List?)?.map((s) {
            if (s is Map<String, dynamic>) {
              return AgentStep(
                description: s['description'] as String? ?? '',
                toolName: s['tool'] as String?,
                args: (s['args'] as Map<String, dynamic>?) ?? {},
              );
            }
            return AgentStep(description: s.toString());
          }).toList() ??
          [];

      final task = AgentTask(
        id: 'api_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: description,
        mode: mode,
        steps: steps,
      );

      final agent = _ref.read(agentProvider.notifier);
      final result = await agent.executeTask(task);

      return _jsonResponse({
        'taskId': result.id,
        'status': result.status.name,
        'result': result.result,
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 500);
    }
  }

  Future<Response> _handleAgentPlan(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final goal = body['goal'] as String?;
      if (goal == null) {
        return _jsonResponse({'error': 'goal is required'}, status: 400);
      }
      final modeStr = body['mode'] as String? ?? 'aiPlanned';
      final mode = TaskMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => TaskMode.aiPlanned,
      );

      final agent = _ref.read(agentProvider.notifier);
      final result = await agent.aiPlanAndExecute(goal, mode: mode);

      return _jsonResponse({
        'taskId': result.id,
        'status': result.status.name,
        'result': result.result,
        'steps': result.steps
            .map(
              (s) => {
                'description': s.description,
                'toolName': s.toolName,
                'status': s.status.name,
                'result': s.result,
              },
            )
            .toList(),
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 500);
    }
  }
}

class WebhookServerNotifier extends Notifier<WebhookServerState> {
  @override
  WebhookServerState build() {
    ref.onDispose(() {
      // Stop the HTTP server if still running when the provider is disposed.
      state.server?.stop();
    });
    return WebhookServerState();
  }

  Future<void> start({int? port}) async {
    if (state.isRunning) return;

    final server = WebhookServer(ref: ref, port: port ?? state.port);
    await server.start();
    state = WebhookServerState(
      isRunning: server.isRunning,
      port: server.port,
      apiKey: server.apiKey,
      baseUrl: server.baseUrl,
      server: server,
    );
  }

  Future<void> stop() async {
    await state.server?.stop();
    state = WebhookServerState(port: state.port);
  }

  void setPort(int port) {
    state = state.copyWith(port: port);
  }
}

class WebhookServerState {
  final bool isRunning;
  final int port;
  final String? apiKey;
  final String? baseUrl;
  final WebhookServer? server;

  const WebhookServerState({
    this.isRunning = false,
    this.port = 18765,
    this.apiKey,
    this.baseUrl,
    this.server,
  });

  WebhookServerState copyWith({
    bool? isRunning,
    int? port,
    String? apiKey,
    String? baseUrl,
    WebhookServer? server,
  }) {
    return WebhookServerState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      server: server ?? this.server,
    );
  }
}

final webhookServerProvider =
    NotifierProvider<WebhookServerNotifier, WebhookServerState>(
      WebhookServerNotifier.new,
    );

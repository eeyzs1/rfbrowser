import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ai_provider.dart';
import '../data/models/chat_memory.dart';
import 'dio_factory.dart';
import 'connectivity_service.dart';
import 'settings_service.dart';
import 'agent_chat_bridge.dart';
import 'memory_service.dart';
import 'dreaming_service.dart';
import 'hebbian_service.dart';
import '../core/ai/request_context.dart';

class ToolCallInfo {
  final String id;
  final String name;
  final Map<String, dynamic> args;

  ToolCallInfo({required this.id, required this.name, required this.args});
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final List<ToolCallInfo> toolCalls;
  final String? toolCallDisplay;
  final String? toolResultDisplay;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.toolCalls = const [],
    this.toolCallDisplay,
    this.toolResultDisplay,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    List<ToolCallInfo>? toolCalls,
    String? toolCallDisplay,
    String? toolResultDisplay,
    bool clearToolCallDisplay = false,
    bool clearToolResultDisplay = false,
  }) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      toolCalls: toolCalls ?? this.toolCalls,
      toolCallDisplay: clearToolCallDisplay
          ? null
          : (toolCallDisplay ?? this.toolCallDisplay),
      toolResultDisplay: clearToolResultDisplay
          ? null
          : (toolResultDisplay ?? this.toolResultDisplay),
    );
  }
}

class AIState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final AIProvider? activeProvider;
  final AIModel? activeModel;

  AIState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.activeProvider,
    this.activeModel,
  });

  AIState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    AIProvider? activeProvider,
    AIModel? activeModel,
    bool clearError = false,
    bool clearProvider = false,
    bool clearModel = false,
  }) {
    return AIState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeProvider: clearProvider
          ? null
          : (activeProvider ?? this.activeProvider),
      activeModel: clearModel ? null : (activeModel ?? this.activeModel),
    );
  }
}

class AINotifier extends Notifier<AIState> {
  static final _dio = DioFactory.instance;

  MemoryService get _memory => ref.read(memoryServiceProvider);
  DreamingService get _dreaming => ref.read(dreamingServiceProvider);

  @override
  AIState build() {
    final aiConfig = ref.read(aiConfigProvider);
    final config = aiConfig.activeConfig;
    if (config != null) {
      final provider = aiConfig.activeProvider;
      final model = aiConfig.activeModel;
      if (provider != null && model != null) {
        _configureDreaming(provider, model);
        return AIState(activeProvider: provider, activeModel: model);
      }
    }
    return AIState();
  }

  void _configureDreaming(AIProvider provider, AIModel model) {
    _dreaming.configureAI(provider: provider, model: model);
  }

  void setActiveModel(AIProvider provider, AIModel model) {
    ref
        .read(aiConfigProvider.notifier)
        .setActiveConfig(
          ActiveAIConfig(providerId: provider.id, modelId: model.id),
        );
    state = state.copyWith(activeProvider: provider, activeModel: model);
  }

  Future<void> sendMessage(
    String userMessage, {
    String? systemPrompt,
    String? context,
    List<Map<String, dynamic>>? tools,
    AgentChatBridge? bridge,
  }) async {
    if (state.isLoading) return;

    var provider =
        state.activeProvider ?? ref.read(aiConfigProvider).activeProvider;
    var model = state.activeModel ?? ref.read(aiConfigProvider).activeModel;

    // ── Ambient request context: vault / active note / selection / scene
    //    are layered onto whatever caller-supplied context exists, so
    //    AI services always know "what is the user doing right now".
    //    Honored only when the user has not disabled it in settings.
    final injectContext = ref.read(settingsProvider).memoryInjectContext;
    final ambient = injectContext ? ref.read(requestContextProvider) : null;
    final ambientBlock = ambient?.toSystemPromptBlock() ?? '';
    // ─────────────────────────────────────────────────────────────

    // ── Memory: query relevant fragments ────────────────────────
    final memoryContext = await _buildMemoryContext(userMessage);
    final effectiveContext = _mergeContext(
      _mergeContext(context, ambientBlock.isEmpty ? null : ambientBlock),
      memoryContext,
    );
    // ─────────────────────────────────────────────────────────────

    final connectivity = ref.read(connectivityProvider);
    if (!connectivity.isOnline) {
      if (provider != null && !provider.isLocal) {
        final offlineProvider = ref
            .read(connectivityProvider.notifier)
            .getOfflineProvider();
        final offlineModel = ref
            .read(connectivityProvider.notifier)
            .getOfflineModel(offlineProvider);
        if (offlineProvider != null && offlineModel != null) {
          provider = offlineProvider;
          model = offlineModel;
        } else {
          state = state.copyWith(error: OfflineNoModelError().toString());
          return;
        }
      }
    }

    if (provider == null || model == null) {
      state = state.copyWith(
        error: 'No AI provider configured. Please set one up in Settings.',
      );
      return;
    }

    if (provider.requiresApiKey) {
      final apiKey = await ref
          .read(aiConfigProvider.notifier)
          .getApiKeyForProvider(provider.id);
      if (apiKey == null || apiKey.isEmpty) {
        state = state.copyWith(
          error:
              'API key not set for "${provider.name}". Please configure it in Settings.',
        );
        return;
      }
    }

    final userMsg = ChatMessage(role: 'user', content: userMessage);
    final streamingMsg = ChatMessage(
      role: 'assistant',
      content: '',
      isStreaming: true,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg, streamingMsg],
      isLoading: true,
      clearError: true,
    );

    // ── Memory: persist user message (fire-and-forget) ──────────
    _persistMessage('user', userMessage);
    // ─────────────────────────────────────────────────────────────

    try {
      final messages = _buildMessages(systemPrompt, effectiveContext);
      final apiKey = provider.requiresApiKey
          ? await ref
                .read(aiConfigProvider.notifier)
                .getApiKeyForProvider(provider.id)
          : null;

      final hasTools = tools != null && tools.isNotEmpty && bridge != null;

      final response = await _sendRequest(
        provider: provider,
        model: model,
        messages: messages,
        apiKey: apiKey,
        stream: true,
        tools: tools,
      );

      if (hasTools) {
        await _handleToolCallLoop(
          response,
          provider,
          model,
          apiKey,
          bridge,
          tools,
          messages,
        );
      } else {
        final buffer = StringBuffer();
        final stream = response.data.stream;
        await for (final chunk in stream) {
          final text = utf8.decode(chunk);
          final lines = text.split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();
              if (data == '[DONE]') break;
              try {
                final json = jsonDecode(data);
                final delta = _extractStreamDelta(json, provider.protocol);
                if (delta != null) {
                  buffer.write(delta);
                  _updateLastAssistantMessage(
                    buffer.toString(),
                    isStreaming: true,
                  );
                }
              } catch (e) {
                debugPrint('Stream chunk parse error: $e');
              }
            }
          }
        }
        _updateLastAssistantMessage(buffer.toString(), isStreaming: false);
        // ── Memory: persist assistant response ──────────────────
        _persistMessage('assistant', buffer.toString());
        // ─────────────────────────────────────────────────────────
      }
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e, provider.protocol);
      _removeLastAssistantMessage();
      state = state.copyWith(isLoading: false, error: errorMsg);
    } catch (e) {
      _removeLastAssistantMessage();
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _updateLastAssistantMessage(
    String content, {
    required bool isStreaming,
  }) {
    final messages = List<ChatMessage>.from(state.messages);
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'assistant') {
        messages[i] = messages[i].copyWith(
          content: content,
          isStreaming: isStreaming,
        );
        break;
      }
    }
    state = state.copyWith(messages: messages, isLoading: isStreaming);
  }

  void _removeLastAssistantMessage() {
    final messages = List<ChatMessage>.from(state.messages);
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'assistant') {
        messages.removeAt(i);
        break;
      }
    }
    state = state.copyWith(messages: messages);
  }

  /// Process a streaming response that may contain tool calls.
  /// When tool calls are detected, execute them and loop until
  /// the AI returns a text-only response.
  Future<void> _handleToolCallLoop(
    Response<dynamic> firstResponse,
    AIProvider provider,
    AIModel model,
    String? apiKey,
    AgentChatBridge bridge,
    List<Map<String, dynamic>> tools,
    List<Map<String, dynamic>> apiMessages,
  ) async {
    const maxLoops = 10;
    var currentMessages = List<Map<String, dynamic>>.from(apiMessages);
    var loopCount = 0;

    while (loopCount < maxLoops) {
      final toolCallsByIndex = <int, _AccToolCall>{};
      final textBuffer = StringBuffer();

      // Read the stream
      final stream = (loopCount == 0)
          ? firstResponse.data.stream
          : (await _sendRequest(
              provider: provider,
              model: model,
              messages: currentMessages,
              apiKey: apiKey,
              stream: true,
              tools: tools,
            )).data.stream;

      await for (final chunk in stream) {
        final text = utf8.decode(chunk);
        final lines = text.split('\n');
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            _accumulateStreamChunk(
              json,
              provider.protocol,
              toolCallsByIndex,
              textBuffer,
            );
          } catch (e) {
            debugPrint('Tool loop chunk parse error: $e');
          }
        }
      }

      // Update UI with accumulated text
      final accumulatedText = textBuffer.toString();
      if (accumulatedText.isNotEmpty) {
        _updateLastAssistantMessage(accumulatedText, isStreaming: true);
      }

      // Check if we have tool calls to execute
      if (toolCallsByIndex.isEmpty) {
        _updateLastAssistantMessage(accumulatedText, isStreaming: false);
        // ── Memory: persist final assistant response ────────────
        if (accumulatedText.isNotEmpty) {
          _persistMessage('assistant', accumulatedText);
        }
        // ─────────────────────────────────────────────────────────
        return;
      }

      // Execute tool calls
      final sortedCalls = toolCallsByIndex.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final toolCalls = sortedCalls.map((e) => e.value).toList();

      // Build assistant message with tool_calls for the API
      final assistantToolCalls = toolCalls.map((tc) {
        return {
          'id': tc.id,
          'type': 'function',
          'function': {'name': tc.name, 'arguments': tc.argsJson},
        };
      }).toList();

      currentMessages.add({
        'role': 'assistant',
        'content': accumulatedText.isNotEmpty ? accumulatedText : null,
        'tool_calls': assistantToolCalls,
      });

      // Display tool calls in UI
      for (final tc in toolCalls) {
        final args = _parseArgs(tc.argsJson);
        final display = bridge.formatToolCallForDisplay(tc.name, args);

        // Add a display-only message for the tool call
        final callMsg = ChatMessage(
          role: 'tool_call',
          content: '',
          toolCallDisplay: display,
        );
        state = state.copyWith(messages: [...state.messages, callMsg]);

        // Execute the tool
        final result = await bridge.executeTool(tc.name, args);
        final resultDisplay = bridge.formatToolResultForDisplay(
          tc.name,
          result,
        );

        // Add tool result to API messages
        currentMessages.add({
          'role': 'tool',
          'tool_call_id': tc.id,
          'content': jsonEncode(result),
        });

        // Display tool result in UI
        final resultMsg = ChatMessage(
          role: 'tool_result',
          content: '',
          toolResultDisplay: resultDisplay,
        );
        state = state.copyWith(messages: [...state.messages, resultMsg]);
      }

      _removeLastAssistantMessage();
      state = state.copyWith(isLoading: true);
      loopCount++;
    }

    // Max loops exceeded
    _updateLastAssistantMessage(
      'Agent tool loop limit reached. Please simplify your request.',
      isStreaming: false,
    );
  }

  /// Accumulate streaming chunks, separating text content and tool calls.
  void _accumulateStreamChunk(
    Map<String, dynamic> json,
    ApiProtocol protocol,
    Map<int, _AccToolCall> toolCallsByIndex,
    StringBuffer textBuffer,
  ) {
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return;

    for (final choice in choices) {
      final delta = choice['delta'] as Map<String, dynamic>?;
      if (delta == null) continue;

      // Text content
      final content = delta['content'] as String?;
      if (content != null) {
        textBuffer.write(content);
        // Update UI with both text and tool calls
        _updateLastAssistantMessage(textBuffer.toString(), isStreaming: true);
      }

      // Tool calls (OpenAI format)
      final tcItems = delta['tool_calls'] as List<dynamic>?;
      if (tcItems == null) continue;

      for (final tc in tcItems) {
        final tcMap = tc as Map<String, dynamic>;
        final index = tcMap['index'] as int? ?? 0;
        final acc = toolCallsByIndex.putIfAbsent(index, () => _AccToolCall());
        if (tcMap.containsKey('id') && tcMap['id'] != null) {
          acc.id = tcMap['id'] as String;
        }
        final func = tcMap['function'] as Map<String, dynamic>?;
        if (func != null) {
          if (func.containsKey('name') && func['name'] != null) {
            acc.name = func['name'] as String;
          }
          final argsDelta = func['arguments'] as String?;
          if (argsDelta != null) {
            acc.argsBuffer.write(argsDelta);
          }
        }
      }
    }
  }

  Map<String, dynamic> _parseArgs(String argsJson) {
    try {
      return jsonDecode(argsJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
    _memory.newSession();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ─── Memory helpers ────────────────────────────────────────────────

  /// Query relevant memory fragments and format them for the system prompt.
  ///
  /// Pipeline:
  ///   1. FTS5 search → top-k fragments
  ///   2. Hebbian expansion → related fragments that didn't match the query
  ///   3. Record the union as a co-access group (so the next call sees
  ///      stronger edges between them)
  ///   4. Fall back to summary search when fragment results are sparse
  Future<String?> _buildMemoryContext(String userMessage) async {
    try {
      final fragments = await _memory.searchFragments(userMessage, limit: 5);
      final hebbian = ref.read(hebbianServiceProvider);
      final neighbors = fragments.isEmpty
          ? const <HebbianNeighbor>[]
          : await hebbian.expandByHebbianLinks(
              fragments.map((f) => f.id),
              limit: 3,
            );

      // Record co-access for the union of primary + neighbors. Failures are
      // logged but never block the response.
      final coAccessIds = <String>[
        ...fragments.map((f) => f.id),
        ...neighbors.map((n) => n.fragment.id),
      ];
      if (coAccessIds.length > 1) {
        unawaited(
          hebbian.recordCoAccess(coAccessIds).catchError((Object e) {
            debugPrint('AI: hebbian recordCoAccess error: $e');
          }),
        );
      }

      final allFragments = <MemoryFragment>[
        ...fragments,
        ...neighbors.map((n) => n.fragment),
      ];

      String? ctx = allFragments.isEmpty
          ? null
          : MemoryService.formatFragmentsForContext(allFragments);

      // Fallback: if no fragments matched, look at summaries.
      if (allFragments.isEmpty) {
        final summaries = await _memory.searchSummaries(userMessage, limit: 3);
        if (summaries.isNotEmpty) {
          ctx = _formatSummariesForContext(summaries);
        }
      }
      return ctx;
    } catch (e) {
      debugPrint('AI: memory context query failed: $e');
      return null;
    }
  }

  static String _formatSummariesForContext(List<MemorySummary> summaries) {
    final buffer = StringBuffer();
    buffer.writeln('[Past conversation summaries — distilled knowledge:]');
    for (final s in summaries) {
      buffer.writeln('- [${s.summaryTier.name.toUpperCase()}] ${s.summaryText}');
    }
    return buffer.toString();
  }

  /// Merge caller-provided context with memory context.
  String? _mergeContext(String? callerContext, String? memoryContext) {
    if (callerContext == null && memoryContext == null) return null;
    if (callerContext == null) return memoryContext;
    if (memoryContext == null) return callerContext;
    return '$memoryContext\n\n$callerContext';
  }

  /// Persist a message and notify the dreaming service.
  void _persistMessage(String role, String content) {
    _memory.saveMessage(role: role, content: content);
    _dreaming.onMessageSaved();
  }

  // ─── Message building ──────────────────────────────────────────────

  List<Map<String, dynamic>> _buildMessages(
    String? systemPrompt,
    String? context,
  ) {
    final messages = <Map<String, dynamic>>[];
    final systemContent = <String>[];
    if (systemPrompt != null) systemContent.add(systemPrompt);
    if (context != null) systemContent.add('Context:\n$context');

    if (systemContent.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemContent.join('\n\n')});
    }

    for (final msg in state.messages) {
      if (msg.isStreaming) continue;
      messages.add({'role': msg.role, 'content': msg.content});
    }
    return messages;
  }

  Future<Response<dynamic>> _sendRequest({
    required AIProvider provider,
    required AIModel model,
    required List<Map<String, dynamic>> messages,
    String? apiKey,
    required bool stream,
    List<Map<String, dynamic>>? tools,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...provider.authHeaders(),
    };

    switch (provider.protocol) {
      case ApiProtocol.openaiCompatible:
        final body = <String, dynamic>{
          'model': model.id,
          'messages': messages,
          'stream': stream,
        };
        if (tools != null && tools.isNotEmpty) {
          body['tools'] = tools;
        }
        return _dio.post(
          provider.chatEndpoint,
          options: Options(
            headers: headers,
            responseType: stream ? ResponseType.stream : ResponseType.json,
          ),
          data: jsonEncode(body),
        );

      case ApiProtocol.anthropic:
        final systemMsg = messages
            .where((m) => m['role'] == 'system')
            .map((m) => m['content'] as String)
            .firstOrNull;
        final chatMsgs = messages.where((m) => m['role'] != 'system').toList();

        return _dio.post(
          provider.chatEndpoint,
          options: Options(
            headers: headers,
            responseType: stream ? ResponseType.stream : ResponseType.json,
          ),
          data: jsonEncode({
            'model': model.id,
            'max_tokens': 4096,
            'system': systemMsg,
            'messages': chatMsgs,
            'stream': stream,
          }),
        );
    }
  }

  String? _extractStreamDelta(dynamic json, ApiProtocol protocol) {
    switch (protocol) {
      case ApiProtocol.openaiCompatible:
        return json['choices']?[0]?['delta']?['content'] as String?;
      case ApiProtocol.anthropic:
        final type = json['type'] as String?;
        if (type == 'content_block_delta') {
          return json['delta']?['text'] as String?;
        }
        return null;
    }
  }

  String _extractErrorMessage(DioException e, ApiProtocol protocol) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        switch (protocol) {
          case ApiProtocol.openaiCompatible:
            return data['error']?['message'] as String? ??
                e.message ??
                'Unknown error';
          case ApiProtocol.anthropic:
            return data['error']?['message'] as String? ??
                e.message ??
                'Unknown error';
        }
      }
    } catch (_) {
      debugPrint('AI: failed to extract error message from response');
    }
    return e.message ?? 'Unknown error';
  }
}

class _AccToolCall {
  String id = '';
  String name = '';
  final StringBuffer argsBuffer = StringBuffer();

  String get argsJson => argsBuffer.toString();
}

final aiProvider = NotifierProvider<AINotifier, AIState>(AINotifier.new);

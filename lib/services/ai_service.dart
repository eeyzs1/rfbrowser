import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/logging/app_logger.dart';
import '../core/ai/request_context.dart';
import '../data/models/ai_provider.dart';
import 'ai/ai_models.dart';
import 'ai/ai_protocol_strategy.dart';
import 'ai/ai_stream_accumulator.dart';
import 'ai/memory_context_builder.dart';
import 'active_memory_buffer.dart';
import 'agent_chat_bridge.dart';
import 'connectivity_service.dart';
import 'dio_factory.dart';
import 'dreaming_service.dart';
import 'hebbian_service.dart';
import 'memory_service.dart';
import 'settings_service.dart';

// Re-export models for backward compatibility — historical callers
// import them from ai_service.dart.
export 'ai/ai_models.dart';

part 'ai_service_tool_loop.dart';

class AINotifier extends Notifier<AIState> with _ToolCallLoopMixin {
  static final _dio = DioFactory.instance;
  late final AiProtocolStrategy _protocol = AiProtocolStrategy(_dio);

  /// 会话持久化的 SharedPreferences 键名
  static const _sessionsStorageKey = 'ai_chat_sessions_v1';

  MemoryService get _memory => ref.read(memoryServiceProvider);
  DreamingService get _dreaming => ref.read(dreamingServiceProvider);

  // ── Bridges for _ToolCallLoopMixin ──────────────────────────────
  @override
  AiProtocolStrategy get protocolStrategy => _protocol;

  @override
  void updateLastAssistantMessage(
    String content, {
    required bool isStreaming,
    bool attachMemoryFootprint = false,
  }) => _updateLastAssistantMessage(
    content,
    isStreaming: isStreaming,
    attachMemoryFootprint: attachMemoryFootprint,
  );

  @override
  void removeLastAssistantMessage() => _removeLastAssistantMessage();

  @override
  void persistMessage(String role, String content) =>
      _persistMessage(role, content);
  // ────────────────────────────────────────────────────────────────

  @override
  AIState build() {
    final aiConfig = ref.read(aiConfigProvider);
    final config = aiConfig.activeConfig;
    AIState initialState;
    if (config != null) {
      final provider = aiConfig.activeProvider;
      final model = aiConfig.activeModel;
      if (provider != null && model != null) {
        _configureDreaming(provider, model);
        initialState = AIState(activeProvider: provider, activeModel: model);
      } else {
        initialState = AIState();
      }
    } else {
      initialState = AIState();
    }

    // 异步加载持久化的会话
    _loadSessions();
    return initialState;
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
    String? sessionId,
  }) async {
    if (state.isLoading) return;

    var provider =
        state.activeProvider ?? ref.read(aiConfigProvider).activeProvider;
    var model = state.activeModel ?? ref.read(aiConfigProvider).activeModel;

    // ── Ambient request context: vault / active note / selection / scene
    //    are layered onto whatever caller-supplied context exists, so
    //    AI services always know "what is the user doing right now".
    //    Honored only when the user has not disabled it in settings.
    final injectContext = ref.read(settingsProvider).memory.injectContext;
    final ambient = injectContext ? ref.read(requestContextProvider) : null;
    final ambientBlock = ambient?.toSystemPromptBlock() ?? '';
    // ─────────────────────────────────────────────────────────────

    // ── Memory: query relevant fragments + inject active working memory
    final memoryBundle = await _buildMemoryContextBundle(
      userMessage,
      sessionId: sessionId,
    );
    final effectiveContext = _mergeContext(
      _mergeContext(context, ambientBlock.isEmpty ? null : ambientBlock),
      memoryBundle.context,
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

    final userMsg = ChatMessage(
      role: 'user',
      content: userMessage,
      id: const Uuid().v4(),
    );
    final streamingMsg = ChatMessage(
      role: 'assistant',
      content: '',
      isStreaming: true,
      id: const Uuid().v4(),
    );
    final newMessages = [...state.messages, userMsg, streamingMsg];
    state = state.copyWith(
      messages: newMessages,
      sessions: _syncedSessions(newMessages),
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

      final hasToolsRequested =
          tools != null && tools.isNotEmpty && bridge != null;

      // ── Pre-send capability validation ───────────────────────────
      //    若调用方请求了 tools,但当前 model 不支持 function calling,
      //    降级为普通对话(不发 tools 数组,避免 provider API 报错),
      //    并在 UI 上提示用户。日志记录便于排查"agent 模式不触发工具"类问题。
      final hasTools = hasToolsRequested && model.supportsTools;
      if (hasToolsRequested && !hasTools) {
        appLog.warning(
          'AI: model "${model.id}" does not declare tools capability; '
          'falling back to plain chat (tools dropped). '
          'If the model actually supports function calling, '
          'edit it in Settings → AI → Custom Models to add the Tools capability.',
        );
        // 在 streaming 消息上挂一条用户可见提示,避免"静默降级"的困惑。
        _updateLastAssistantMessage(
          '(当前模型 "${model.displayName}" 未声明 Tools 能力,已降级为普通对话。'
          '如需使用 Agent 工具调用,请在 设置 → AI → 自定义模型 中勾选 Tools。)\n\n',
          isStreaming: true,
        );
      }

      // ── Sampling parameters: read from settings (chat scene).
      //    When the caller passes tools (agent tool-call loop), use the
      //    agent scene's parameters instead for more deterministic output.
      final sampling = ref.read(settingsProvider).sampling;
      final isAgentCall = hasTools;
      final temperature = isAgentCall
          ? sampling.agentTemperature
          : sampling.chatTemperature;
      final maxTokens = isAgentCall
          ? sampling.agentMaxTokens
          : sampling.chatMaxTokens;

      final response = await _protocol.sendRequest(
        provider: provider,
        model: model,
        messages: messages,
        apiKey: apiKey,
        stream: true,
        tools: hasTools ? tools : null,
        temperature: temperature,
        maxTokens: maxTokens,
      );

      if (hasTools) {
        await handleToolCallLoop(
          response,
          provider,
          model,
          apiKey,
          bridge,
          tools,
          messages,
          temperature: temperature,
          maxTokens: maxTokens,
          maxLoops: sampling.maxToolLoops,
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
                final delta = _protocol.extractStreamDelta(
                  json,
                  provider.protocol,
                );
                if (delta != null) {
                  buffer.write(delta);
                  _updateLastAssistantMessage(
                    buffer.toString(),
                    isStreaming: true,
                  );
                }
              } catch (e) {
                appLog.warning('Stream chunk parse error', error: e);
              }
            }
          }
        }
        _updateLastAssistantMessage(
          buffer.toString(),
          isStreaming: false,
          attachMemoryFootprint: true,
        );
        // ── Memory: persist assistant response ──────────────────
        _persistMessage('assistant', buffer.toString());
        // ─────────────────────────────────────────────────────────
        // 持久化会话到本地存储
        _persistSessions();
      }
    } on DioException catch (e) {
      final errorMsg = _protocol.extractErrorMessage(e, provider.protocol);
      _removeLastAssistantMessage();
      state = state.copyWith(isLoading: false, error: errorMsg);
      _persistSessions();
    } catch (e) {
      _removeLastAssistantMessage();
      state = state.copyWith(isLoading: false, error: e.toString());
      _persistSessions();
    }
  }

  void _updateLastAssistantMessage(
    String content, {
    required bool isStreaming,
    bool attachMemoryFootprint = false,
  }) {
    final messages = List<ChatMessage>.from(state.messages);
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'assistant') {
        messages[i] = messages[i].copyWith(
          content: content,
          isStreaming: isStreaming,
          // Only stamp the memory footprint on the terminal update so we
          // don't flash a "using N memories" badge while the message is
          // still streaming.
          usedMemoryFragmentIds: attachMemoryFootprint
              ? _bundle.fragmentIds
              : messages[i].usedMemoryFragmentIds,
          usedMemorySummaryIds: attachMemoryFootprint
              ? _bundle.summaryIds
              : messages[i].usedMemorySummaryIds,
          memoryContextTokens: attachMemoryFootprint
              ? _bundle.tokensUsed
              : messages[i].memoryContextTokens,
        );
        break;
      }
    }
    state = state.copyWith(
      messages: messages,
      sessions: _syncedSessions(messages),
      isLoading: isStreaming,
    );
  }

  void _removeLastAssistantMessage() {
    final messages = List<ChatMessage>.from(state.messages);
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'assistant') {
        messages.removeAt(i);
        break;
      }
    }
    state = state.copyWith(
      messages: messages,
      sessions: _syncedSessions(messages),
    );
  }

  void clearMessages() {
    // 清空当前会话的消息，并同步到 sessions
    final sessions = List<ChatSession>.from(state.sessions);
    final currentId = state.currentSessionId;
    if (currentId != null) {
      final idx = sessions.indexWhere((s) => s.id == currentId);
      if (idx >= 0) {
        sessions[idx] = sessions[idx].copyWith(messages: const []);
      }
    }
    state = state.copyWith(messages: [], sessions: sessions);
    _memory.newSession();
    _persistSessions();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ─── 多会话管理 ───────────────────────────────────────────────────

  /// 创建新会话并切换到该会话
  void createSession() {
    // 先持久化当前状态
    _persistSessions();

    final session = ChatSession(
      id: const Uuid().v4(),
      title: '',
      messages: const [],
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      sessions: [...state.sessions, session],
      currentSessionId: session.id,
      messages: const [],
      clearError: true,
    );
    _persistSessions();
  }

  /// 切换到指定会话
  void switchSession(String sessionId) {
    final session = state.sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) return;
    // 先同步当前消息到当前会话
    final syncedSessions = _syncedSessions(state.messages);
    state = state.copyWith(
      sessions: syncedSessions,
      currentSessionId: sessionId,
      messages: session.messages,
      clearError: true,
    );
    _persistSessions();
  }

  /// 重命名指定会话
  void renameSession(String sessionId, String title) {
    final sessions = List<ChatSession>.from(state.sessions);
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    sessions[idx] = sessions[idx].copyWith(title: title);
    state = state.copyWith(sessions: sessions);
    _persistSessions();
  }

  /// 删除指定会话
  void deleteSession(String sessionId) {
    final sessions = state.sessions.where((s) => s.id != sessionId).toList();
    if (sessions.isEmpty) {
      // 删除最后一个会话时，创建一个新的默认会话
      final newSession = ChatSession(
        id: const Uuid().v4(),
        title: '',
        messages: const [],
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        sessions: [newSession],
        currentSessionId: newSession.id,
        messages: const [],
        clearError: true,
      );
    } else {
      final wasCurrent = state.currentSessionId == sessionId;
      if (wasCurrent) {
        final newCurrent = sessions.first;
        state = state.copyWith(
          sessions: sessions,
          currentSessionId: newCurrent.id,
          messages: newCurrent.messages,
          clearError: true,
        );
      } else {
        state = state.copyWith(sessions: sessions);
      }
    }
    _persistSessions();
  }

  // ─── 会话持久化辅助方法 ───────────────────────────────────────────

  /// 从第一条用户消息生成会话标题（截取前 30 个字符）
  String _generateTitle(String content) {
    final trimmed = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= 30) return trimmed;
    return '${trimmed.substring(0, 30)}...';
  }

  /// 将当前 messages 同步到 sessions 列表中的当前会话，返回更新后的 sessions
  /// 如果当前会话还没有标题且 messages 中有用户消息，自动生成标题
  List<ChatSession> _syncedSessions(List<ChatMessage> messages) {
    final currentId = state.currentSessionId;
    if (currentId == null) return state.sessions;
    final sessions = List<ChatSession>.from(state.sessions);
    final idx = sessions.indexWhere((s) => s.id == currentId);
    if (idx < 0) return sessions;

    var title = sessions[idx].title;
    // 当前会话还没有消息且即将添加用户消息时，自动生成标题
    if (sessions[idx].messages.isEmpty || title.isEmpty) {
      final firstUser = messages
          .where((m) => m.role == 'user' && !m.isStreaming)
          .firstOrNull;
      if (firstUser != null && firstUser.content.isNotEmpty) {
        title = _generateTitle(firstUser.content);
      }
    }
    sessions[idx] = sessions[idx].copyWith(title: title, messages: messages);
    return sessions;
  }

  /// 持久化所有会话到 SharedPreferences
  Future<void> _persistSessions() async {
    try {
      // 先同步当前消息到会话列表
      final sessionsToSave = _syncedSessions(state.messages);
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(sessionsToSave.map((s) => s.toJson()).toList());
      await prefs.setString(_sessionsStorageKey, json);
    } catch (e) {
      appLog.warning('Failed to persist AI sessions', error: e);
    }
  }

  /// 从 SharedPreferences 加载持久化的会话
  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_sessionsStorageKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        final sessions = list
            .map((s) => ChatSession.fromJson(s as Map<String, dynamic>))
            .toList();
        if (sessions.isNotEmpty) {
          final current = sessions.first;
          state = state.copyWith(
            sessions: sessions,
            currentSessionId: current.id,
            messages: current.messages,
          );
          return;
        }
      }
    } catch (e) {
      appLog.warning('Failed to load AI sessions', error: e);
    }
    // 没有持久化会话，创建默认会话
    _ensureDefaultSession();
  }

  /// 确保至少有一个默认会话
  void _ensureDefaultSession() {
    if (state.currentSessionId != null && state.sessions.isNotEmpty) return;
    final session = ChatSession(
      id: const Uuid().v4(),
      title: '',
      messages: const [],
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      sessions: [session],
      currentSessionId: session.id,
      messages: const [],
    );
  }

  /// 重试发送上一条用户消息（用于错误 banner 的重试按钮）。
  /// 会移除当前最后一条用户消息并重新发送，避免消息重复。
  Future<void> retryLastMessage() async {
    if (state.isLoading) return;

    // 从消息列表中找到最后一条用户消息
    final messages = List<ChatMessage>.from(state.messages);
    String? lastUserContent;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'user') {
        lastUserContent = messages[i].content;
        messages.removeAt(i);
        break;
      }
    }

    if (lastUserContent == null || lastUserContent.isEmpty) return;

    // 移除旧的用户消息并清除错误状态
    state = state.copyWith(
      messages: messages,
      sessions: _syncedSessions(messages),
      clearError: true,
    );

    // 重新发送
    await sendMessage(lastUserContent);
  }

  /// 重新生成最后一条 AI 回复。
  /// 删除最后一条 AI 回复和对应的用户消息，然后重新发送该用户消息。
  Future<void> regenerateLastResponse() async {
    if (state.isLoading) return;

    final messages = List<ChatMessage>.from(state.messages);

    // 找到并移除最后一条 assistant 消息
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'assistant') {
        messages.removeAt(i);
        break;
      }
    }

    // 找到最后一条 user 消息的内容并移除
    String? lastUserContent;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'user') {
        lastUserContent = messages[i].content;
        messages.removeAt(i);
        break;
      }
    }

    if (lastUserContent == null || lastUserContent.isEmpty) return;

    // 更新状态（移除旧消息并同步会话）
    state = state.copyWith(
      messages: messages,
      sessions: _syncedSessions(messages),
      clearError: true,
    );

    // 重新发送用户消息
    await sendMessage(lastUserContent);
  }

  // ─── Memory helpers ────────────────────────────────────────────────

  /// Snapshot returned by [_buildMemoryContext] — the formatted
  /// prompt fragment plus the source rows so the UI can render a
  /// "memory footprint" alongside the assistant's reply.
  MemoryContextBundle _bundle = const MemoryContextBundle.empty();

  /// Last memory bundle used to construct a context. Exposed so the chat
  /// panel can read the same fragment ids the model was "thinking with"
  /// after the assistant's reply completes streaming.
  MemoryContextBundle get lastMemoryContext => _bundle;

  Future<MemoryContextBundle> _buildMemoryContextBundle(
    String userMessage, {
    String? sessionId,
  }) async {
    final builder = MemoryContextBuilder(
      memory: _memory,
      hebbian: ref.read(hebbianServiceProvider),
      activeBuffer: ref.read(activeMemoryBufferProvider),
    );
    final budget = ref.read(settingsProvider).memory.contextBudget;
    _bundle = await builder.buildContext(
      userMessage,
      sessionId: sessionId,
      budget: budget,
    );
    return _bundle;
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
}

final aiProvider = NotifierProvider<AINotifier, AIState>(AINotifier.new);

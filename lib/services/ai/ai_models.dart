import '../../data/models/ai_provider.dart';

/// Information about a tool call requested by the AI model.
class ToolCallInfo {
  final String id;
  final String name;
  final Map<String, dynamic> args;

  ToolCallInfo({required this.id, required this.name, required this.args});
}

/// A single chat message in the AI conversation.
class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final List<ToolCallInfo> toolCalls;
  final String? toolCallDisplay;
  final String? toolResultDisplay;

  /// Stable id used for cross-references (e.g. the "Remember this" button
  /// links a memory fragment back to the originating message). Generated
  /// on first access if the message was constructed without one.
  final String? id;

  /// Memory fragment ids that were injected into this response's context.
  /// Lets the UI render a "memory footprint" so the user can see what the
  /// model was thinking with.
  final List<String> usedMemoryFragmentIds;

  /// Memory summary ids that were injected as a fallback when no fragments
  /// matched.
  final List<String> usedMemorySummaryIds;

  /// Approximate number of memory-context tokens consumed by this turn.
  /// Tracked for the budget cap + UI display.
  final int memoryContextTokens;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.toolCalls = const [],
    this.toolCallDisplay,
    this.toolResultDisplay,
    this.id,
    this.usedMemoryFragmentIds = const [],
    this.usedMemorySummaryIds = const [],
    this.memoryContextTokens = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 序列化为 JSON（仅持久化必要字段，流式/工具调用等瞬态信息不保存）
  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'id': id,
  };

  /// 从 JSON 反序列化
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    id: json['id'] as String?,
  );

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    List<ToolCallInfo>? toolCalls,
    String? toolCallDisplay,
    String? toolResultDisplay,
    List<String>? usedMemoryFragmentIds,
    List<String>? usedMemorySummaryIds,
    int? memoryContextTokens,
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
      usedMemoryFragmentIds:
          usedMemoryFragmentIds ?? this.usedMemoryFragmentIds,
      usedMemorySummaryIds: usedMemorySummaryIds ?? this.usedMemorySummaryIds,
      memoryContextTokens: memoryContextTokens ?? this.memoryContextTokens,
    );
  }
}

/// What [MemoryContextBuilder.buildContext] (or equivalent) decided to put
/// into the system prompt. Carries the formatted string plus the source
/// rows and an approximate token cost so the chat panel can render a
/// "memory footprint" beside the assistant's reply.
class MemoryContextBundle {
  /// Final prompt fragment injected into the system prompt.
  final String? context;

  /// Ids of the memory fragments that were picked.
  final List<String> fragmentIds;

  /// Ids of the summaries used as a fallback (when no fragments fit).
  final List<String> summaryIds;

  /// Approximate number of tokens the formatted context consumed. Tracked
  /// for the user-facing budget display.
  final int tokensUsed;

  /// The budget the picker was targeting.
  final int budget;
  const MemoryContextBundle({
    required this.context,
    required this.fragmentIds,
    required this.summaryIds,
    required this.tokensUsed,
    required this.budget,
  });
  const MemoryContextBundle.empty()
    : context = null,
      fragmentIds = const [],
      summaryIds = const [],
      tokensUsed = 0,
      budget = 0;
  bool get isEmpty =>
      context == null && fragmentIds.isEmpty && summaryIds.isEmpty;
}

/// 一个 AI 对话会话，包含独立的消息历史。
/// 用于多会话管理：用户可创建/切换/重命名/删除会话。
class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
  });

  ChatSession copyWith({
    String? title,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    title: json['title'] as String,
    messages: (json['messages'] as List?)
        ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList() ??
        const [],
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// State for the AI chat notifier.
class AIState {
  /// 当前会话的消息列表（等同于当前 session 的 messages，保留以兼容旧代码）
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final AIProvider? activeProvider;
  final AIModel? activeModel;

  /// 所有对话会话列表
  final List<ChatSession> sessions;

  /// 当前活跃会话 ID
  final String? currentSessionId;

  AIState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.activeProvider,
    this.activeModel,
    this.sessions = const [],
    this.currentSessionId,
  });

  /// 获取当前活跃会话
  ChatSession? get currentSession {
    if (currentSessionId == null) return null;
    try {
      return sessions.firstWhere((s) => s.id == currentSessionId);
    } catch (_) {
      return null;
    }
  }

  AIState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    AIProvider? activeProvider,
    AIModel? activeModel,
    List<ChatSession>? sessions,
    String? currentSessionId,
    bool clearError = false,
    bool clearProvider = false,
    bool clearModel = false,
    bool clearCurrentSessionId = false,
  }) {
    return AIState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeProvider: clearProvider
          ? null
          : (activeProvider ?? this.activeProvider),
      activeModel: clearModel ? null : (activeModel ?? this.activeModel),
      sessions: sessions ?? this.sessions,
      currentSessionId: clearCurrentSessionId
          ? null
          : (currentSessionId ?? this.currentSessionId),
    );
  }
}

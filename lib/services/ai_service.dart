import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ai_provider.dart';
import 'connectivity_service.dart';
import 'settings_service.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({String? content, bool? isStreaming}) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
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
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  @override
  AIState build() {
    _syncActiveConfig();
    return AIState();
  }

  void _syncActiveConfig() {
    final aiConfig = ref.read(aiConfigProvider);
    final config = aiConfig.activeConfig;
    if (config != null) {
      final provider = aiConfig.activeProvider;
      final model = aiConfig.activeModel;
      if (provider != null && model != null) {
        state = state.copyWith(activeProvider: provider, activeModel: model);
      }
    }
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
  }) async {
    if (state.isLoading) return;

    var provider =
        state.activeProvider ??
        ref.read(aiConfigProvider).activeProvider;
    var model =
        state.activeModel ?? ref.read(aiConfigProvider).activeModel;

    final connectivity = ref.read(connectivityProvider);
    if (!connectivity.isOnline) {
      if (provider != null && provider.protocol != ApiProtocol.ollama) {
        final offlineProvider = ref.read(connectivityProvider.notifier).getOfflineProvider();
        final offlineModel = ref.read(connectivityProvider.notifier).getOfflineModel(offlineProvider);
        if (offlineProvider != null && offlineModel != null) {
          provider = offlineProvider;
          model = offlineModel;
        } else {
          state = state.copyWith(
            error: OfflineNoModelError().toString(),
          );
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

    if (provider.protocol.requiresApiKey) {
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

    try {
      final messages = _buildMessages(systemPrompt, context);
      final apiKey = provider.protocol.requiresApiKey
          ? await ref
                .read(aiConfigProvider.notifier)
                .getApiKeyForProvider(provider.id)
          : null;

      if (provider.protocol == ApiProtocol.ollama) {
        final response = await _sendRequest(
          provider: provider,
          model: model,
          messages: messages,
          apiKey: apiKey,
          stream: false,
        );
        final content = _extractContent(response, provider.protocol);
        _updateLastAssistantMessage(content, isStreaming: false);
        return;
      }

      final response = await _sendRequest(
        provider: provider,
        model: model,
        messages: messages,
        apiKey: apiKey,
        stream: true,
      );

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

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

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
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...provider.authHeaders(),
    };

    switch (provider.protocol) {
      case ApiProtocol.openaiCompatible:
        return _dio.post(
          provider.chatEndpoint,
          options: Options(
            headers: headers,
            responseType: stream ? ResponseType.stream : ResponseType.json,
          ),
          data: jsonEncode({
            'model': model.id,
            'messages': messages,
            'stream': stream,
          }),
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

      case ApiProtocol.ollama:
        return _dio.post(
          provider.chatEndpoint,
          data: jsonEncode({
            'model': model.id,
            'messages': messages,
            'stream': false,
          }),
        );
    }
  }

  String _extractContent(dynamic response, ApiProtocol protocol) {
    try {
      final data = response.data;
      switch (protocol) {
        case ApiProtocol.openaiCompatible:
          final choices = data?['choices'] as List?;
          if (choices == null || choices.isEmpty) return '';
          return choices[0]?['message']?['content'] as String? ?? '';
        case ApiProtocol.anthropic:
          final content = data?['content'] as List?;
          if (content == null || content.isEmpty) return '';
          return content.first?['text'] as String? ?? '';
        case ApiProtocol.ollama:
          return data?['message']?['content'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('Extract content error: $e');
      return '';
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
      case ApiProtocol.ollama:
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
          case ApiProtocol.ollama:
            return data['error'] as String? ?? e.message ?? 'Unknown error';
        }
      }
    } catch (_) {
      debugPrint('AI: failed to extract error message from response');
    }
    return e.message ?? 'Unknown error';
  }
}

final aiProvider = NotifierProvider<AINotifier, AIState>(AINotifier.new);

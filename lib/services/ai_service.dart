import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_service.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({required this.role, required this.content, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class AIState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final String activeModel;

  AIState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.activeModel = 'gpt-4o',
  });

  AIState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    String? activeModel,
    bool clearError = false,
  }) {
    return AIState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeModel: activeModel ?? this.activeModel,
    );
  }
}

class AINotifier extends StateNotifier<AIState> {
  final Dio _dio;

  AINotifier() : _dio = Dio(), super(AIState());

  void setActiveModel(String model) {
    state = state.copyWith(activeModel: model);
  }

  Future<void> sendMessage(
    String userMessage, {
    String? systemPrompt,
    String? context,
  }) async {
    final apiKey = _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      state = state.copyWith(
        error: 'API key not set. Please configure it in Settings.',
      );
      return;
    }

    final userMsg = ChatMessage(role: 'user', content: userMessage);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearError: true,
    );

    try {
      final messages = <Map<String, String>>[];
      if (systemPrompt != null || context != null) {
        messages.add({
          'role': 'system',
          'content':
              '${systemPrompt ?? "You are a helpful AI assistant."}\n\n${context != null ? "Context:\n$context" : ""}',
        });
      }
      for (final msg in state.messages) {
        messages.add({'role': msg.role, 'content': msg.content});
      }

      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode({
          'model': state.activeModel,
          'messages': messages,
          'stream': false,
        }),
      );

      final assistantContent =
          response.data['choices'][0]['message']['content'] as String;
      final assistantMsg = ChatMessage(
        role: 'assistant',
        content: assistantContent,
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data?['error']?['message'] ??
          e.message ??
          'Unknown error';
      state = state.copyWith(isLoading: false, error: errorMsg);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Stream<String> sendMessageStream(
    String userMessage, {
    String? systemPrompt,
    String? context,
  }) async* {
    final apiKey = _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      yield '[Error] API key not set';
      return;
    }

    final userMsg = ChatMessage(role: 'user', content: userMessage);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearError: true,
    );

    try {
      final messages = <Map<String, String>>[];
      if (systemPrompt != null || context != null) {
        messages.add({
          'role': 'system',
          'content':
              '${systemPrompt ?? "You are a helpful AI assistant."}\n\n${context != null ? "Context:\n$context" : ""}',
        });
      }
      for (final msg in state.messages) {
        messages.add({'role': msg.role, 'content': msg.content});
      }

      final response = await _dio.post(
        'https://api.openai.com/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: jsonEncode({
          'model': state.activeModel,
          'messages': messages,
          'stream': true,
        }),
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
              final delta = json['choices'][0]['delta']['content'];
              if (delta != null) {
                buffer.write(delta);
                yield delta;
              }
            } catch (_) {}
          }
        }
      }

      final assistantMsg = ChatMessage(
        role: 'assistant',
        content: buffer.toString(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      yield '[Error] $e';
    }
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  String? _getApiKey() {
    final container = _container;
    return container?.read(settingsProvider.notifier).apiKey;
  }

  ProviderContainer? _container;
  void setContainer(ProviderContainer container) {
    _container = container;
  }
}

final aiProvider = StateNotifierProvider<AINotifier, AIState>((ref) {
  final notifier = AINotifier();
  notifier.setContainer(ref.container);
  return notifier;
});

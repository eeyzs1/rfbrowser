import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModelInfo {
  final String id;
  final String name;
  final String provider;
  final bool isLocal;

  ModelInfo({
    required this.id,
    required this.name,
    required this.provider,
    this.isLocal = false,
  });
}

class ModelRouter {
  final Dio _dio = Dio();

  Future<List<ModelInfo>> getCloudModels(String apiKey) async {
    final models = <ModelInfo>[];
    try {
      final response = await _dio.get(
        'https://api.openai.com/v1/models',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );
      final data = response.data;
      if (data is Map && data.containsKey('data')) {
        for (final model in data['data']) {
          final id = model['id'] as String;
          if (id.startsWith('gpt-') ||
              id.startsWith('o1-') ||
              id.startsWith('o3-')) {
            models.add(ModelInfo(id: id, name: id, provider: 'openai'));
          }
        }
      }
    } catch (_) {}
    return models;
  }

  Future<List<ModelInfo>> getLocalModels(String endpoint) async {
    final models = <ModelInfo>[];
    try {
      final response = await _dio.get('$endpoint/api/tags');
      final data = response.data;
      if (data is Map && data.containsKey('models')) {
        for (final model in data['models']) {
          final name = model['name'] as String;
          models.add(
            ModelInfo(id: name, name: name, provider: 'ollama', isLocal: true),
          );
        }
      }
    } catch (_) {}
    return models;
  }

  Future<String> chat({
    required String model,
    required List<Map<String, String>> messages,
    String? apiKey,
    String? localEndpoint,
  }) async {
    if (model.contains('gpt') || model.contains('o1') || model.contains('o3')) {
      return _chatOpenAI(model, messages, apiKey!);
    } else if (model.contains('claude')) {
      return _chatAnthropic(model, messages, apiKey!);
    } else if (model.contains('deepseek')) {
      return _chatDeepSeek(model, messages, apiKey!);
    } else {
      return _chatOllama(
        model,
        messages,
        localEndpoint ?? 'http://localhost:11434',
      );
    }
  }

  Future<String> _chatOpenAI(
    String model,
    List<Map<String, String>> messages,
    String apiKey,
  ) async {
    final response = await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: jsonEncode({'model': model, 'messages': messages}),
    );
    return response.data['choices'][0]['message']['content'];
  }

  Future<String> _chatAnthropic(
    String model,
    List<Map<String, String>> messages,
    String apiKey,
  ) async {
    final systemMsg =
        messages
            .where((m) => m['role'] == 'system')
            .map((m) => m['content']!)
            .firstOrNull ??
        '';
    final chatMsgs = messages.where((m) => m['role'] != 'system').toList();
    final response = await _dio.post(
      'https://api.anthropic.com/v1/messages',
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
      ),
      data: jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'system': systemMsg,
        'messages': chatMsgs,
      }),
    );
    final content = response.data['content'] as List;
    return content.first['text'] ?? '';
  }

  Future<String> _chatDeepSeek(
    String model,
    List<Map<String, String>> messages,
    String apiKey,
  ) async {
    final response = await _dio.post(
      'https://api.deepseek.com/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: jsonEncode({'model': model, 'messages': messages}),
    );
    return response.data['choices'][0]['message']['content'];
  }

  Future<String> _chatOllama(
    String model,
    List<Map<String, String>> messages,
    String endpoint,
  ) async {
    final response = await _dio.post(
      '$endpoint/api/chat',
      data: jsonEncode({'model': model, 'messages': messages, 'stream': false}),
    );
    return response.data['message']['content'];
  }
}

final modelRouterProvider = Provider<ModelRouter>((ref) => ModelRouter());

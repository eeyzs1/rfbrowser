import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ai_provider.dart';

class ModelDiscovery {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<List<AIModel>> fetchModels(
    AIProvider provider, {
    String? apiKey,
  }) async {
    try {
      switch (provider.protocol) {
        case ApiProtocol.openaiCompatible:
          return _fetchOpenAIModels(provider, apiKey);
        case ApiProtocol.anthropic:
          return _fetchAnthropicModels(provider, apiKey);
        case ApiProtocol.ollama:
          return _fetchOllamaModels(provider);
      }
    } catch (e) {
      debugPrint('Model discovery error: $e');
      return [];
    }
  }

  Future<List<AIModel>> _fetchOpenAIModels(
    AIProvider provider,
    String? apiKey,
  ) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _dio.get(
      provider.modelsEndpoint,
      options: Options(headers: headers),
    );

    final data = response.data;
    if (data is! Map || !data.containsKey('data')) return [];

    final models = <AIModel>[];
    for (final item in data['data']) {
      final id = item['id'] as String;
      models.add(
        AIModel(
          id: id,
          providerId: provider.id,
          displayName: _humanizeModelId(id),
          capabilities: _inferCapabilities(id),
        ),
      );
    }
    return models;
  }

  Future<List<AIModel>> _fetchAnthropicModels(
    AIProvider provider,
    String? apiKey,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['x-api-key'] = apiKey;
    }

    final response = await _dio.get(
      provider.modelsEndpoint,
      options: Options(headers: headers),
    );

    final data = response.data;
    if (data is! Map || !data.containsKey('data')) return [];

    final models = <AIModel>[];
    for (final item in data['data']) {
      final id = item['id'] as String;
      models.add(
        AIModel(
          id: id,
          providerId: provider.id,
          displayName: _humanizeModelId(id),
          capabilities: _inferCapabilities(id),
        ),
      );
    }
    return models;
  }

  Future<List<AIModel>> _fetchOllamaModels(AIProvider provider) async {
    final response = await _dio.get(provider.modelsEndpoint);

    final data = response.data;
    if (data is! Map || !data.containsKey('models')) return [];

    final models = <AIModel>[];
    for (final item in data['models']) {
      final name = item['name'] as String;
      final model = item['model'] as String? ?? name;
      final details = item['details'] as Map<String, dynamic>?;

      Set<ModelCapability> capabilities = {ModelCapability.text};
      if (details != null) {
        final families = details['families'] as List?;
        if (families != null &&
            families.any((f) => f == 'clip' || f == 'llava')) {
          capabilities = {ModelCapability.text, ModelCapability.vision};
        }
      }

      models.add(
        AIModel(
          id: model,
          providerId: provider.id,
          displayName: name,
          capabilities: capabilities,
        ),
      );
    }
    return models;
  }

  Set<ModelCapability> _inferCapabilities(String modelId) {
    final id = modelId.toLowerCase();
    final visionKeywords = [
      'vision',
      'visual',
      '4o',
      'gpt-4o',
      'gpt-4-turbo',
      'claude-3-5',
      'claude-3-opus',
      'claude-3-sonnet',
      'gemini',
      'qwen-vl',
      'llava',
      'pixtral',
    ];
    final isVision = visionKeywords.any((k) => id.contains(k));
    return {ModelCapability.text, if (isVision) ModelCapability.vision};
  }

  String _humanizeModelId(String id) {
    if (id.startsWith('gpt-4o-mini')) return 'GPT-4o Mini';
    if (id.startsWith('gpt-4o')) return 'GPT-4o';
    if (id.startsWith('gpt-4-turbo')) return 'GPT-4 Turbo';
    if (id.startsWith('gpt-4')) return 'GPT-4';
    if (id.startsWith('gpt-3.5')) return 'GPT-3.5';
    if (id.startsWith('o1-mini')) return 'o1 Mini';
    if (id.startsWith('o1-preview')) return 'o1 Preview';
    if (id.startsWith('o1-')) return 'o1';
    if (id.startsWith('o3-mini')) return 'o3 Mini';
    if (id.startsWith('o3-')) return 'o3';
    if (id.startsWith('claude-3-5-sonnet')) return 'Claude 3.5 Sonnet';
    if (id.startsWith('claude-3-5-haiku')) return 'Claude 3.5 Haiku';
    if (id.startsWith('claude-3-opus')) return 'Claude 3 Opus';
    if (id.startsWith('claude-3-sonnet')) return 'Claude 3 Sonnet';
    if (id.startsWith('claude-3-haiku')) return 'Claude 3 Haiku';
    if (id.startsWith('claude-')) return 'Claude';
    if (id.startsWith('deepseek-reasoner')) return 'DeepSeek Reasoner';
    if (id.startsWith('deepseek-chat')) return 'DeepSeek Chat';
    if (id.startsWith('deepseek-')) return 'DeepSeek';
    return id;
  }
}

final modelDiscoveryProvider = Provider<ModelDiscovery>(
  (ref) => ModelDiscovery(),
);

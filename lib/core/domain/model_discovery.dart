import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/builtin_model_registry.dart';
import '../logging/app_logger.dart';
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
      }
    } catch (e) {
      appLog.warning('Model discovery error', error: e);
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
      final builtin = BuiltinModelRegistry.lookup(id);
      models.add(
        AIModel(
          id: id,
          providerId: provider.id,
          displayName: _humanizeModelId(id),
          capabilities: builtin?.capabilities ?? _inferCapabilities(id),
          contextWindow:
              item['context_length'] as int? ??
              item['context_window'] as int? ??
              builtin?.contextWindow,
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
      final builtin = BuiltinModelRegistry.lookup(id);
      models.add(
        AIModel(
          id: id,
          providerId: provider.id,
          displayName: _humanizeModelId(id),
          capabilities: builtin?.capabilities ?? _inferCapabilities(id),
          contextWindow:
              item['context_length'] as int? ??
              item['context_window'] as int? ??
              builtin?.contextWindow,
        ),
      );
    }
    return models;
  }

  @visibleForTesting
  Set<ModelCapability> inferCapabilities(String modelId) =>
      _inferCapabilities(modelId);

  @visibleForTesting
  String humanizeModelId(String id) => _humanizeModelId(id);

  /// 关键词推断模型能力(builtin registry 未命中时的 fallback)。
  ///
  /// 优先级:`/v1/models` 返回的 context_length > [BuiltinModelRegistry] >
  /// 此处的关键词推断。builtin registry 命中时会直接使用其 capabilities,
  /// 此方法仅在 registry 未覆盖的模型上生效。
  ///
  /// tools 推断保守策略:仅在模型 id 明确包含 function-calling 相关标记时
  /// 才标 tools,避免对未知模型发送 tools 数组导致 API 报错。
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

    // 工具调用关键词:GPT-4 全系、Claude 3+、Gemini、Qwen-max/plus/turbo
    // 已被 builtin registry 覆盖;此处仅捕获 registry 未覆盖的边缘情况,
    // 例如 gpt-4-xxx 自定义微调名、claude-3-xxx-custom 等。
    final toolsKeywords = [
      'gpt-4',
      'gpt-3.5-turbo',
      'claude-3',
      'claude-3-5',
      'gemini',
      'qwen-max',
      'qwen-plus',
      'qwen-turbo',
      'deepseek-chat',
      'function-call',
      'tool-use',
    ];
    final isTools = toolsKeywords.any((k) => id.contains(k));

    return {
      ModelCapability.text,
      if (isVision) ModelCapability.vision,
      if (isTools) ModelCapability.tools,
    };
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

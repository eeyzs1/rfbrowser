import 'package:flutter/material.dart';

enum ApiProtocol {
  openaiCompatible,
  anthropic,
  ollama;

  String get label => switch (this) {
        ApiProtocol.openaiCompatible => 'OpenAI Compatible',
        ApiProtocol.anthropic => 'Anthropic',
        ApiProtocol.ollama => 'Ollama',
      };

  IconData get icon => switch (this) {
        ApiProtocol.openaiCompatible => Icons.cloud,
        ApiProtocol.anthropic => Icons.auto_awesome,
        ApiProtocol.ollama => Icons.computer,
      };

  String get defaultBaseUrl => switch (this) {
        ApiProtocol.openaiCompatible => 'https://api.openai.com',
        ApiProtocol.anthropic => 'https://api.anthropic.com',
        ApiProtocol.ollama => 'http://localhost:11434',
      };

  bool get requiresApiKey => this != ApiProtocol.ollama;

  String get modelsPath => switch (this) {
        ApiProtocol.openaiCompatible => '/v1/models',
        ApiProtocol.anthropic => '/v1/models',
        ApiProtocol.ollama => '/api/tags',
      };

  String get chatPath => switch (this) {
        ApiProtocol.openaiCompatible => '/v1/chat/completions',
        ApiProtocol.anthropic => '/v1/messages',
        ApiProtocol.ollama => '/api/chat',
      };
}

enum ModelCapability {
  text,
  vision;

  String get label => switch (this) {
        ModelCapability.text => 'Text',
        ModelCapability.vision => 'Vision',
      };

  String get icon => switch (this) {
        ModelCapability.text => '📝',
        ModelCapability.vision => '👁',
      };
}

class AIProvider {
  final String id;
  final String name;
  final ApiProtocol protocol;
  final String baseUrl;
  final String? apiKey;
  final bool isEnabled;

  const AIProvider({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    this.apiKey,
    this.isEnabled = true,
  });

  AIProvider copyWith({
    String? name,
    ApiProtocol? protocol,
    String? baseUrl,
    String? apiKey,
    bool? isEnabled,
  }) {
    return AIProvider(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  String get modelsEndpoint => '$baseUrl${protocol.modelsPath}';
  String get chatEndpoint => '$baseUrl${protocol.chatPath}';

  Map<String, String> authHeaders() {
    switch (protocol) {
      case ApiProtocol.openaiCompatible:
        return apiKey != null
            ? {'Authorization': 'Bearer $apiKey'}
            : {};
      case ApiProtocol.anthropic:
        return {
          'x-api-key': apiKey ?? '',
          'anthropic-version': '2023-06-01',
        };
      case ApiProtocol.ollama:
        return {};
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.index,
        'baseUrl': baseUrl,
        'isEnabled': isEnabled,
      };

  factory AIProvider.fromJson(Map<String, dynamic> json) => AIProvider(
        id: json['id'] as String,
        name: json['name'] as String,
        protocol: ApiProtocol.values[json['protocol'] as int],
        baseUrl: json['baseUrl'] as String,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIProvider && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AIModel {
  final String id;
  final String providerId;
  final String displayName;
  final Set<ModelCapability> capabilities;
  final int? contextWindow;
  final bool isCustom;

  const AIModel({
    required this.id,
    required this.providerId,
    required this.displayName,
    this.capabilities = const {ModelCapability.text},
    this.contextWindow,
    this.isCustom = false,
  });

  AIModel copyWith({
    String? displayName,
    Set<ModelCapability>? capabilities,
    int? contextWindow,
  }) {
    return AIModel(
      id: id,
      providerId: providerId,
      displayName: displayName ?? this.displayName,
      capabilities: capabilities ?? this.capabilities,
      contextWindow: contextWindow ?? this.contextWindow,
      isCustom: isCustom,
    );
  }

  bool get supportsTextOnly =>
      capabilities.length == 1 && capabilities.contains(ModelCapability.text);

  bool get supportsVision => capabilities.contains(ModelCapability.vision);

  String get capabilityLabel {
    final parts = capabilities.map((c) => c.label).toList()..sort();
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerId': providerId,
        'displayName': displayName,
        'capabilities':
            capabilities.map((c) => c.index).toList(),
        'contextWindow': contextWindow,
        'isCustom': isCustom,
      };

  factory AIModel.fromJson(Map<String, dynamic> json) => AIModel(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        displayName: json['displayName'] as String,
        capabilities: (json['capabilities'] as List?)
                ?.map((i) => ModelCapability.values[i as int])
                .toSet() ??
            {ModelCapability.text},
        contextWindow: json['contextWindow'] as int?,
        isCustom: json['isCustom'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIModel && id == other.id && providerId == other.providerId;

  @override
  int get hashCode => Object.hash(id, providerId);
}

class ActiveAIConfig {
  final String providerId;
  final String modelId;

  const ActiveAIConfig({
    required this.providerId,
    required this.modelId,
  });

  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'modelId': modelId,
      };

  factory ActiveAIConfig.fromJson(Map<String, dynamic> json) => ActiveAIConfig(
        providerId: json['providerId'] as String,
        modelId: json['modelId'] as String,
      );
}

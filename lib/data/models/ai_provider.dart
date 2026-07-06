import 'package:flutter/material.dart';

enum ApiProtocol {
  openaiCompatible,
  anthropic;

  String get label => switch (this) {
    ApiProtocol.openaiCompatible => 'OpenAI Compatible',
    ApiProtocol.anthropic => 'Anthropic',
  };

  IconData get icon => switch (this) {
    ApiProtocol.openaiCompatible => Icons.cloud,
    ApiProtocol.anthropic => Icons.auto_awesome,
  };

  String get defaultBaseUrl => switch (this) {
    ApiProtocol.openaiCompatible => 'https://api.openai.com',
    ApiProtocol.anthropic => 'https://api.anthropic.com',
  };

  String get modelsPath => switch (this) {
    ApiProtocol.openaiCompatible => '/v1/models',
    ApiProtocol.anthropic => '/v1/models',
  };

  String get chatPath => switch (this) {
    ApiProtocol.openaiCompatible => '/v1/chat/completions',
    ApiProtocol.anthropic => '/v1/messages',
  };
}

enum ModelCapability {
  text,
  vision,
  tools;

  String get label => switch (this) {
    ModelCapability.text => 'Text',
    ModelCapability.vision => 'Vision',
    ModelCapability.tools => 'Tools',
  };

  String get icon => switch (this) {
    ModelCapability.text => '📝',
    ModelCapability.vision => '👁',
    ModelCapability.tools => '🔧',
  };
}

class AIProvider {
  final String id;
  final String name;
  final ApiProtocol protocol;
  final String baseUrl;
  final String? apiKey;
  final bool isEnabled;
  final bool requiresApiKey;

  AIProvider({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    this.apiKey,
    this.isEnabled = true,
    bool? requiresApiKey,
  }) : requiresApiKey =
           requiresApiKey ?? _inferRequiresApiKey(protocol, baseUrl);

  static bool _inferRequiresApiKey(ApiProtocol protocol, String baseUrl) {
    if (_isLocalUrl(baseUrl)) return false;
    return true;
  }

  static bool _isLocalUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('0.0.0.0') ||
        lower.contains('[::1]');
  }

  bool get isLocal => _isLocalUrl(baseUrl);

  IconData get displayIcon => isLocal ? Icons.computer : protocol.icon;

  AIProvider copyWith({
    String? name,
    ApiProtocol? protocol,
    String? baseUrl,
    String? apiKey,
    bool? isEnabled,
    bool? requiresApiKey,
    bool clearApiKey = false,
  }) {
    return AIProvider(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
      isEnabled: isEnabled ?? this.isEnabled,
      requiresApiKey: requiresApiKey ?? this.requiresApiKey,
    );
  }

  /// True if [baseUrl] already ends with a version segment like `/v1`, `/v4`.
  /// When true, the endpoint getters strip the `/v1` prefix from the protocol
  /// path to avoid producing double-versioned URLs like `/v4/v1/chat/completions`.
  bool get _baseUrlHasVersion => RegExp(r'/v\d+$').hasMatch(baseUrl);

  String get modelsEndpoint {
    final path = protocol.modelsPath;
    if (_baseUrlHasVersion && path.startsWith('/v1')) {
      return '$baseUrl${path.substring(3)}';
    }
    return '$baseUrl$path';
  }

  String get chatEndpoint {
    final path = protocol.chatPath;
    if (_baseUrlHasVersion && path.startsWith('/v1')) {
      return '$baseUrl${path.substring(3)}';
    }
    return '$baseUrl$path';
  }

  String get embeddingEndpoint {
    if (_baseUrlHasVersion) {
      return '$baseUrl/embeddings';
    }
    return '$baseUrl/v1/embeddings';
  }

  Map<String, String> authHeaders() {
    switch (protocol) {
      case ApiProtocol.openaiCompatible:
        return apiKey != null ? {'Authorization': 'Bearer $apiKey'} : {};
      case ApiProtocol.anthropic:
        return {'x-api-key': apiKey ?? '', 'anthropic-version': '2023-06-01'};
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.index,
    'baseUrl': baseUrl,
    'isEnabled': isEnabled,
    'requiresApiKey': requiresApiKey,
  };

  factory AIProvider.fromJson(Map<String, dynamic> json) {
    final protocolIndex = json['protocol'] as int;
    final protocol = protocolIndex < ApiProtocol.values.length
        ? ApiProtocol.values[protocolIndex]
        : ApiProtocol.openaiCompatible;
    final baseUrl = json['baseUrl'] as String;
    return AIProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      protocol: protocol,
      baseUrl: baseUrl,
      isEnabled: json['isEnabled'] as bool? ?? true,
      requiresApiKey: json['requiresApiKey'] as bool?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIProvider && id == other.id;

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

  bool get supportsTools => capabilities.contains(ModelCapability.tools);

  String get capabilityLabel {
    final parts = capabilities.map((c) => c.label).toList()..sort();
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'providerId': providerId,
    'displayName': displayName,
    'capabilities': capabilities.map((c) => c.index).toList(),
    'contextWindow': contextWindow,
    'isCustom': isCustom,
  };

  factory AIModel.fromJson(Map<String, dynamic> json) => AIModel(
    id: json['id'] as String,
    providerId: json['providerId'] as String,
    displayName: json['displayName'] as String,
    capabilities:
        (json['capabilities'] as List?)
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

  const ActiveAIConfig({required this.providerId, required this.modelId});

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'modelId': modelId,
  };

  factory ActiveAIConfig.fromJson(Map<String, dynamic> json) => ActiveAIConfig(
    providerId: json['providerId'] as String,
    modelId: json['modelId'] as String,
  );
}

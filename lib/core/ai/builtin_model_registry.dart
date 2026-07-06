import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

import '../../data/models/ai_provider.dart';

/// 内置模型元数据。
class BuiltinModelInfo {
  /// 上下文窗口大小(token)。
  final int contextWindow;

  /// 单次响应最大输出 token。
  final int maxOutputTokens;

  /// 模型能力集合(含 tools 表示支持 function calling)。
  final Set<ModelCapability> capabilities;

  const BuiltinModelInfo({
    required this.contextWindow,
    required this.maxOutputTokens,
    required this.capabilities,
  });

  factory BuiltinModelInfo.fromJson(Map<String, dynamic> json) {
    final caps = <ModelCapability>{};
    for (final c in json['capabilities'] as List) {
      final name = c as String;
      switch (name) {
        case 'text':
          caps.add(ModelCapability.text);
          break;
        case 'vision':
          caps.add(ModelCapability.vision);
          break;
        case 'tools':
          caps.add(ModelCapability.tools);
          break;
      }
    }
    if (caps.isEmpty) caps.add(ModelCapability.text);
    return BuiltinModelInfo(
      contextWindow: json['contextWindow'] as int,
      maxOutputTokens: json['maxOutputTokens'] as int,
      capabilities: caps,
    );
  }
}

class _Entry {
  final String prefix;
  final BuiltinModelInfo info;
  const _Entry(this.prefix, this.info);
}

/// 内置模型元数据库。
///
/// 数据来源:`assets/data/builtin_models.json`(主)，以及下方硬编码
/// [_fallbackEntries](兜底——JSON 加载失败时使用)。更新模型元数据只需
/// 编辑 JSON 文件，无需改代码重新编译。
///
/// 通过 [lookup] 按 model id 查询元数据。未命中返回 null,调用方应 fallback
/// 到关键词推断([ModelDiscovery._inferCapabilities])或让用户手动填写。
class BuiltinModelRegistry {
  BuiltinModelRegistry._();

  /// JSON 加载的条目(按前缀长度降序排列)。null 表示尚未加载或加载失败。
  static List<_Entry>? _jsonEntries;

  /// 是否已尝试加载 JSON(无论成功与否)。避免重复加载。
  static bool _loadAttempted = false;

  /// 按 model id 查询内置元数据。
  ///
  /// 匹配规则:小写前缀匹配。优先查 JSON 加载的条目,未加载或未命中则查
  /// 硬编码兜底条目。未命中返回 null。
  static BuiltinModelInfo? lookup(String modelId) {
    if (modelId.isEmpty) return null;
    final id = modelId.toLowerCase();

    // 优先使用 JSON 条目(如果已加载)
    final jsonEntries = _jsonEntries;
    if (jsonEntries != null) {
      for (final entry in jsonEntries) {
        if (id.startsWith(entry.prefix)) return entry.info;
      }
    }

    // 兜底:硬编码条目
    for (final entry in _fallbackEntries) {
      if (id.startsWith(entry.prefix)) return entry.info;
    }
    return null;
  }

  /// 从 `assets/data/builtin_models.json` 加载模型元数据。
  ///
  /// 应在 app 启动时调用(如 `_initApp`)。加载成功后 [lookup] 优先使用
  /// JSON 数据;加载失败则静默回退到硬编码兜底条目,不抛异常。
  static Future<void> loadFromAssets() async {
    if (_loadAttempted) return;
    _loadAttempted = true;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/builtin_models.json',
      );
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final models = data['models'] as List;
      final entries =
          models
              .map(
                (m) => _Entry(
                  (m['prefix'] as String).toLowerCase(),
                  BuiltinModelInfo.fromJson(m as Map<String, dynamic>),
                ),
              )
              .toList()
            ..sort((a, b) => b.prefix.length.compareTo(a.prefix.length));
      _jsonEntries = entries;
      if (kDebugMode) {
        debugPrint(
          'BuiltinModelRegistry: loaded ${entries.length} entries from JSON',
        );
      }
    } catch (e) {
      // 静默失败:使用硬编码兜底条目
      if (kDebugMode) {
        debugPrint(
          'BuiltinModelRegistry: JSON load failed, using fallback: $e',
        );
      }
    }
  }

  /// 硬编码兜底条目(JSON 加载失败时使用)。
  ///
  /// 仅包含最常用模型,确保 app 在 JSON 缺失时仍能基本运行。
  /// 完整数据在 `assets/data/builtin_models.json` 中。
  static const List<_Entry> _fallbackEntries = [
    // OpenAI
    _Entry(
      'gpt-4o-mini',
      BuiltinModelInfo(
        contextWindow: 128000,
        maxOutputTokens: 16384,
        capabilities: {
          ModelCapability.text,
          ModelCapability.vision,
          ModelCapability.tools,
        },
      ),
    ),
    _Entry(
      'gpt-4o',
      BuiltinModelInfo(
        contextWindow: 128000,
        maxOutputTokens: 16384,
        capabilities: {
          ModelCapability.text,
          ModelCapability.vision,
          ModelCapability.tools,
        },
      ),
    ),
    _Entry(
      'gpt-4',
      BuiltinModelInfo(
        contextWindow: 8192,
        maxOutputTokens: 4096,
        capabilities: {ModelCapability.text, ModelCapability.tools},
      ),
    ),
    // Anthropic
    _Entry(
      'claude-3-5-sonnet',
      BuiltinModelInfo(
        contextWindow: 200000,
        maxOutputTokens: 8192,
        capabilities: {
          ModelCapability.text,
          ModelCapability.vision,
          ModelCapability.tools,
        },
      ),
    ),
    _Entry(
      'claude-3',
      BuiltinModelInfo(
        contextWindow: 200000,
        maxOutputTokens: 4096,
        capabilities: {
          ModelCapability.text,
          ModelCapability.vision,
          ModelCapability.tools,
        },
      ),
    ),
    // 智谱 GLM
    _Entry(
      'glm-4',
      BuiltinModelInfo(
        contextWindow: 128000,
        maxOutputTokens: 8192,
        capabilities: {ModelCapability.text, ModelCapability.tools},
      ),
    ),
    // DeepSeek
    _Entry(
      'deepseek-chat',
      BuiltinModelInfo(
        contextWindow: 64000,
        maxOutputTokens: 8192,
        capabilities: {ModelCapability.text, ModelCapability.tools},
      ),
    ),
    // Qwen
    _Entry(
      'qwen',
      BuiltinModelInfo(
        contextWindow: 131072,
        maxOutputTokens: 8192,
        capabilities: {ModelCapability.text, ModelCapability.tools},
      ),
    ),
    // Gemini
    _Entry(
      'gemini',
      BuiltinModelInfo(
        contextWindow: 1000000,
        maxOutputTokens: 8192,
        capabilities: {
          ModelCapability.text,
          ModelCapability.vision,
          ModelCapability.tools,
        },
      ),
    ),
  ];
}

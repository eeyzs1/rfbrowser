import 'dart:convert';

import '../../data/models/ai_provider.dart';

/// Accumulated tool-call state for a single streaming response chunk.
class AccToolCall {
  String id = '';
  String name = '';
  final StringBuffer argsBuffer = StringBuffer();

  String get argsJson => argsBuffer.toString();
}

/// Accumulates streaming chunks from an AI provider, separating text
/// content from tool-call deltas. Used by the tool-call loop to collect
/// a full response before executing tools.
class AiStreamAccumulator {
  final Map<int, AccToolCall> _toolCallsByIndex = {};
  final StringBuffer _textBuffer = StringBuffer();

  List<AccToolCall> get toolCalls =>
      (_toolCallsByIndex.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .map((e) => e.value)
          .toList();

  String get text => _textBuffer.toString();

  bool get hasToolCalls => _toolCallsByIndex.isNotEmpty;

  /// Process a single decoded JSON chunk. Updates internal text and
  /// tool-call buffers.
  void accumulateChunk(
    Map<String, dynamic> json,
    ApiProtocol protocol,
  ) {
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return;

    for (final choice in choices) {
      final delta = choice['delta'] as Map<String, dynamic>?;
      if (delta == null) continue;

      // Text content
      final content = delta['content'] as String?;
      if (content != null) {
        _textBuffer.write(content);
      }

      // Tool calls (OpenAI format)
      final tcItems = delta['tool_calls'] as List<dynamic>?;
      if (tcItems == null) continue;

      for (final tc in tcItems) {
        final tcMap = tc as Map<String, dynamic>;
        final index = tcMap['index'] as int? ?? 0;
        final acc = _toolCallsByIndex.putIfAbsent(index, () => AccToolCall());
        if (tcMap.containsKey('id') && tcMap['id'] != null) {
          acc.id = tcMap['id'] as String;
        }
        final func = tcMap['function'] as Map<String, dynamic>?;
        if (func != null) {
          if (func.containsKey('name') && func['name'] != null) {
            acc.name = func['name'] as String;
          }
          final argsDelta = func['arguments'] as String?;
          if (argsDelta != null) {
            acc.argsBuffer.write(argsDelta);
          }
        }
      }
    }
  }

  /// Parse tool-call arguments JSON, returning an empty map on failure.
  static Map<String, dynamic> parseArgs(String argsJson) {
    try {
      return jsonDecode(argsJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

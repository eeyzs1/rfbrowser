import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/logging/app_logger.dart';
import '../../data/models/ai_provider.dart';

/// Protocol-aware HTTP request builder and response parser for AI
/// providers. Encapsulates the differences between OpenAI-compatible
/// and Anthropic streaming / non-streaming APIs.
class AiProtocolStrategy {
  final Dio _dio;

  AiProtocolStrategy(this._dio);

  /// Send a chat-completion request to [provider]'s endpoint. The
  /// response is a [Response] whose `data` is either a decoded JSON
  /// object (non-stream) or a byte stream (stream).
  ///
  /// [temperature] / [maxTokens] are optional sampling parameters.
  /// When null, they are omitted from the request body (provider uses
  /// its own defaults). This fixes the previous hardcoding where
  /// Anthropic always sent max_tokens=4096 and OpenAI sent neither.
  Future<Response<dynamic>> sendRequest({
    required AIProvider provider,
    required AIModel model,
    required List<Map<String, dynamic>> messages,
    String? apiKey,
    required bool stream,
    List<Map<String, dynamic>>? tools,
    double? temperature,
    int? maxTokens,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...provider.authHeaders(),
    };

    switch (provider.protocol) {
      case ApiProtocol.openaiCompatible:
        final body = <String, dynamic>{
          'model': model.id,
          'messages': messages,
          'stream': stream,
        };
        if (temperature != null) body['temperature'] = temperature;
        if (maxTokens != null) body['max_tokens'] = maxTokens;
        if (tools != null && tools.isNotEmpty) {
          body['tools'] = tools;
        }
        return _dio.post(
          provider.chatEndpoint,
          options: Options(
            headers: headers,
            responseType: stream ? ResponseType.stream : ResponseType.json,
          ),
          data: jsonEncode(body),
        );

      case ApiProtocol.anthropic:
        final systemMsg = messages
            .where((m) => m['role'] == 'system')
            .map((m) => m['content'] as String)
            .firstOrNull;
        final chatMsgs = messages.where((m) => m['role'] != 'system').toList();

        // Anthropic requires max_tokens (non-optional). Fall back to a
        // safe default when the caller does not specify one.
        final effectiveMaxTokens = maxTokens ?? 4096;

        final body = <String, dynamic>{
          'model': model.id,
          'max_tokens': effectiveMaxTokens,
          'system': systemMsg,
          'messages': chatMsgs,
          'stream': stream,
        };
        if (temperature != null) body['temperature'] = temperature;
        if (tools != null && tools.isNotEmpty) {
          body['tools'] = tools;
        }

        return _dio.post(
          provider.chatEndpoint,
          options: Options(
            headers: headers,
            responseType: stream ? ResponseType.stream : ResponseType.json,
          ),
          data: jsonEncode(body),
        );
    }
  }

  /// Extract the text delta from a single streaming chunk.
  String? extractStreamDelta(dynamic json, ApiProtocol protocol) {
    switch (protocol) {
      case ApiProtocol.openaiCompatible:
        final choices = json is Map ? json['choices'] : null;
        if (choices is List && choices.isNotEmpty) {
          final first = choices[0];
          if (first is Map) {
            final delta = first['delta'];
            if (delta is Map) {
              return delta['content'] as String?;
            }
          }
        }
        return null;
      case ApiProtocol.anthropic:
        final type = json['type'] as String?;
        if (type == 'content_block_delta') {
          return json['delta']?['text'] as String?;
        }
        return null;
    }
  }

  /// Extract a human-readable error message from a [DioException],
  /// honouring the provider's response shape.
  String extractErrorMessage(DioException e, ApiProtocol protocol) {
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
        }
      }
    } catch (_) {
      appLog.warning('AI: failed to extract error message from response');
    }
    return e.message ?? 'Unknown error';
  }
}

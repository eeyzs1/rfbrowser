// 覆盖验收标准:
//   AC-AI-Protocol-001: 协议策略选择逻辑 — 根据 provider.protocol 路由到正确分支
//   AC-AI-Protocol-002: 不同 provider 对应不同策略 — OpenAI vs Anthropic 请求体差异
//   AC-AI-Protocol-003: buildRequest (sendRequest) — 请求头、请求体、stream/tools 处理
//   AC-AI-Protocol-004: parseResponse (extractStreamDelta) — 流式增量文本提取
//   AC-AI-Protocol-005: extractErrorMessage — DioException 错误信息提取与降级

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/services/ai/ai_protocol_strategy.dart';

/// 捕获的请求数据，用于断言 sendRequest 构建的请求内容。
class CapturedRequest {
  final String path;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> body;
  final ResponseType responseType;

  CapturedRequest({
    required this.path,
    required this.headers,
    required this.body,
    required this.responseType,
  });
}

/// Dio HttpClientAdapter 的 mock 实现。
/// 捕获请求并返回预设响应，不发起真实网络调用。
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._responder);

  /// 最后一次捕获的请求（测试中断言用）。
  CapturedRequest? lastRequest;

  final Future<ResponseBody> Function(CapturedRequest) _responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String? bodyText;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      bodyText = utf8.decode(bytes);
    }
    final captured = CapturedRequest(
      path: options.path,
      headers: options.headers.map((k, v) => MapEntry(k, v.toString())),
      body: bodyText != null
          ? jsonDecode(bodyText) as Map<String, dynamic>
          : <String, dynamic>{},
      responseType: options.responseType,
    );
    lastRequest = captured;
    return _responder(captured);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponseBody(Map<String, dynamic> body, {int statusCode = 200}) {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
  return ResponseBody(
    Stream.value(bytes),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

DioException _makeDioException({
  Map<String, dynamic>? responseData,
  String? message,
  int statusCode = 400,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/test'),
    response: responseData != null
        ? Response(
            requestOptions: RequestOptions(path: '/test'),
            data: responseData,
            statusCode: statusCode,
          )
        : null,
    message: message,
  );
}

AIProvider _openAiProvider({String? apiKey}) => AIProvider(
      id: 'openai-1',
      name: 'OpenAI',
      protocol: ApiProtocol.openaiCompatible,
      baseUrl: 'https://api.openai.com',
      apiKey: apiKey ?? 'sk-test-key',
    );

AIProvider _anthropicProvider({String? apiKey}) => AIProvider(
      id: 'anthropic-1',
      name: 'Anthropic',
      protocol: ApiProtocol.anthropic,
      baseUrl: 'https://api.anthropic.com',
      apiKey: apiKey ?? 'sk-ant-test',
    );

const _testModel = AIModel(
  id: 'gpt-4',
  providerId: 'openai-1',
  displayName: 'GPT-4',
);

const _claudeModel = AIModel(
  id: 'claude-3',
  providerId: 'anthropic-1',
  displayName: 'Claude 3',
);

void main() {
  group('AC-AI-Protocol-001: 协议策略选择逻辑', () {
    test('OpenAI Compatible provider 路由到 openaiCompatible 分支', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured, isNotNull);
      // OpenAI 分支特征：body 中有 model + messages + stream，无 system/max_tokens
      expect(captured!.body.containsKey('model'), isTrue);
      expect(captured!.body.containsKey('messages'), isTrue);
      expect(captured!.body.containsKey('stream'), isTrue);
      expect(captured!.body.containsKey('system'), isFalse);
      expect(captured!.body.containsKey('max_tokens'), isFalse);
    });

    test('Anthropic provider 路由到 anthropic 分支', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _anthropicProvider(),
        model: _claudeModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured, isNotNull);
      // Anthropic 分支特征：body 中有 max_tokens + system
      expect(captured!.body.containsKey('max_tokens'), isTrue);
      expect(captured!.body['max_tokens'], 4096);
      expect(captured!.body.containsKey('system'), isTrue);
    });

    test('策略实例可复用于不同 provider', () async {
      final capturedList = <CapturedRequest>[];
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          capturedList.add(req);
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'a'}],
        stream: false,
      );
      await strategy.sendRequest(
        provider: _anthropicProvider(),
        model: _claudeModel,
        messages: [{'role': 'user', 'content': 'b'}],
        stream: false,
      );

      expect(capturedList.length, 2);
      expect(capturedList[0].body.containsKey('max_tokens'), isFalse);
      expect(capturedList[1].body.containsKey('max_tokens'), isTrue);
    });
  });

  group('AC-AI-Protocol-002: 不同 provider 对应不同策略', () {
    test('OpenAI: 请求路径为 /v1/chat/completions', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured!.path, 'https://api.openai.com/v1/chat/completions');
    });

    test('Anthropic: 请求路径为 /v1/messages', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _anthropicProvider(),
        model: _claudeModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured!.path, 'https://api.anthropic.com/v1/messages');
    });

    test('OpenAI: authHeaders 使用 Bearer token', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(apiKey: 'sk-secret'),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured!.headers['Authorization'], 'Bearer sk-secret');
      expect(captured!.headers.containsKey('x-api-key'), isFalse);
    });

    test('Anthropic: authHeaders 使用 x-api-key + anthropic-version', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _anthropicProvider(apiKey: 'sk-ant-secret'),
        model: _claudeModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured!.headers['x-api-key'], 'sk-ant-secret');
      expect(captured!.headers['anthropic-version'], '2023-06-01');
      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });

    test('Anthropic: system 消息从 messages 提取到顶层 system 字段', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _anthropicProvider(),
        model: _claudeModel,
        messages: [
          {'role': 'system', 'content': 'You are helpful.'},
          {'role': 'user', 'content': 'hi'},
        ],
        stream: false,
      );

      expect(captured!.body['system'], 'You are helpful.');
      final msgs = captured!.body['messages'] as List<dynamic>;
      expect(msgs.length, 1);
      expect(msgs[0]['role'], 'user');
    });

    test('Anthropic: 无 system 消息时 system 字段为 null', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _anthropicProvider(),
        model: _claudeModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured!.body['system'], isNull);
    });

    test('OpenAI: system 消息保留在 messages 数组中', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [
          {'role': 'system', 'content': 'You are helpful.'},
          {'role': 'user', 'content': 'hi'},
        ],
        stream: false,
      );

      expect(captured!.body.containsKey('system'), isFalse);
      final msgs = captured!.body['messages'] as List<dynamic>;
      expect(msgs.length, 2);
      expect(msgs[0]['role'], 'system');
    });
  });

  group('AC-AI-Protocol-003: buildRequest (sendRequest)', () {
    test('OpenAI: body 包含 model、messages、stream 字段', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hello'}],
        stream: false,
      );

      expect(captured!.body['model'], 'gpt-4');
      expect(captured!.body['stream'], false);
      expect((captured!.body['messages'] as List).length, 1);
    });

    test('OpenAI: stream=true 时 responseType 为 stream', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: true,
      );

      expect(captured!.responseType, ResponseType.stream);
      expect(captured!.body['stream'], true);
    });

    test('OpenAI: stream=false 时 responseType 为 json', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured!.responseType, ResponseType.json);
    });

    test('OpenAI: 传入 tools 时 body 包含 tools 字段', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      final tools = [
        {
          'type': 'function',
          'function': {
            'name': 'search',
            'description': 'Search the web',
            'parameters': {'type': 'object', 'properties': {}},
          },
        },
      ];

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
        tools: tools,
      );

      expect(captured!.body.containsKey('tools'), isTrue);
      expect((captured!.body['tools'] as List).length, 1);
    });

    test('OpenAI: tools 为空列表时不添加 tools 字段', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
        tools: [],
      );

      expect(captured!.body.containsKey('tools'), isFalse);
    });

    test('OpenAI: tools 为 null 时不添加 tools 字段', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
        tools: null,
      );

      expect(captured!.body.containsKey('tools'), isFalse);
    });

    test('Content-Type header 始终为 application/json', () async {
      CapturedRequest? captured;
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          captured = req;
          return Future.value(_jsonResponseBody({'ok': true}));
        });
      final strategy = AiProtocolStrategy(dio);

      await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(captured!.headers['Content-Type'], 'application/json');
    });

    test('sendRequest 返回 Dio Response 且 statusCode 为 200', () async {
      final dio = Dio()
        ..httpClientAdapter = _MockAdapter((req) {
          return Future.value(_jsonResponseBody({'choices': []}));
        });
      final strategy = AiProtocolStrategy(dio);

      final response = await strategy.sendRequest(
        provider: _openAiProvider(),
        model: _testModel,
        messages: [{'role': 'user', 'content': 'hi'}],
        stream: false,
      );

      expect(response.statusCode, 200);
      expect(response.data, isA<Map<String, dynamic>>());
    });
  });

  group('AC-AI-Protocol-004: parseResponse (extractStreamDelta)', () {
    test('OpenAI: 从 choices[0].delta.content 提取文本', () {
      final strategy = AiProtocolStrategy(Dio());
      final json = {
        'choices': [
          {'delta': {'content': 'Hello'}},
        ],
      };

      final delta = strategy.extractStreamDelta(json, ApiProtocol.openaiCompatible);

      expect(delta, 'Hello');
    });

    test('OpenAI: content 为 null 时返回 null', () {
      final strategy = AiProtocolStrategy(Dio());
      final json = {
        'choices': [
          {'delta': <String, dynamic>{}},
        ],
      };

      final delta = strategy.extractStreamDelta(json, ApiProtocol.openaiCompatible);

      expect(delta, isNull);
    });

    test('OpenAI: choices 为空时返回 null', () {
      final strategy = AiProtocolStrategy(Dio());
      final delta = strategy.extractStreamDelta(
        {'choices': <dynamic>[]},
        ApiProtocol.openaiCompatible,
      );

      expect(delta, isNull);
    });

    test('OpenAI: choices 为 null 时返回 null', () {
      final strategy = AiProtocolStrategy(Dio());
      final delta = strategy.extractStreamDelta(
        <String, dynamic>{},
        ApiProtocol.openaiCompatible,
      );

      expect(delta, isNull);
    });

    test('Anthropic: content_block_delta 类型提取 text', () {
      final strategy = AiProtocolStrategy(Dio());
      final json = {
        'type': 'content_block_delta',
        'delta': {'text': 'Hello from Claude'},
      };

      final delta = strategy.extractStreamDelta(json, ApiProtocol.anthropic);

      expect(delta, 'Hello from Claude');
    });

    test('Anthropic: 非 content_block_delta 类型返回 null', () {
      final strategy = AiProtocolStrategy(Dio());
      final json = {
        'type': 'message_start',
        'delta': {'text': 'should be ignored'},
      };

      final delta = strategy.extractStreamDelta(json, ApiProtocol.anthropic);

      expect(delta, isNull);
    });

    test('Anthropic: type 为 null 时返回 null', () {
      final strategy = AiProtocolStrategy(Dio());
      final delta = strategy.extractStreamDelta(
        <String, dynamic>{},
        ApiProtocol.anthropic,
      );

      expect(delta, isNull);
    });

    test('Anthropic: content_block_delta 但 delta.text 为 null 时返回 null', () {
      final strategy = AiProtocolStrategy(Dio());
      final json = {
        'type': 'content_block_delta',
        'delta': <String, dynamic>{},
      };

      final delta = strategy.extractStreamDelta(json, ApiProtocol.anthropic);

      expect(delta, isNull);
    });
  });

  group('AC-AI-Protocol-005: extractErrorMessage', () {
    test('OpenAI: 从 error.message 提取错误信息', () {
      final strategy = AiProtocolStrategy(Dio());
      final e = _makeDioException(
        responseData: {'error': {'message': 'Invalid API key'}},
      );

      final msg = strategy.extractErrorMessage(e, ApiProtocol.openaiCompatible);

      expect(msg, 'Invalid API key');
    });

    test('Anthropic: 从 error.message 提取错误信息', () {
      final strategy = AiProtocolStrategy(Dio());
      final e = _makeDioException(
        responseData: {'error': {'message': 'Rate limited'}},
      );

      final msg = strategy.extractErrorMessage(e, ApiProtocol.anthropic);

      expect(msg, 'Rate limited');
    });

    test('response.data 为 null 时降级到 e.message', () {
      final strategy = AiProtocolStrategy(Dio());
      final e = _makeDioException(message: 'Connection refused');

      final msg = strategy.extractErrorMessage(e, ApiProtocol.openaiCompatible);

      expect(msg, 'Connection refused');
    });

    test('response.data 非 Map（如 String）时降级到 e.message', () {
      final strategy = AiProtocolStrategy(Dio());
      final e = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          data: 'Internal Server Error',
          statusCode: 500,
        ),
        message: 'Server error',
      );

      final msg = strategy.extractErrorMessage(e, ApiProtocol.openaiCompatible);

      expect(msg, 'Server error');
    });

    test('error.message 缺失且无 response.data 时返回 Unknown error', () {
      final strategy = AiProtocolStrategy(Dio());
      final e = DioException(requestOptions: RequestOptions(path: '/test'));

      final msg = strategy.extractErrorMessage(e, ApiProtocol.openaiCompatible);

      expect(msg, 'Unknown error');
    });

    test('OpenAI: error 对象无 message 字段时降级到 e.message', () {
      final strategy = AiProtocolStrategy(Dio());
      final e = _makeDioException(
        responseData: {'error': <String, dynamic>{}},
        message: 'Fallback message',
      );

      final msg = strategy.extractErrorMessage(e, ApiProtocol.openaiCompatible);

      expect(msg, 'Fallback message');
    });

    test('Anthropic: error 对象无 message 字段时降级到 e.message', () {
      final strategy = AiProtocolStrategy(Dio());
      final e = _makeDioException(
        responseData: {'error': <String, dynamic>{}},
        message: 'Anthropic fallback',
      );

      final msg = strategy.extractErrorMessage(e, ApiProtocol.anthropic);

      expect(msg, 'Anthropic fallback');
    });

    test('e.message 为 null 且 error.message 缺失时返回 Unknown error', () {
      final strategy = AiProtocolStrategy(Dio());
      final e = _makeDioException(
        responseData: {'error': <String, dynamic>{}},
      );

      final msg = strategy.extractErrorMessage(e, ApiProtocol.openaiCompatible);

      expect(msg, 'Unknown error');
    });
  });
}

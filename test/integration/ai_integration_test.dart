// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' show Platform, HttpOverrides;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/services/ai_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/services/connectivity_service.dart';
import 'package:rfbrowser/services/dio_factory.dart';

const secureStorage = FlutterSecureStorage();

class _RealHttpOverrides extends HttpOverrides {}

class TestAIConfigNotifier extends AIConfigNotifier {
  final AIConfigState _state;
  TestAIConfigNotifier(this._state);
  @override
  AIConfigState build() => _state;
  @override
  set state(AIConfigState newState) => super.state = newState;
  @override
  Future<String?> getApiKeyForProvider(String providerId) async {
    try {
      final key = await secureStorage.read(key: 'ai_key_$providerId');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    final envKey =
        Platform.environment['BAILIAN_API_KEY'] ??
        Platform.environment['DASHSCOPE_API_KEY'];
    return envKey;
  }
}

class TestConnectivityNotifier extends ConnectivityNotifier {
  @override
  ConnectivityState build() => ConnectivityState(isOnline: true);
  @override
  set state(ConnectivityState newState) => super.state = newState;
}

Future<String?> tryGetBailianApiKey() async {
  String? apiKey;

  try {
    apiKey = await secureStorage.read(key: 'ai_key_bailian');
  } catch (_) {}

  if (apiKey == null || apiKey.isEmpty) {
    apiKey = Platform.environment['BAILIAN_API_KEY'];
  }

  if (apiKey == null || apiKey.isEmpty) {
    apiKey = Platform.environment['DASHSCOPE_API_KEY'];
  }

  return (apiKey != null && apiKey.isNotEmpty) ? apiKey : null;
}

const _skipReason = '未找到百炼 API Key，请设置环境变量 BAILIAN_API_KEY 或 DASHSCOPE_API_KEY';

String? _cachedApiKey;

void main() {
  HttpOverrides.global = _RealHttpOverrides();

  group('AI - 百炼 直接 API 测试', () {
    setUpAll(() async {
      _cachedApiKey = await tryGetBailianApiKey();
    });

    test('1. 读取百炼 API Key', () async {
      expect(_cachedApiKey, isNotEmpty);
      print('API Key 已找到 (长度: ${_cachedApiKey!.length})');
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('2. 发送简单消息并验证回复', () async {
      final dio = DioFactory.instance;

      final response = await dio.post(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': 'qwen-turbo',
          'messages': [
            {'role': 'user', 'content': '你好！请用一句话介绍你自己。'},
          ],
        }),
      );

      expect(response.statusCode, 200);
      final data = response.data;
      expect(data['choices'], isNotEmpty);
      final content = data['choices'][0]['message']['content'] as String;
      expect(content, isNotEmpty);
      print('百炼回复: $content');
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('3. 中文对话上下文理解', () async {
      final dio = DioFactory.instance;

      final response = await dio.post(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': 'qwen-turbo',
          'messages': [
            {'role': 'user', 'content': '我最近在学习Flutter开发，能给我推荐3个最佳实践吗？'},
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      expect(response.statusCode, 200);
      final content =
          response.data['choices'][0]['message']['content'] as String;
      expect(content, isNotEmpty);
      expect(content.length, greaterThan(20));
      print('推荐最佳实践:\n$content');
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('4. 流式输出 (SSE)', () async {
      final dio = DioFactory.instance;

      final response = await dio.post(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
          responseType: ResponseType.stream,
        ),
        data: jsonEncode({
          'model': 'qwen-turbo',
          'messages': [
            {'role': 'user', 'content': '用三句话描述AI的未来发展趋势。'},
          ],
          'stream': true,
        }),
      );

      final buffer = StringBuffer();
      int chunkCount = 0;
      final stream = response.data.stream;
      await for (final chunk in stream) {
        final text = utf8.decode(chunk);
        for (final line in text.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') break;
            try {
              final json = jsonDecode(data);
              final delta =
                  json['choices']?[0]?['delta']?['content'] as String?;
              if (delta != null) {
                buffer.write(delta);
                chunkCount++;
              }
            } catch (_) {}
          }
        }
      }

      final fullContent = buffer.toString();
      expect(fullContent, isNotEmpty);
      expect(chunkCount, greaterThan(0));
      print('流式输出 ($chunkCount chunks): $fullContent');
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('5. AI 错误处理 - 无效 API Key', () async {
      final dio = DioFactory.instance;
      try {
        await dio.post(
          'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer invalid-key-12345',
            },
          ),
          data: jsonEncode({
            'model': 'qwen-turbo',
            'messages': [
              {'role': 'user', 'content': 'Hello'},
            ],
          }),
        );
        fail('应该抛出异常');
      } on DioException catch (e) {
        expect(e.response?.statusCode, isNotNull);
        print('错误处理测试通过: ${e.response?.statusCode} - ${e.message}');
      }
    });

    test('6. System Prompt 消息测试', () async {
      final dio = DioFactory.instance;

      final response = await dio.post(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': 'qwen-turbo',
          'messages': [
            {'role': 'system', 'content': '你是一个Flutter开发专家，回答要简洁，只给代码示例。'},
            {'role': 'user', 'content': '如何在Flutter中创建一个带圆角的Container？'},
          ],
          'temperature': 0.3,
          'max_tokens': 200,
        }),
      );

      expect(response.statusCode, 200);
      final content =
          response.data['choices'][0]['message']['content'] as String;
      expect(content, isNotEmpty);
      print('System Prompt 回复: $content');
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('7. 长文本摘要', () async {
      final dio = DioFactory.instance;

      final response = await dio.post(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': 'qwen-turbo',
          'messages': [
            {
              'role': 'user',
              'content':
                  '简要总结以下内容的核心要点（不超过3句话）：\n\n'
                  'Riverpod 是 Flutter 中的一个响应式状态管理库，由 Remi Rousselet 创建。'
                  '它解决了 Provider 包的一些局限性，提供了编译时安全、更好的测试支持。'
                  'Riverpod 的核心概念包括 Provider（提供值）、Notifier（管理可变状态）、'
                  '以及 Ref（用于在 providers 之间建立依赖关系）。'
                  'Riverpod 支持代码生成，通过 riverpod_generator 可以自动生成 provider 代码。'
                  '它的 ProviderScope 和 ProviderContainer 使得在测试中可以轻松替换依赖。'
                  '与 BLoC 和 Redux 相比，Riverpod 更加轻量级，不需要 boilerplate 代码。',
            },
          ],
          'temperature': 0.3,
          'max_tokens': 150,
        }),
      );

      expect(response.statusCode, 200);
      final content =
          response.data['choices'][0]['message']['content'] as String;
      expect(content, isNotEmpty);
      print('摘要: $content');
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('8. Token 用量统计', () async {
      final dio = DioFactory.instance;

      final response = await dio.post(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': 'qwen-turbo',
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
          'max_tokens': 10,
        }),
      );

      expect(response.statusCode, 200);
      final data = response.data;
      final usage = data['usage'];
      if (usage != null) {
        print(
          'Token 用量: '
          'prompt=${usage['prompt_tokens']}, '
          'completion=${usage['completion_tokens']}, '
          'total=${usage['total_tokens']}',
        );
      }
      expect(data['choices'], isNotEmpty);
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('9. 获取百炼可用模型列表', () async {
      final dio = DioFactory.instance;

      final response = await dio.get(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/models',
        options: Options(headers: {'Authorization': 'Bearer $_cachedApiKey'}),
      );

      expect(response.statusCode, 200);
      final data = response.data;
      expect(data['data'], isNotNull);
      final models = data['data'] as List;
      expect(models, isNotEmpty);
      print('百炼可用模型数量: ${models.length}');
      for (final m in models.take(5)) {
        print('  - ${m['id']}');
      }
    }, skip: _cachedApiKey == null ? _skipReason : null);
  });

  group('AI - AINotifier 集成测试', () {
    ProviderContainer? container;
    AINotifier? aiNotifier;
    bool hasApiKey = false;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final key = await tryGetBailianApiKey();
      hasApiKey = key != null;
    });

    setUp(() async {
      if (!hasApiKey) return;

      final apiKey = await tryGetBailianApiKey();
      if (apiKey == null) return;

      final bailianProvider = AIProvider(
        id: 'bailian',
        name: '阿里百炼',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode',
        apiKey: apiKey,
      );
      const bailianModel = AIModel(
        id: 'qwen-turbo',
        providerId: 'bailian',
        displayName: 'Qwen Turbo',
      );

      final configState = AIConfigState(
        providers: [bailianProvider],
        models: const [bailianModel],
      );

      container = ProviderContainer(
        overrides: [
          connectivityProvider.overrideWith(() => TestConnectivityNotifier()),
          aiConfigProvider.overrideWith(
            () => TestAIConfigNotifier(configState),
          ),
        ],
      );

      aiNotifier = container!.read(aiProvider.notifier);
      aiNotifier!.state = aiNotifier!.state.copyWith(
        activeProvider: bailianProvider,
        activeModel: bailianModel,
      );
    });

    tearDown(() {
      container?.dispose();
      container = null;
    });

    test('10. AINotifier.sendMessage 完整调用', () async {
      expect(aiNotifier!.state.activeProvider?.id, 'bailian');
      expect(aiNotifier!.state.activeModel?.id, 'qwen-turbo');

      await aiNotifier!.sendMessage('用一句话介绍Flutter');

      expect(aiNotifier!.state.isLoading, false);
      expect(aiNotifier!.state.error, isNull);
      expect(aiNotifier!.state.messages.length, greaterThanOrEqualTo(2));

      final userMsg = aiNotifier!.state.messages[0];
      final assistantMsg = aiNotifier!.state.messages[1];
      if (assistantMsg.role != 'assistant') {
        fail('Expected assistant message, got ${assistantMsg.role}');
      }

      expect(userMsg.role, 'user');
      expect(userMsg.content, '用一句话介绍Flutter');
      expect(assistantMsg.content, isNotEmpty);

      print('AINotifier 回复: ${assistantMsg.content}');
    }, skip: !hasApiKey ? _skipReason : null);
  });
}

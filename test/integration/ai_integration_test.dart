// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' show Directory, File, HttpOverrides, Platform;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/ai_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/services/connectivity_service.dart';
import 'package:rfbrowser/services/dio_factory.dart';
import '../helpers/sqflite_test_setup.dart';

const secureStorage = FlutterSecureStorage();

class _RealHttpOverrides extends HttpOverrides {}

class TestAIConfigNotifier extends AIConfigNotifier {
  final AIConfigState _state;
  final String? _apiKey;
  TestAIConfigNotifier(this._state, this._apiKey);
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
    return _apiKey ??
        Platform.environment['AI_API_KEY'] ??
        Platform.environment['DASHSCOPE_API_KEY'];
  }
}

class TestConnectivityNotifier extends ConnectivityNotifier {
  @override
  ConnectivityState build() => ConnectivityState(isOnline: true);
  @override
  set state(ConnectivityState newState) => super.state = newState;
}

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
}

final _envVars = <String, String>{};

Future<void> _loadEnvVars() async {
  if (_envVars.isNotEmpty) return;
  try {
    final candidates = [
      p.join(Directory.current.path, '.env'),
      p.join(Directory.current.path, 'test', '.env'),
    ];
    for (final envPath in candidates) {
      final envFile = File(envPath);
      if (await envFile.exists()) {
        final lines = await envFile.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final eqIndex = trimmed.indexOf('=');
          if (eqIndex < 0) continue;
          final key = trimmed.substring(0, eqIndex).trim();
          var value = trimmed.substring(eqIndex + 1).trim();
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          }
          _envVars[key] = value;
        }
      }
    }
  } catch (e) {
    print('读取 .env 文件失败: $e');
  }
}

Future<String?> tryGetAiApiKey() async {
  await _loadEnvVars();

  String? apiKey;

  try {
    apiKey = await secureStorage.read(key: 'ai_key_test-ai');
  } catch (_) {}

  if (apiKey == null || apiKey.isEmpty) {
    final envKey = _envVars['AI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty && !envKey.startsWith('sk-your')) {
      apiKey = envKey;
    }
  }

  if (apiKey == null || apiKey.isEmpty) {
    apiKey = Platform.environment['AI_API_KEY'];
  }

  if (apiKey == null || apiKey.isEmpty) {
    apiKey = Platform.environment['DASHSCOPE_API_KEY'];
  }

  return (apiKey != null && apiKey.isNotEmpty) ? apiKey : null;
}

String get _aiBaseUrl =>
    _envVars['AI_BASE_URL'] ??
    Platform.environment['AI_BASE_URL'] ??
    'https://dashscope.aliyuncs.com/compatible-mode';

String get _aiModel =>
    _envVars['AI_MODEL'] ?? Platform.environment['AI_MODEL'] ?? 'qwen-turbo';

/// If [_aiBaseUrl] already ends with a version segment (e.g. `/v1`, `/v4`),
/// append the endpoint path directly; otherwise prepend `/v1/`.
String get _chatEndpoint {
  if (RegExp(r'/v\d+$').hasMatch(_aiBaseUrl)) {
    return '$_aiBaseUrl/chat/completions';
  }
  return '$_aiBaseUrl/v1/chat/completions';
}

String get _modelsEndpoint {
  if (RegExp(r'/v\d+$').hasMatch(_aiBaseUrl)) {
    return '$_aiBaseUrl/models';
  }
  return '$_aiBaseUrl/v1/models';
}

const _skipReason = '未找到 AI API Key，请设置环境变量 AI_API_KEY 或 DASHSCOPE_API_KEY';

String? _cachedApiKey;

Future<void> main() async {
  HttpOverrides.global = _RealHttpOverrides();
  setupSqfliteForTests();

  // Load API key BEFORE group/test definitions — the `skip` parameter is
  // evaluated at definition time, so it must be available upfront.
  _cachedApiKey = await tryGetAiApiKey();

  group('AI - 直接 API 测试', () {
    test('1. 读取 AI API Key', () async {
      expect(_cachedApiKey, isNotEmpty);
      print('API Key 已找到 (长度: ${_cachedApiKey!.length})');
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('2. 发送简单消息并验证回复', () async {
      final dio = DioFactory.instance;

      final response = await dio.post(
        _chatEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': _aiModel,
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
      print('AI 回复: $content');
    }, skip: _cachedApiKey == null ? _skipReason : null);

    test('3. 中文对话上下文理解', () async {
      final dio = DioFactory.instance;

      final response = await dio.post(
        _chatEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': _aiModel,
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
        _chatEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
          responseType: ResponseType.stream,
        ),
        data: jsonEncode({
          'model': _aiModel,
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
          _chatEndpoint,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer invalid-key-12345',
            },
          ),
          data: jsonEncode({
            'model': _aiModel,
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
        _chatEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': _aiModel,
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
        _chatEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': _aiModel,
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
        _chatEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': _aiModel,
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

    test('9. 获取可用模型列表', () async {
      final dio = DioFactory.instance;

      final response = await dio.get(
        _modelsEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $_cachedApiKey'}),
      );

      expect(response.statusCode, 200);
      final data = response.data;
      expect(data['data'], isNotNull);
      final models = data['data'] as List;
      expect(models, isNotEmpty);
      print('可用模型数量: ${models.length}');
      for (final m in models.take(5)) {
        print('  - ${m['id']}');
      }
    }, skip: _cachedApiKey == null ? _skipReason : null);
  });

  group('AI - AINotifier 集成测试', () {
    ProviderContainer? container;
    AINotifier? aiNotifier;
    Directory? tempDir;

    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() async {
      if (_cachedApiKey == null) return;

      // Create a temp vault directory so MemoryService gets a valid DB path
      // and background persistence doesn't hit database_closed after tearDown.
      tempDir = Directory.systemTemp.createTempSync('rfb_ai_test_');
      final rfbDir = Directory(p.join(tempDir!.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir!.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );

      final testProvider = AIProvider(
        id: 'test-ai',
        name: 'Test AI',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: _aiBaseUrl,
        apiKey: _cachedApiKey,
      );
      final testModel = AIModel(
        id: _aiModel,
        providerId: 'test-ai',
        displayName: 'Test AI Model',
      );

      final configState = AIConfigState(
        providers: [testProvider],
        models: [testModel],
      );

      container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
          connectivityProvider.overrideWith(() => TestConnectivityNotifier()),
          aiConfigProvider.overrideWith(
            () => TestAIConfigNotifier(configState, _cachedApiKey),
          ),
        ],
      );

      aiNotifier = container!.read(aiProvider.notifier);
      aiNotifier!.state = aiNotifier!.state.copyWith(
        activeProvider: testProvider,
        activeModel: testModel,
      );
    });

    tearDown(() async {
      // Give background persistence (MemoryService.saveMessage / DreamingService)
      // a moment to finish before we dispose the container and close the DB.
      await Future.delayed(const Duration(milliseconds: 500));
      container?.dispose();
      container = null;
      try {
        tempDir?.deleteSync(recursive: true);
      } catch (_) {}
      tempDir = null;
    });

    test(
      '10. AINotifier.sendMessage 完整调用',
      () async {
        expect(aiNotifier!.state.activeProvider?.id, 'test-ai');
        expect(aiNotifier!.state.activeModel?.id, _aiModel);

        await aiNotifier!.sendMessage('用一句话介绍Flutter');

        // Allow background persistence to settle
        await Future.delayed(const Duration(seconds: 2));

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
      },
      skip: _cachedApiKey == null ? _skipReason : null,
    );
  });
}

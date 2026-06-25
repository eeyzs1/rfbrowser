// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' show Directory, File, HttpOverrides, Platform;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/agent/agent_tool_registry.dart';
import 'package:rfbrowser/services/agent/builtin_tools.dart';
import 'package:rfbrowser/services/agent/plan_generator.dart';
import 'package:rfbrowser/services/ai_service.dart';
import 'package:rfbrowser/services/connectivity_service.dart';
import 'package:rfbrowser/services/dio_factory.dart';
import 'package:rfbrowser/services/settings_service.dart';
import '../helpers/sqflite_test_setup.dart';

class _RealHttpOverrides extends HttpOverrides {}

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
}

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
      final key = await const FlutterSecureStorage().read(
        key: 'ai_key_$providerId',
      );
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    return _apiKey ??
        Platform.environment['BAILIAN_API_KEY'] ??
        Platform.environment['DASHSCOPE_API_KEY'];
  }
}

class TestConnectivityNotifier extends ConnectivityNotifier {
  @override
  ConnectivityState build() => ConnectivityState(isOnline: true);
  @override
  set state(ConnectivityState newState) => super.state = newState;
}

final _envVars = <String, String>{};

Future<String?> _loadApiKey() async {
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

    final apiKey = _envVars['BAILIAN_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty && !apiKey.startsWith('sk-your')) {
      return apiKey;
    }
  } catch (e) {
    print('读取 .env 文件失败: $e');
  }

  final envKey =
      Platform.environment['BAILIAN_API_KEY'] ??
      Platform.environment['DASHSCOPE_API_KEY'];
  if (envKey != null && envKey.isNotEmpty) return envKey;

  return null;
}

String? _cachedApiKey;
String _bailianModel = 'qwen-turbo';
String _bailianBaseUrl = 'https://dashscope.aliyuncs.com/compatible-mode';

const _skipReason =
    '未找到百炼 API Key。请在 .env 文件中设置 BAILIAN_API_KEY，'
    '或设置环境变量 BAILIAN_API_KEY / DASHSCOPE_API_KEY';

/// Quick connectivity probe used to decide whether the cached key + model
/// are still valid. Returns false on auth errors, deprecated model, or any
/// unexpected transport failure (in which case we treat the run as
/// "no network available" and skip the network-dependent tests).
Future<bool> _probeBailian() async {
  final base =
      _envVars['BAILIAN_BASE_URL'] ??
      'https://dashscope.aliyuncs.com/compatible-mode';
  final model = _envVars['BAILIAN_MODEL'] ?? 'qwen-turbo';
  try {
    final dio = DioFactory.instance;
    final response = await dio.post(
      '$base/v1/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_cachedApiKey',
        },
        // Don't let dio raise on 4xx — we want to inspect the code.
        validateStatus: (s) => s != null && s < 500,
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
      data: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
        'max_tokens': 1,
      }),
    );
    final code = response.statusCode ?? 0;
    return code >= 200 && code < 400;
  } catch (e) {
    print('Bailian probe threw: $e');
    return false;
  }
}

Future<void> main() async {
  HttpOverrides.global = _RealHttpOverrides();

  setupSqfliteForTests();

  _cachedApiKey = await _loadApiKey();
  if (_cachedApiKey != null) {
    // Quick API probe — bail if the key is rejected (401/403) or the model
    // is deprecated (400). Without this, a stale .env key would surface as
    // confusing "Expected: not empty / true" failures instead of a clean skip.
    final probeOk = await _probeBailian();
    if (!probeOk) {
      print(
        'Bailian API probe failed (key/model rejected). '
        'Treating as "no key available" and skipping all network tests.',
      );
      _cachedApiKey = null;
    }
  }
  if (_cachedApiKey != null) {
    _bailianModel = _envVars['BAILIAN_MODEL'] ?? 'qwen-turbo';
    _bailianBaseUrl =
        _envVars['BAILIAN_BASE_URL'] ??
        'https://dashscope.aliyuncs.com/compatible-mode';
    print(
      'API Key 已加载 (长度: ${_cachedApiKey!.length}), '
      '模型: $_bailianModel, '
      'Base URL: $_bailianBaseUrl',
    );
  } else {
    print(_skipReason);
  }

  group('Agent 集成测试 — 百炼 API', () {
    test(
      '3. PlanGenerator — AI 生成任务计划',
      () async {
        final registry = AgentToolRegistry();
        registry.register(CreateNoteTool((title, content) async => 'ok'));
        registry.register(
          SearchNotesTool((query) async {
            return [
              {'title': '测试笔记', 'score': 0.9, 'snippet': '关于"$query"的内容'},
            ];
          }),
        );
        registry.register(
          AIReasonTool((prompt, systemPrompt) async {
            final dio = DioFactory.instance;
            final response = await dio.post(
              '$_bailianBaseUrl/v1/chat/completions',
              options: Options(
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_cachedApiKey',
                },
              ),
              data: jsonEncode({
                'model': _bailianModel,
                'messages': [
                  {'role': 'system', 'content': systemPrompt},
                  {'role': 'user', 'content': prompt},
                ],
                'temperature': 0.3,
              }),
            );
            return response.data['choices'][0]['message']['content'] as String;
          }),
        );

        final planGenerator = PlanGenerator(registry);
        final systemPrompt = planGenerator.buildSystemPrompt();

        final dio = DioFactory.instance;
        final response = await dio.post(
          '$_bailianBaseUrl/v1/chat/completions',
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_cachedApiKey',
            },
          ),
          data: jsonEncode({
            'model': _bailianModel,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': '搜索关于"量子计算"的笔记，如果没找到就创建一个'},
            ],
            'temperature': 0.3,
          }),
        );

        final llmResponse =
            response.data['choices'][0]['message']['content'] as String;
        expect(llmResponse, isNotEmpty);
        print('LLM 原始回复:\n$llmResponse');

        final steps = planGenerator.parsePlan(llmResponse);
        expect(steps, isNotEmpty, reason: 'AI 应该生成至少一个步骤');
        expect(
          steps.every((s) => registry.hasTool(s.toolName ?? '')),
          isTrue,
          reason: '所有步骤的 toolName 应该在 registry 中',
        );

        for (final step in steps) {
          print('  步骤: ${step.toolName}(${step.args}) — ${step.description}');
        }
      },
      skip: _cachedApiKey == null ? _skipReason : null,
    );

    test(
      '4. AgentToolRegistry — 工具注册与执行',
      () async {
        final registry = AgentToolRegistry();
        var searchCalled = false;
        var reasonCalled = false;

        registry.register(
          SearchNotesTool((query) async {
            searchCalled = true;
            return [
              {'title': '量子计算入门', 'score': 0.95, 'snippet': '关于"$query"的内容'},
            ];
          }),
        );
        registry.register(
          AIReasonTool((prompt, systemPrompt) async {
            reasonCalled = true;
            final dio = DioFactory.instance;
            final response = await dio.post(
              '$_bailianBaseUrl/v1/chat/completions',
              options: Options(
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_cachedApiKey',
                },
              ),
              data: jsonEncode({
                'model': _bailianModel,
                'messages': [
                  {'role': 'system', 'content': systemPrompt ?? ''},
                  {'role': 'user', 'content': prompt},
                ],
                'temperature': 0.3,
                'max_tokens': 100,
              }),
            );
            return response.data['choices'][0]['message']['content'] as String;
          }),
        );

        final searchResult = await registry.execute('search_notes', {
          'query': '量子计算',
        });
        expect(searchResult.success, isTrue);
        expect(searchCalled, isTrue);
        expect(searchResult.output, contains('量子计算'));
        print('搜索工具执行结果: ${searchResult.output}');

        final reasonResult = await registry.execute('ai_reason', {
          'prompt': '用一句话解释量子计算',
          'system_prompt': '你是科学解释助手，回答要简洁。',
        });
        expect(reasonResult.success, isTrue);
        expect(reasonCalled, isTrue);
        expect(reasonResult.output, isNotEmpty);
        print('AI推理工具执行结果: ${reasonResult.output}');
      },
      skip: _cachedApiKey == null ? _skipReason : null,
    );

    test(
      '5. AINotifier + AgentService — 手动模式任务',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('rfb_agent_');
        addTearDown(() {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
        if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

        final vaultState = VaultState(
          currentVault: VaultConfig(
            path: tempDir.path,
            name: 'test',
            lastOpened: DateTime.now(),
          ),
        );

        final bailianProvider = AIProvider(
          id: 'bailian',
          name: '阿里百炼',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: _bailianBaseUrl,
          apiKey: _cachedApiKey,
        );
        final bailianModel = AIModel(
          id: _bailianModel,
          providerId: 'bailian',
          displayName: 'Qwen Turbo',
        );

        final configState = AIConfigState(
          providers: [bailianProvider],
          models: [bailianModel],
          activeConfig: ActiveAIConfig(
            providerId: 'bailian',
            modelId: _bailianModel,
          ),
        );

        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [
            vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
            connectivityProvider.overrideWith(() => TestConnectivityNotifier()),
            aiConfigProvider.overrideWith(
              () => TestAIConfigNotifier(configState, _cachedApiKey),
            ),
          ],
        );
        addTearDown(container.dispose);

        final aiNotifier = container.read(aiProvider.notifier);
        aiNotifier.state = aiNotifier.state.copyWith(
          activeProvider: bailianProvider,
          activeModel: bailianModel,
        );

        await aiNotifier.sendMessage('回复"Agent测试成功"四个字');
        await Future.delayed(const Duration(seconds: 5));

        expect(
          aiNotifier.state.error,
          isNull,
          reason: 'AI 不应报错: ${aiNotifier.state.error}',
        );
        final messages = aiNotifier.state.messages;
        final assistantMsgs = messages.where(
          (m) => m.role == 'assistant' && !m.isStreaming,
        );
        expect(assistantMsgs, isNotEmpty, reason: '应有 AI 回复');
        print('AI 回复: ${assistantMsgs.last.content}');
      },
      skip: _cachedApiKey == null ? _skipReason : null,
    );

    test(
      '6. PlanGenerator — ReAct 循环解析',
      () async {
        final registry = AgentToolRegistry();
        registry.register(
          SearchNotesTool((query) async {
            return [];
          }),
        );
        registry.register(CreateNoteTool((title, content) async => 'ok'));

        final planGenerator = PlanGenerator(registry);

        final reactResponse = jsonEncode({
          'thought': '需要先搜索笔记，看看有没有相关内容',
          'tool': 'search_notes',
          'args': {'query': '量子计算'},
          'done': false,
        });

        final parsed = planGenerator.parseReactResponse(reactResponse);
        expect(parsed, isNotNull);
        expect(parsed!['tool'], 'search_notes');
        expect(parsed['done'], false);
        expect(parsed['thought'], contains('搜索'));

        final finalResponse = jsonEncode({
          'thought': '任务完成',
          'tool': 'final_answer',
          'args': {'answer': '已搜索并创建笔记'},
          'done': true,
        });

        final finalParsed = planGenerator.parseReactResponse(finalResponse);
        expect(finalParsed!['done'], true);
        expect(finalParsed['tool'], 'final_answer');

        print('ReAct 循环解析测试通过');
      },
      skip: _cachedApiKey == null ? _skipReason : null,
    );

    test('7. BuiltinTools — 所有内置工具参数验证', () async {
      final registry = AgentToolRegistry();

      registry.register(NavigateTool((url) async => 'Navigated'));
      registry.register(ExtractTextTool((url) async => 'Extracted'));
      registry.register(CreateNoteTool((title, content) async => 'Created'));
      registry.register(
        SearchNotesTool((query) async {
          return [];
        }),
      );
      registry.register(AIReasonTool((prompt, sys) async => 'Reasoned'));
      registry.register(WebClipTool((url, fmt) async => 'Clipped'));
      registry.register(DeleteNoteTool((title) async => true));
      registry.register(UpdateNoteTool((title, content) async => 'Updated'));
      registry.register(ListNotesTool((tag, limit) async => 'Listed'));
      registry.register(GetTagsTool(() async => 'tag1, tag2'));
      registry.register(MoveNoteTool((title, folder) async => 'Moved'));
      registry.register(RenameNoteTool((oldT, newT) async => 'Renamed'));

      expect(registry.tools.length, 12, reason: '应有 12 个内置工具');

      final navigateResult = await registry.execute('navigate', {
        'url': 'https://example.com',
      });
      expect(navigateResult.success, isTrue);

      final createResult = await registry.execute('create_note', {
        'title': '测试笔记',
        'content': '# 测试\n\n内容',
      });
      expect(createResult.success, isTrue);

      final missingArgResult = await registry.execute('create_note', {
        'content': 'no title',
      });
      expect(missingArgResult.success, isFalse);
      expect(missingArgResult.error, contains('title'));

      final unknownResult = await registry.execute('nonexistent_tool', {});
      expect(unknownResult.success, isFalse);
      expect(unknownResult.error, contains('Unknown'));

      print('所有 12 个工具注册验证通过');
      for (final name in registry.tools.keys) {
        final tool = registry.tools[name]!;
        print(
          '  ✓ $name — ${tool.description} (destructive: ${tool.isDestructive})',
        );
      }
    });

    test('8. AgentPersistence — 任务持久化', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_persist_');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final task = AgentTask(
        id: 'persist-test-001',
        name: '持久化测试任务',
        description: '测试任务持久化',
        mode: TaskMode.manual,
        steps: [
          AgentStep(
            description: '步骤1',
            toolName: 'search_notes',
            args: {'query': 'test'},
            status: TaskStatus.completed,
            result: '搜索完成',
            completedAt: DateTime.now(),
          ),
        ],
        status: TaskStatus.completed,
        result: '任务完成',
        completed: DateTime.now(),
      );

      final json = task.toJson();
      expect(json['id'], 'persist-test-001');
      expect(json['mode'], isNotNull);

      final restored = AgentTask.fromJson(json);
      expect(restored.id, task.id);
      expect(restored.name, task.name);
      expect(restored.mode, task.mode);
      expect(restored.steps.length, 1);
      expect(restored.steps[0].toolName, 'search_notes');

      print('AgentTask 序列化/反序列化测试通过');
    });

    test('9. 完整 ReAct 循环 — AI 驱动多步任务', () async {
      final registry = AgentToolRegistry();
      final executionLog = <String>[];

      registry.register(
        SearchNotesTool((query) async {
          executionLog.add('search_notes($query)');
          return [];
        }),
      );
      registry.register(
        CreateNoteTool((title, content) async {
          executionLog.add('create_note($title)');
          return '笔记已创建: $title';
        }),
      );
      registry.register(
        AIReasonTool((prompt, systemPrompt) async {
          executionLog.add('ai_reason(${prompt.substring(0, 20)}...)');
          final dio = DioFactory.instance;
          final response = await dio.post(
            '$_bailianBaseUrl/v1/chat/completions',
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_cachedApiKey',
              },
            ),
            data: jsonEncode({
              'model': _bailianModel,
              'messages': [
                {'role': 'system', 'content': systemPrompt ?? ''},
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.3,
              'max_tokens': 200,
            }),
          );
          return response.data['choices'][0]['message']['content'] as String;
        }),
      );

      final planGenerator = PlanGenerator(registry);
      final reactPrompt = planGenerator.buildReactSystemPrompt();

      final dio = DioFactory.instance;

      final observation = planGenerator.buildReactObservation(
        '帮我搜索"深度学习"的笔记，如果没有就创建一个',
        [],
        0,
        3,
      );

      final response = await dio.post(
        '$_bailianBaseUrl/v1/chat/completions',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_cachedApiKey',
          },
        ),
        data: jsonEncode({
          'model': _bailianModel,
          'messages': [
            {'role': 'system', 'content': reactPrompt},
            {'role': 'user', 'content': observation},
          ],
          'temperature': 0.3,
        }),
      );

      final llmResponse =
          response.data['choices'][0]['message']['content'] as String;
      expect(llmResponse, isNotEmpty);
      print('ReAct 第1轮 AI 回复:\n$llmResponse');

      final action = planGenerator.parseReactResponse(llmResponse);
      expect(action, isNotNull, reason: 'AI 应返回有效的 JSON 动作');

      if (action != null) {
        final toolName = action['tool'] as String?;
        expect(toolName, isNotNull);
        expect(toolName, isNot(equals('final_answer')), reason: '第一轮不应直接结束');

        if (toolName != null && registry.hasTool(toolName)) {
          final args = (action['args'] as Map<String, dynamic>?) ?? {};
          final result = await registry.execute(toolName, args);
          expect(result.success, isTrue);
          print('工具执行结果: ${result.output}');

          final observation2 = planGenerator.buildReactObservation(
            '帮我搜索"深度学习"的笔记，如果没有就创建一个',
            [result.output],
            1,
            3,
          );

          final response2 = await dio.post(
            '$_bailianBaseUrl/v1/chat/completions',
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_cachedApiKey',
              },
            ),
            data: jsonEncode({
              'model': _bailianModel,
              'messages': [
                {'role': 'system', 'content': reactPrompt},
                {'role': 'user', 'content': observation2},
              ],
              'temperature': 0.3,
            }),
          );

          final llmResponse2 =
              response2.data['choices'][0]['message']['content'] as String;
          print('ReAct 第2轮 AI 回复:\n$llmResponse2');

          final action2 = planGenerator.parseReactResponse(llmResponse2);
          expect(action2, isNotNull);
        }
      }

      print('执行日志: $executionLog');
    }, skip: _cachedApiKey == null ? _skipReason : null);
  });
}

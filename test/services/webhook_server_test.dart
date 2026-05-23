// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rfbrowser/services/agent/agent_tool_registry.dart';
import 'package:rfbrowser/services/agent/builtin_tools.dart';
import 'package:rfbrowser/services/agent_service.dart';
import 'package:rfbrowser/services/webhook_server.dart';

class _MockAgentNotifier extends AgentNotifier {
  final AgentState _state;
  _MockAgentNotifier(this._state);
  @override
  AgentState build() => _state;
  @override
  set state(AgentState newState) => super.state = newState;
}

void main() {
  group('WebhookServerState', () {
    test('默认值', () {
      final state = WebhookServerState();
      expect(state.isRunning, false);
      expect(state.port, 18765);
      expect(state.apiKey, isNull);
      expect(state.baseUrl, isNull);
      expect(state.server, isNull);
    });

    test('copyWith', () {
      final state = WebhookServerState();
      final updated = state.copyWith(
        isRunning: true,
        port: 9999,
        apiKey: 'test',
        baseUrl: 'http://localhost:9999',
      );
      expect(updated.isRunning, true);
      expect(updated.port, 9999);
      expect(updated.apiKey, 'test');
      expect(updated.baseUrl, 'http://localhost:9999');
      expect(state.isRunning, false);
    });

    test('copyWith 不传参保持原值', () {
      final state = WebhookServerState(
        isRunning: true,
        port: 8080,
        apiKey: 'key123',
        baseUrl: 'http://localhost:8080',
      );
      final updated = state.copyWith();
      expect(updated.isRunning, true);
      expect(updated.port, 8080);
      expect(updated.apiKey, 'key123');
      expect(updated.baseUrl, 'http://localhost:8080');
    });
  });

  group('WebhookServer 单元测试', () {
    test('默认 API Key 以 rfb_ 开头', () {
      final container = ProviderContainer();
      final server = WebhookServer(ref: _createTestRef(container), port: 19876);
      expect(server.apiKey, startsWith('rfb_'));
      container.dispose();
    });

    test('自定义 API Key', () {
      final container = ProviderContainer();
      final server = WebhookServer(
        ref: _createTestRef(container),
        apiKey: 'custom_key',
        port: 19876,
      );
      expect(server.apiKey, 'custom_key');
      container.dispose();
    });

    test('setApiKey 更新 API Key', () {
      final container = ProviderContainer();
      final server = WebhookServer(
        ref: _createTestRef(container),
        apiKey: 'original',
        port: 19876,
      );
      expect(server.apiKey, 'original');
      server.setApiKey('updated');
      expect(server.apiKey, 'updated');
      container.dispose();
    });

    test('baseUrl 根据端口生成', () {
      final container = ProviderContainer();
      final server = WebhookServer(ref: _createTestRef(container), port: 9999);
      expect(server.baseUrl, 'http://localhost:9999');
      container.dispose();
    });

    test('初始状态 isRunning 为 false', () {
      final container = ProviderContainer();
      final server = WebhookServer(ref: _createTestRef(container), port: 19877);
      expect(server.isRunning, false);
      container.dispose();
    });

    test('重复启动不会报错', () async {
      final container = ProviderContainer(
        overrides: [
          agentProvider.overrideWith(() => _MockAgentNotifier(AgentState())),
        ],
      );
      final server = WebhookServer(
        ref: _createTestRef(container),
        apiKey: 'test',
        port: 19878,
      );
      await server.start();
      expect(server.isRunning, true);
      await server.start();
      expect(server.isRunning, true);
      await server.stop();
      container.dispose();
    });

    test('stop 在未启动时不报错', () async {
      final container = ProviderContainer();
      final server = WebhookServer(ref: _createTestRef(container), port: 19879);
      await server.stop();
      expect(server.isRunning, false);
      container.dispose();
    });
  });

  group('WebhookServer HTTP 集成测试', () {
    late WebhookServer server;
    late ProviderContainer container;

    setUp(() async {
      final registry = AgentToolRegistry();
      registry.register(
        CreateNoteTool((title, content) async => 'Created: $title'),
      );
      registry.register(SearchNotesTool((query) async => []));

      final agentState = AgentState(toolRegistry: registry);

      container = ProviderContainer(
        overrides: [
          agentProvider.overrideWith(() => _MockAgentNotifier(agentState)),
        ],
      );

      server = WebhookServer(
        ref: _createTestRef(container),
        apiKey: 'test_key_123',
        port: 19876,
      );
      await server.start();
    });

    tearDown(() async {
      await server.stop();
      container.dispose();
    });

    test('GET /api/status — 返回服务状态', () async {
      final response = await _httpGet('/api/status', 'test_key_123');
      expect(response.statusCode, 200);
      final body = await _readBody(response);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], 'ok');
      expect(json['version'], isNotNull);
      expect(json['tools'], isA<int>());
    });

    test('GET /api/status — 无认证返回 403', () async {
      final response = await _httpGet('/api/status', null);
      expect(response.statusCode, 403);
      final body = await _readBody(response);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['error'], 'Unauthorized');
    });

    test('GET /api/status — 错误 Key 返回 403', () async {
      final response = await _httpGet('/api/status', 'wrong_key');
      expect(response.statusCode, 403);
    });

    test('OPTIONS 请求返回 CORS 头', () async {
      final client = HttpClient();
      try {
        final request = await client.openUrl(
          'OPTIONS',
          Uri.parse('http://localhost:19876/api/status'),
        );
        final response = await request.close();
        expect(response.statusCode, 200);
        expect(response.headers.value('Access-Control-Allow-Origin'), '*');
        expect(
          response.headers.value('Access-Control-Allow-Methods'),
          isNotNull,
        );
      } finally {
        client.close();
      }
    });

    test('GET /api/tools — 返回工具列表', () async {
      final response = await _httpGet('/api/tools', 'test_key_123');
      expect(response.statusCode, 200);
      final body = await _readBody(response);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['tools'], isA<List>());
      expect((json['tools'] as List).length, greaterThanOrEqualTo(2));
    });

    test('GET /api/agent/tasks — 返回任务列表', () async {
      final response = await _httpGet('/api/agent/tasks', 'test_key_123');
      expect(response.statusCode, 200);
      final body = await _readBody(response);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['tasks'], isA<List>());
    });

    test('POST /api/agent/plan — 缺少 goal 返回错误', () async {
      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse('http://localhost:19876/api/agent/plan'),
        );
        request.headers.set('Authorization', 'Bearer test_key_123');
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({}));
        final response = await request.close();
        final body = await _readBody(response);
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['error'], contains('goal'));
      } finally {
        client.close();
      }
    });
  });
}

final _testRefProvider = Provider<Ref>((ref) => ref);

Ref _createTestRef(ProviderContainer container) {
  return container.read(_testRefProvider);
}

Future<HttpClientResponse> _httpGet(String path, String? apiKey) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://localhost:19876$path'),
    );
    if (apiKey != null) {
      request.headers.set('Authorization', 'Bearer $apiKey');
    }
    return await request.close();
  } finally {
    // client.close() would abort the response, so we don't close here
  }
}

Future<String> _readBody(HttpClientResponse response) {
  return response.transform(utf8.decoder).join();
}

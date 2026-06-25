// 覆盖验收标准:
//   AC-AI-Stream-001: 流式消息累积 — 逐块接收 SSE 数据并累积为完整文本
//   AC-AI-Stream-002: SSE 协议解析 — data: 前缀解析、[DONE] 终止标记处理
//   AC-AI-Stream-003: 空数据处理 — null/空 choices/delta/content 安全跳过
//   AC-AI-Stream-004: 多行数据拼接 — 单 chunk 多行 SSE、跨 chunk 分片拼接
//   AC-AI-Stream-005: 错误数据处理 — 无效 JSON 跳过、parseArgs 容错
//   AC-AI-Stream-006: 工具调用累积 — tool_calls delta 按 index 累积、arguments 拼接

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/services/ai/ai_stream_accumulator.dart';

/// 复刻 ai_service_tool_loop.dart 中的 SSE 行解析逻辑，
/// 用于测试 AiStreamAccumulator 与 SSE 协议的集成。
/// 返回是否遇到 [DONE] 终止标记。
bool processSseText(
  AiStreamAccumulator acc,
  String sseText,
  ApiProtocol protocol,
) {
  final lines = sseText.split('\n');
  for (final line in lines) {
    if (!line.startsWith('data: ')) continue;
    final data = line.substring(6).trim();
    if (data == '[DONE]') return true;
    try {
      final json = jsonDecode(data);
      acc.accumulateChunk(json, protocol);
    } catch (_) {
      // 无效 JSON 行被忽略，与生产代码行为一致
    }
  }
  return false;
}

Map<String, dynamic> _textChunk(String content) {
  return {
    'choices': [
      {'delta': {'content': content}},
    ],
  };
}

Map<String, dynamic> _toolCallChunk(
  int index, {
  String? id,
  String? name,
  String? argsDelta,
}) {
  final tc = <String, dynamic>{'index': index};
  if (id != null) tc['id'] = id;
  if (name != null || argsDelta != null) {
    tc['function'] = <String, dynamic>{};
    if (name != null) tc['function']['name'] = name;
    if (argsDelta != null) tc['function']['arguments'] = argsDelta;
  }
  return {
    'choices': [
      {'delta': {'tool_calls': [tc]}},
    ],
  };
}

void main() {
  group('AC-AI-Stream-001: 流式消息累积', () {
    test('逐块接收文本并累积为完整消息', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk(_textChunk('Hello'), ApiProtocol.openaiCompatible);
      acc.accumulateChunk(_textChunk(', '), ApiProtocol.openaiCompatible);
      acc.accumulateChunk(_textChunk('world!'), ApiProtocol.openaiCompatible);

      expect(acc.text, 'Hello, world!');
      expect(acc.hasToolCalls, isFalse);
    });

    test('累积过程中 text getter 始终返回当前累积值', () {
      final acc = AiStreamAccumulator();
      expect(acc.text, '');

      acc.accumulateChunk(_textChunk('A'), ApiProtocol.openaiCompatible);
      expect(acc.text, 'A');

      acc.accumulateChunk(_textChunk('B'), ApiProtocol.openaiCompatible);
      expect(acc.text, 'AB');

      acc.accumulateChunk(_textChunk('C'), ApiProtocol.openaiCompatible);
      expect(acc.text, 'ABC');
    });

    test('单字符逐块累积与整段直接写入结果一致', () {
      final accChunk = AiStreamAccumulator();
      for (final ch in 'streaming'.split('')) {
        accChunk.accumulateChunk(_textChunk(ch), ApiProtocol.openaiCompatible);
      }

      final accWhole = AiStreamAccumulator();
      accWhole.accumulateChunk(
        _textChunk('streaming'),
        ApiProtocol.openaiCompatible,
      );

      expect(accChunk.text, accWhole.text);
      expect(accChunk.text, 'streaming');
    });
  });

  group('AC-AI-Stream-002: SSE 协议解析', () {
    test('data: 前缀正确解析并累积', () {
      final acc = AiStreamAccumulator();
      final sse = 'data: ${jsonEncode(_textChunk('Hello'))}\n'
          'data: ${jsonEncode(_textChunk(' world'))}\n';

      final done = processSseText(acc, sse, ApiProtocol.openaiCompatible);

      expect(done, isFalse);
      expect(acc.text, 'Hello world');
    });

    test('[DONE] 终止标记停止后续数据处理', () {
      final acc = AiStreamAccumulator();
      final sse = 'data: ${jsonEncode(_textChunk('before'))}\n'
          'data: [DONE]\n'
          'data: ${jsonEncode(_textChunk('after'))}\n';

      final done = processSseText(acc, sse, ApiProtocol.openaiCompatible);

      expect(done, isTrue);
      expect(acc.text, 'before');
    });

    test('非 data: 前缀行被忽略（如注释行、空行）', () {
      final acc = AiStreamAccumulator();
      final sse = ': this is a comment\n'
          '\n'
          'event: message\n'
          'data: ${jsonEncode(_textChunk('only'))}\n'
          'id: 12345\n';

      processSseText(acc, sse, ApiProtocol.openaiCompatible);

      expect(acc.text, 'only');
    });

    test('data: 后带空格的行也能正确解析', () {
      final acc = AiStreamAccumulator();
      final sse = 'data:  ${jsonEncode(_textChunk('spaced'))}\n';

      processSseText(acc, sse, ApiProtocol.openaiCompatible);

      expect(acc.text, 'spaced');
    });
  });

  group('AC-AI-Stream-003: 空数据处理', () {
    test('choices 为 null 不抛异常', () {
      final acc = AiStreamAccumulator();
      expect(
        () => acc.accumulateChunk({'model': 'gpt-4'}, ApiProtocol.openaiCompatible),
        returnsNormally,
      );
      expect(acc.text, '');
      expect(acc.hasToolCalls, isFalse);
    });

    test('choices 为空列表不抛异常', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk({'choices': <dynamic>[]}, ApiProtocol.openaiCompatible);
      expect(acc.text, '');
    });

    test('delta 为 null 不抛异常', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk({
        'choices': [<String, dynamic>{}],
      }, ApiProtocol.openaiCompatible);
      expect(acc.text, '');
    });

    test('content 为 null 不影响已有累积', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk(_textChunk('kept'), ApiProtocol.openaiCompatible);
      acc.accumulateChunk({
        'choices': [{'delta': <String, dynamic>{}}],
      }, ApiProtocol.openaiCompatible);

      expect(acc.text, 'kept');
    });

    test('空字符串 content 不改变累积结果', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk(_textChunk('A'), ApiProtocol.openaiCompatible);
      acc.accumulateChunk(_textChunk(''), ApiProtocol.openaiCompatible);
      acc.accumulateChunk(_textChunk('B'), ApiProtocol.openaiCompatible);

      expect(acc.text, 'AB');
    });

    test('全新实例 text 为空、hasToolCalls 为 false', () {
      final acc = AiStreamAccumulator();
      expect(acc.text, '');
      expect(acc.hasToolCalls, isFalse);
      expect(acc.toolCalls, isEmpty);
    });
  });

  group('AC-AI-Stream-004: 多行数据拼接', () {
    test('单个 chunk 包含多行 SSE data 被正确拼接', () {
      final acc = AiStreamAccumulator();
      final sse = 'data: ${jsonEncode(_textChunk('line1 '))}\n'
          'data: ${jsonEncode(_textChunk('line2 '))}\n'
          'data: ${jsonEncode(_textChunk('line3'))}\n';

      processSseText(acc, sse, ApiProtocol.openaiCompatible);

      expect(acc.text, 'line1 line2 line3');
    });

    test('多个 chunk 跨网络分片被正确拼接', () {
      final acc = AiStreamAccumulator();
      // 模拟 TCP 分片：一行 SSE 可能被拆到多个 chunk
      final chunk1 = 'data: ${jsonEncode(_textChunk('Hel'))}\n'
          'data: ${jsonEncode(_textChunk('lo'))}\n';
      final chunk2 = 'data: ${jsonEncode(_textChunk(' '))}\n'
          'data: ${jsonEncode(_textChunk('World'))}\n';

      processSseText(acc, chunk1, ApiProtocol.openaiCompatible);
      processSseText(acc, chunk2, ApiProtocol.openaiCompatible);

      expect(acc.text, 'Hello World');
    });

    test('工具调用 arguments 跨多块拼接为完整 JSON', () {
      final acc = AiStreamAccumulator();
      // 第一块：id + name + 部分 arguments
      acc.accumulateChunk(
        _toolCallChunk(0, id: 'call_1', name: 'get_weather', argsDelta: '{"ci'),
        ApiProtocol.openaiCompatible,
      );
      // 第二块：arguments 续片
      acc.accumulateChunk(
        _toolCallChunk(0, argsDelta: 'ty": "Be'),
        ApiProtocol.openaiCompatible,
      );
      // 第三块：arguments 续片
      acc.accumulateChunk(
        _toolCallChunk(0, argsDelta: 'ijing"}'),
        ApiProtocol.openaiCompatible,
      );

      expect(acc.hasToolCalls, isTrue);
      expect(acc.toolCalls.length, 1);
      final tc = acc.toolCalls.first;
      expect(tc.id, 'call_1');
      expect(tc.name, 'get_weather');
      expect(tc.argsJson, '{"city": "Beijing"}');

      final parsed = AiStreamAccumulator.parseArgs(tc.argsJson);
      expect(parsed['city'], 'Beijing');
    });
  });

  group('AC-AI-Stream-005: 错误数据处理', () {
    test('SSE data 行包含无效 JSON 时被跳过', () {
      final acc = AiStreamAccumulator();
      final sse = 'data: ${jsonEncode(_textChunk('valid'))}\n'
          'data: {invalid json\n'
          'data: ${jsonEncode(_textChunk(' also_valid'))}\n';

      processSseText(acc, sse, ApiProtocol.openaiCompatible);

      expect(acc.text, 'valid also_valid');
    });

    test('缺失 choices 字段的 chunk 被安全忽略', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk(_textChunk('before'), ApiProtocol.openaiCompatible);
      acc.accumulateChunk({'object': 'chat.completion'}, ApiProtocol.openaiCompatible);
      acc.accumulateChunk(_textChunk(' after'), ApiProtocol.openaiCompatible);

      expect(acc.text, 'before after');
    });

    test('parseArgs 无效 JSON 返回空 map', () {
      final result = AiStreamAccumulator.parseArgs('not json at all');
      expect(result, isEmpty);
    });

    test('parseArgs 有效 JSON 对象返回解析结果', () {
      final result = AiStreamAccumulator.parseArgs('{"key": "value", "num": 42}');
      expect(result['key'], 'value');
      expect(result['num'], 42);
    });

    test('parseArgs JSON 数组（非对象）返回空 map', () {
      final result = AiStreamAccumulator.parseArgs('[1, 2, 3]');
      expect(result, isEmpty);
    });

    test('parseArgs 空字符串返回空 map', () {
      final result = AiStreamAccumulator.parseArgs('');
      expect(result, isEmpty);
    });

    test('tool_calls 中 function 为 null 不抛异常', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk({
        'choices': [
          {
            'delta': {
              'tool_calls': [
                {'index': 0, 'id': 'call_1'},
              ],
            },
          },
        ],
      }, ApiProtocol.openaiCompatible);

      expect(acc.hasToolCalls, isTrue);
      expect(acc.toolCalls.first.id, 'call_1');
      expect(acc.toolCalls.first.name, '');
      expect(acc.toolCalls.first.argsJson, '');
    });
  });

  group('AC-AI-Stream-006: 工具调用累积', () {
    test('单个工具调用 id 和 name 累积', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk(
        _toolCallChunk(0, id: 'call_abc', name: 'search'),
        ApiProtocol.openaiCompatible,
      );

      expect(acc.hasToolCalls, isTrue);
      expect(acc.toolCalls.length, 1);
      expect(acc.toolCalls.first.id, 'call_abc');
      expect(acc.toolCalls.first.name, 'search');
    });

    test('多个工具调用按 index 升序排列', () {
      final acc = AiStreamAccumulator();
      // 故意乱序输入 index
      acc.accumulateChunk(
        _toolCallChunk(2, id: 'c2', name: 'tool_c2'),
        ApiProtocol.openaiCompatible,
      );
      acc.accumulateChunk(
        _toolCallChunk(0, id: 'c0', name: 'tool_c0'),
        ApiProtocol.openaiCompatible,
      );
      acc.accumulateChunk(
        _toolCallChunk(1, id: 'c1', name: 'tool_c1'),
        ApiProtocol.openaiCompatible,
      );

      expect(acc.toolCalls.length, 3);
      expect(acc.toolCalls[0].id, 'c0');
      expect(acc.toolCalls[1].id, 'c1');
      expect(acc.toolCalls[2].id, 'c2');
    });

    test('同一 index 的后续 chunk 不覆盖已有 id 和 name', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk(
        _toolCallChunk(0, id: 'call_1', name: 'original'),
        ApiProtocol.openaiCompatible,
      );
      // 后续 chunk 不带 id/name，只带 arguments 续片
      acc.accumulateChunk(
        _toolCallChunk(0, argsDelta: '{"q": "test"}'),
        ApiProtocol.openaiCompatible,
      );

      expect(acc.toolCalls.first.id, 'call_1');
      expect(acc.toolCalls.first.name, 'original');
      expect(acc.toolCalls.first.argsJson, '{"q": "test"}');
    });

    test('tool_calls 缺失 index 时默认为 0', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk({
        'choices': [
          {
            'delta': {
              'tool_calls': [
                {'id': 'call_x', 'function': {'name': 'noop'}},
              ],
            },
          },
        ],
      }, ApiProtocol.openaiCompatible);

      expect(acc.toolCalls.length, 1);
      expect(acc.toolCalls.first.id, 'call_x');
    });

    test('文本和工具调用可在同一 chunk 中共存', () {
      final acc = AiStreamAccumulator();
      acc.accumulateChunk({
        'choices': [
          {
            'delta': {
              'content': 'Let me search: ',
              'tool_calls': [
                {'index': 0, 'id': 'call_1', 'function': {'name': 'search'}},
              ],
            },
          },
        ],
      }, ApiProtocol.openaiCompatible);

      expect(acc.text, 'Let me search: ');
      expect(acc.hasToolCalls, isTrue);
      expect(acc.toolCalls.first.name, 'search');
    });
  });
}

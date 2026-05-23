import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/agent/plan_generator.dart';
import 'package:rfbrowser/services/agent/agent_tool_registry.dart';
import 'package:rfbrowser/services/agent/agent_tool.dart';

class _TestTool extends AgentTool {
  _TestTool({required super.name, required super.description})
    : super(parametersSchema: const {});

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async =>
      ToolResult.success('ok');
}

void main() {
  late AgentToolRegistry registry;
  late PlanGenerator generator;

  setUp(() {
    registry = AgentToolRegistry();
    registry.register(
      _TestTool(name: 'navigate', description: 'Navigate to URL'),
    );
    registry.register(
      _TestTool(name: 'extract_text', description: 'Extract text from page'),
    );
    registry.register(
      _TestTool(name: 'create_note', description: 'Create a note'),
    );
    registry.register(
      _TestTool(name: 'ai_reason', description: 'AI reasoning'),
    );
    registry.register(
      _TestTool(name: 'search_notes', description: 'Search notes'),
    );
    generator = PlanGenerator(registry);
  });

  group('PlanGenerator', () {
    test('buildSystemPrompt includes tool descriptions', () {
      final prompt = generator.buildSystemPrompt();
      expect(prompt, contains('navigate'));
      expect(prompt, contains('extract_text'));
      expect(prompt, contains('create_note'));
      expect(prompt, contains('ai_reason'));
      expect(prompt, contains('search_notes'));
    });

    test('buildReactSystemPrompt includes tool descriptions', () {
      final prompt = generator.buildReactSystemPrompt();
      expect(prompt, contains('navigate'));
      expect(prompt, contains('ReAct'));
    });

    test('parsePlan parses valid JSON', () {
      final json = '''{
        "steps": [
          {"tool": "navigate", "args": {"url": "https://example.com"}, "description": "Go to example"},
          {"tool": "extract_text", "args": {"url": "https://example.com"}, "description": "Get text"},
          {"tool": "ai_reason", "args": {"prompt": "Summarize"}}
        ]
      }''';
      final steps = generator.parsePlan(json);
      expect(steps.length, 3);
      expect(steps[0].toolName, 'navigate');
      expect(steps[0].args['url'], 'https://example.com');
      expect(steps[1].toolName, 'extract_text');
      expect(steps[2].toolName, 'ai_reason');
    });

    test('parsePlan handles markdown fences', () {
      final json =
          '```json\n{"steps": [{"tool": "navigate", "args": {"url": "test"}}]}\n```';
      final steps = generator.parsePlan(json);
      expect(steps.length, 1);
      expect(steps[0].toolName, 'navigate');
    });

    test('parsePlan returns empty list for invalid JSON', () {
      final steps = generator.parsePlan('not json at all');
      expect(steps, isEmpty);
    });

    test('parsePlan handles empty steps', () {
      final steps = generator.parsePlan('{"steps": []}');
      expect(steps, isEmpty);
    });

    test('parsePlan extracts retryCount and onFailure', () {
      final json = '''{
        "steps": [
          {"tool": "navigate", "args": {"url": "test"}, "retryCount": 3, "onFailure": "skip"}
        ]
      }''';
      final steps = generator.parsePlan(json);
      expect(steps[0].retryCount, 3);
      expect(steps[0].onFailure, 'skip');
    });

    test('parseReactResponse parses valid JSON', () {
      final json =
          '{"thought": "I should search", "tool": "search_notes", "args": {"query": "test"}, "done": false}';
      final result = generator.parseReactResponse(json);
      expect(result, isNotNull);
      expect(result!['thought'], 'I should search');
      expect(result['tool'], 'search_notes');
      expect(result['done'], false);
    });

    test('parseReactResponse handles markdown fences', () {
      final json =
          '```json\n{"thought": "done", "tool": "final_answer", "args": {"answer": "result"}, "done": true}\n```';
      final result = generator.parseReactResponse(json);
      expect(result, isNotNull);
      expect(result!['done'], true);
    });

    test('parseReactResponse returns null for invalid JSON', () {
      final result = generator.parseReactResponse('not json');
      expect(result, isNull);
    });

    test('resolveStepReferences replaces {{step_N}}', () {
      final args = {'prompt': 'Summarize: {{step_0}} and {{step_1}}'};
      final results = ['First result', 'Second result'];
      final resolved = generator.resolveStepReferences(args, results);
      expect(resolved, contains('First result'));
      expect(resolved, contains('Second result'));
      expect(resolved, isNot(contains('{{step_')));
    });

    test('resolveStepReferences handles missing references gracefully', () {
      final args = {'prompt': '{{step_5}}'};
      final results = ['Only one result'];
      final resolved = generator.resolveStepReferences(args, results);
      expect(resolved, contains('{{step_5}}'));
    });

    test('parseResolvedArgs parses valid JSON', () {
      final result = generator.parseResolvedArgs('{"key": "value"}');
      expect(result['key'], 'value');
    });

    test('parseResolvedArgs returns empty map for invalid JSON', () {
      final result = generator.parseResolvedArgs('not json');
      expect(result, isEmpty);
    });

    test('buildReactObservation includes goal and iteration', () {
      final obs = generator.buildReactObservation(
        'Research AI',
        ['Step 0 result'],
        1,
        10,
      );
      expect(obs, contains('Research AI'));
      expect(obs, contains('1 / 10'));
      expect(obs, contains('Step 0 result'));
    });

    test('buildReactObservation handles empty results', () {
      final obs = generator.buildReactObservation('Goal', [], 0, 5);
      expect(obs, contains('none yet'));
    });

    test('fallbackParse extracts tools from malformed JSON', () {
      final text =
          'Here is my plan: "tool": "navigate", "args": {"url": "test"} and "tool": "create_note", "args": {"title": "hi"}';
      final steps = generator.parsePlan(text);
      expect(steps.length, 2);
      expect(steps[0].toolName, 'navigate');
      expect(steps[1].toolName, 'create_note');
    });
  });
}

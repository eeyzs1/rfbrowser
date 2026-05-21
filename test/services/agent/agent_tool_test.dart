import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/agent/agent_tool.dart';
import 'package:rfbrowser/services/agent/agent_tool_registry.dart';
import 'package:rfbrowser/services/agent/builtin_tools.dart';

class _TestTool extends AgentTool {
  final Future<ToolResult> Function(Map<String, dynamic>) _fn;

  _TestTool({
    required super.name,
    required super.description,
    super.parametersSchema = const {},
    super.isDestructive = false,
    required Future<ToolResult> Function(Map<String, dynamic>) executeFn,
  }) : _fn = executeFn;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) => _fn(args);
}

void main() {
  group('ToolResult', () {
    test('success factory creates success result', () {
      final result = ToolResult.success('ok');
      expect(result.success, true);
      expect(result.output, 'ok');
      expect(result.error, isNull);
    });

    test('failure factory creates failure result', () {
      final result = ToolResult.failure('bad');
      expect(result.success, false);
      expect(result.output, '');
      expect(result.error, 'bad');
    });

    test('toJson includes metadata', () {
      final result = ToolResult.success('ok', metadata: {'count': 5});
      final json = result.toJson();
      expect(json['success'], true);
      expect(json['metadata']['count'], 5);
    });
  });

  group('AgentTool', () {
    test('toToolDefinition returns correct map', () {
      final tool = _TestTool(
        name: 'test',
        description: 'A test tool',
        executeFn: (_) async => ToolResult.success('ok'),
      );
      final def = tool.toToolDefinition();
      expect(def['name'], 'test');
      expect(def['description'], 'A test tool');
      expect(def['isDestructive'], false);
      expect(def['source'], 'builtin');
    });

    test('toPromptDescription includes name and description', () {
      final tool = _TestTool(
        name: 'search',
        description: 'Search for things',
        executeFn: (_) async => ToolResult.success('ok'),
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': 'Search query'}
          },
          'required': ['query'],
        },
      );
      final desc = tool.toPromptDescription();
      expect(desc, contains('search'));
      expect(desc, contains('Search for things'));
      expect(desc, contains('query'));
    });

    test('destructive tool marks in prompt', () {
      final tool = _TestTool(
        name: 'delete',
        description: 'Delete things',
        isDestructive: true,
        executeFn: (_) async => ToolResult.success('ok'),
      );
      final desc = tool.toPromptDescription();
      expect(desc, contains('⚠️'));
    });
  });

  group('AgentToolRegistry', () {
    late AgentToolRegistry registry;

    setUp(() {
      registry = AgentToolRegistry();
    });

    test('register and retrieve tool', () {
      final tool = _TestTool(
        name: 'test',
        description: 'Test',
        executeFn: (_) async => ToolResult.success('ok'),
      );
      registry.register(tool);
      expect(registry.hasTool('test'), true);
      expect(registry.getTool('test'), tool);
    });

    test('unregister removes tool', () {
      final tool = _TestTool(
        name: 'test',
        description: 'Test',
        executeFn: (_) async => ToolResult.success('ok'),
      );
      registry.register(tool);
      registry.unregister('test');
      expect(registry.hasTool('test'), false);
      expect(registry.getTool('test'), isNull);
    });

    test('execute calls tool and returns result', () async {
      final tool = _TestTool(
        name: 'echo',
        description: 'Echo',
        executeFn: (args) async => ToolResult.success(args['msg'] as String? ?? ''),
      );
      registry.register(tool);
      final result = await registry.execute('echo', {'msg': 'hello'});
      expect(result.success, true);
      expect(result.output, 'hello');
    });

    test('execute returns failure for unknown tool', () async {
      final result = await registry.execute('unknown', {});
      expect(result.success, false);
      expect(result.error, contains('Unknown tool'));
    });

    test('allToolDefinitions returns all tools', () {
      registry.register(_TestTool(
        name: 'a',
        description: 'A',
        executeFn: (_) async => ToolResult.success(''),
      ));
      registry.register(_TestTool(
        name: 'b',
        description: 'B',
        executeFn: (_) async => ToolResult.success(''),
      ));
      final defs = registry.allToolDefinitions();
      expect(defs.length, 2);
      expect(defs.any((d) => d['name'] == 'a'), true);
      expect(defs.any((d) => d['name'] == 'b'), true);
    });

    test('toolsPrompt includes all tool descriptions', () {
      registry.register(_TestTool(
        name: 'alpha',
        description: 'Alpha tool',
        executeFn: (_) async => ToolResult.success(''),
      ));
      final prompt = registry.toolsPrompt();
      expect(prompt, contains('alpha'));
      expect(prompt, contains('Alpha tool'));
    });

    test('clear removes all tools', () {
      registry.register(_TestTool(
        name: 'a',
        description: 'A',
        executeFn: (_) async => ToolResult.success(''),
      ));
      registry.clear();
      expect(registry.allTools, isEmpty);
    });
  });

  group('BuiltinTools', () {
    test('NavigateTool requires url', () async {
      final tool = NavigateTool((url) async => 'Navigated to $url');
      final result = await tool.execute({});
      expect(result.success, false);
    });

    test('NavigateTool succeeds with url', () async {
      final tool = NavigateTool((url) async => 'Navigated to $url');
      final result = await tool.execute({'url': 'https://example.com'});
      expect(result.success, true);
      expect(result.output, contains('example.com'));
    });

    test('ExtractTextTool requires url', () async {
      final tool = ExtractTextTool((url) async => 'Text from $url');
      final result = await tool.execute({});
      expect(result.success, false);
    });

    test('CreateNoteTool requires title', () async {
      final tool = CreateNoteTool((title, content) async => 'Created: $title');
      final result = await tool.execute({});
      expect(result.success, false);
    });

    test('CreateNoteTool uses default empty content', () async {
      var capturedContent = 'not called';
      final tool = CreateNoteTool((title, content) async {
        capturedContent = content;
        return 'Created: $title';
      });
      final result = await tool.execute({'title': 'Test'});
      expect(result.success, true);
      expect(capturedContent, '');
    });

    test('SearchNotesTool requires query', () async {
      final tool = SearchNotesTool((query) async => []);
      final result = await tool.execute({});
      expect(result.success, false);
    });

    test('SearchNotesTool returns formatted results', () async {
      final tool = SearchNotesTool((query) async => [
        {'title': 'Note 1', 'score': 0.9},
        {'title': 'Note 2', 'score': 0.7},
      ]);
      final result = await tool.execute({'query': 'test'});
      expect(result.success, true);
      expect(result.output, contains('Note 1'));
      expect(result.metadata['count'], 2);
    });

    test('AIReasonTool requires prompt', () async {
      final tool = AIReasonTool((prompt, sys) async => 'response');
      final result = await tool.execute({});
      expect(result.success, false);
    });

    test('WebClipTool defaults to markdown format', () async {
      var capturedFormat = '';
      final tool = WebClipTool((url, format) async {
        capturedFormat = format;
        return 'Clipped $url as $format';
      });
      final result = await tool.execute({'url': 'https://example.com'});
      expect(result.success, true);
      expect(capturedFormat, 'markdown');
    });

    test('DeleteNoteTool is destructive', () {
      final tool = DeleteNoteTool((title) async => true);
      expect(tool.isDestructive, true);
    });
  });
}

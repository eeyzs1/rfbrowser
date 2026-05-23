import 'package:flutter_test/flutter_test.dart';

import 'package:rfbrowser/services/agent/agent_tool_registry.dart';
import 'package:rfbrowser/services/agent/builtin_tools.dart';

void main() {
  group('UpdateNoteTool', () {
    late UpdateNoteTool tool;

    setUp(() {
      tool = UpdateNoteTool((title, content) async => 'Updated: $title');
    });

    test('名称和描述', () {
      expect(tool.name, 'update_note');
      expect(tool.isDestructive, false);
    });

    test('成功更新笔记', () async {
      final result = await tool.execute({'title': '测试笔记', 'content': '新内容'});
      expect(result.success, true);
      expect(result.output, contains('测试笔记'));
    });

    test('缺少 title 返回失败', () async {
      final result = await tool.execute({'content': '内容'});
      expect(result.success, false);
      expect(result.error, contains('title'));
    });

    test('缺少 content 返回失败', () async {
      final result = await tool.execute({'title': '笔记'});
      expect(result.success, false);
      expect(result.error, contains('content'));
    });
  });

  group('ListNotesTool', () {
    late ListNotesTool tool;

    setUp(() {
      tool = ListNotesTool((tag, limit) async {
        return 'Found 2 notes:\n- Note1\n- Note2';
      });
    });

    test('名称和描述', () {
      expect(tool.name, 'list_notes');
      expect(tool.isDestructive, false);
    });

    test('列出所有笔记', () async {
      final result = await tool.execute({});
      expect(result.success, true);
      expect(result.output, contains('Note1'));
    });

    test('按标签过滤', () async {
      final result = await tool.execute({'tag': '重要', 'limit': 5});
      expect(result.success, true);
    });

    test('默认 limit 为 20', () async {
      var capturedLimit = 0;
      final localTool = ListNotesTool((tag, limit) async {
        capturedLimit = limit;
        return '';
      });
      await localTool.execute({});
      expect(capturedLimit, 20);
    });
  });

  group('GetTagsTool', () {
    late GetTagsTool tool;

    setUp(() {
      tool = GetTagsTool(() async => '量子计算, 深度学习, AI');
    });

    test('名称和描述', () {
      expect(tool.name, 'get_tags');
      expect(tool.isDestructive, false);
    });

    test('返回所有标签', () async {
      final result = await tool.execute({});
      expect(result.success, true);
      expect(result.output, contains('量子计算'));
      expect(result.output, contains('深度学习'));
    });
  });

  group('MoveNoteTool', () {
    late MoveNoteTool tool;

    setUp(() {
      tool = MoveNoteTool((title, folder) async => 'Moved "$title" to $folder');
    });

    test('名称和描述', () {
      expect(tool.name, 'move_note');
      expect(tool.isDestructive, false);
    });

    test('成功移动笔记', () async {
      final result = await tool.execute({
        'title': '测试笔记',
        'folder': 'projects',
      });
      expect(result.success, true);
      expect(result.output, contains('projects'));
    });

    test('缺少 title 返回失败', () async {
      final result = await tool.execute({'folder': 'projects'});
      expect(result.success, false);
      expect(result.error, contains('title'));
    });

    test('缺少 folder 返回失败', () async {
      final result = await tool.execute({'title': '笔记'});
      expect(result.success, false);
      expect(result.error, contains('folder'));
    });
  });

  group('RenameNoteTool', () {
    late RenameNoteTool tool;

    setUp(() {
      tool = RenameNoteTool(
        (oldTitle, newTitle) async => 'Renamed "$oldTitle" to "$newTitle"',
      );
    });

    test('名称和描述', () {
      expect(tool.name, 'rename_note');
      expect(tool.isDestructive, false);
    });

    test('成功重命名笔记', () async {
      final result = await tool.execute({
        'old_title': '旧名称',
        'new_title': '新名称',
      });
      expect(result.success, true);
      expect(result.output, contains('旧名称'));
      expect(result.output, contains('新名称'));
    });

    test('缺少 old_title 返回失败', () async {
      final result = await tool.execute({'new_title': '新名称'});
      expect(result.success, false);
      expect(result.error, contains('old_title'));
    });

    test('缺少 new_title 返回失败', () async {
      final result = await tool.execute({'old_title': '旧名称'});
      expect(result.success, false);
      expect(result.error, contains('new_title'));
    });
  });

  group('5 个新工具在 Registry 中的集成', () {
    test('全部注册后可查询和执行', () async {
      final registry = AgentToolRegistry();

      registry.register(UpdateNoteTool((t, c) async => 'ok'));
      registry.register(ListNotesTool((t, l) async => 'list'));
      registry.register(GetTagsTool(() async => 'tags'));
      registry.register(MoveNoteTool((t, f) async => 'moved'));
      registry.register(RenameNoteTool((o, n) async => 'renamed'));

      expect(registry.hasTool('update_note'), true);
      expect(registry.hasTool('list_notes'), true);
      expect(registry.hasTool('get_tags'), true);
      expect(registry.hasTool('move_note'), true);
      expect(registry.hasTool('rename_note'), true);

      final updateResult = await registry.execute('update_note', {
        'title': 'test',
        'content': 'content',
      });
      expect(updateResult.success, true);

      final moveResult = await registry.execute('move_note', {
        'title': 'test',
        'folder': 'new-folder',
      });
      expect(moveResult.success, true);

      final renameResult = await registry.execute('rename_note', {
        'old_title': 'old',
        'new_title': 'new',
      });
      expect(renameResult.success, true);
    });

    test('allToolDefinitions 包含所有 5 个新工具', () {
      final registry = AgentToolRegistry();
      registry.register(UpdateNoteTool((t, c) async => 'ok'));
      registry.register(ListNotesTool((t, l) async => 'list'));
      registry.register(GetTagsTool(() async => 'tags'));
      registry.register(MoveNoteTool((t, f) async => 'moved'));
      registry.register(RenameNoteTool((o, n) async => 'renamed'));

      final definitions = registry.allToolDefinitions();
      final names = definitions.map((d) => d['name'] as String).toList();
      expect(
        names,
        containsAll([
          'update_note',
          'list_notes',
          'get_tags',
          'move_note',
          'rename_note',
        ]),
      );
    });

    test('toolsPrompt 包含所有 5 个新工具描述', () {
      final registry = AgentToolRegistry();
      registry.register(UpdateNoteTool((t, c) async => 'ok'));
      registry.register(ListNotesTool((t, l) async => 'list'));
      registry.register(GetTagsTool(() async => 'tags'));
      registry.register(MoveNoteTool((t, f) async => 'moved'));
      registry.register(RenameNoteTool((o, n) async => 'renamed'));

      final prompt = registry.toolsPrompt();
      expect(prompt, contains('update_note'));
      expect(prompt, contains('list_notes'));
      expect(prompt, contains('get_tags'));
      expect(prompt, contains('move_note'));
      expect(prompt, contains('rename_note'));
    });
  });
}

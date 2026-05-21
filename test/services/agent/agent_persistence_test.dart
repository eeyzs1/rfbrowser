import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/services/agent/agent_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentPersistence', () {
    late AgentPersistence persistence;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('agent_persistence_test_');
      persistence = AgentPersistence(basePath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loadTasks — 文件不存在时返回空列表', () async {
      final tasks = await persistence.loadTasks();
      expect(tasks, isEmpty);
    });

    test('saveTasks + loadTasks 往返', () async {
      final originalTasks = [
        AgentTask(
          id: 'task-001',
          name: '测试任务1',
          description: '描述1',
          mode: TaskMode.manual,
          steps: [
            AgentStep(
              description: '步骤1',
              toolName: 'search_notes',
              args: {'query': 'test'},
              status: TaskStatus.completed,
              result: '搜索完成',
              completedAt: DateTime(2026, 1, 1),
            ),
            AgentStep(
              description: '步骤2',
              toolName: 'create_note',
              args: {'title': '新笔记', 'content': '内容'},
              status: TaskStatus.pending,
            ),
          ],
          status: TaskStatus.running,
          created: DateTime(2026, 1, 1),
        ),
        AgentTask(
          id: 'task-002',
          name: '测试任务2',
          description: '描述2',
          mode: TaskMode.reactLoop,
          status: TaskStatus.completed,
          result: '任务完成',
          completed: DateTime(2026, 1, 2),
          created: DateTime(2026, 1, 1),
        ),
      ];

      await persistence.saveTasks(originalTasks);
      final loadedTasks = await persistence.loadTasks();

      expect(loadedTasks.length, 2);

      expect(loadedTasks[0].id, 'task-001');
      expect(loadedTasks[0].name, '测试任务1');
      expect(loadedTasks[0].mode, TaskMode.manual);
      expect(loadedTasks[0].steps.length, 2);
      expect(loadedTasks[0].steps[0].toolName, 'search_notes');
      expect(loadedTasks[0].steps[0].status, TaskStatus.completed);
      expect(loadedTasks[0].steps[1].status, TaskStatus.pending);
      expect(loadedTasks[0].status, TaskStatus.running);

      expect(loadedTasks[1].id, 'task-002');
      expect(loadedTasks[1].mode, TaskMode.reactLoop);
      expect(loadedTasks[1].status, TaskStatus.completed);
      expect(loadedTasks[1].result, '任务完成');
    });

    test('saveTasks — 空列表', () async {
      await persistence.saveTasks([]);
      final loaded = await persistence.loadTasks();
      expect(loaded, isEmpty);
    });

    test('clearTasks — 删除持久化文件', () async {
      await persistence.saveTasks([
        AgentTask(
          id: 'task-003',
          name: '临时任务',
          description: '临时',
          mode: TaskMode.aiPlanned,
          status: TaskStatus.pending,
          created: DateTime.now(),
        ),
      ]);

      var loaded = await persistence.loadTasks();
      expect(loaded, isNotEmpty);

      await persistence.clearTasks();
      loaded = await persistence.loadTasks();
      expect(loaded, isEmpty);
    });

    test('saveTasks — 覆盖写入', () async {
      await persistence.saveTasks([
        AgentTask(
          id: 'old-task',
          name: '旧任务',
          description: '旧',
          mode: TaskMode.manual,
          status: TaskStatus.completed,
          created: DateTime(2025, 1, 1),
        ),
      ]);

      await persistence.saveTasks([
        AgentTask(
          id: 'new-task',
          name: '新任务',
          description: '新',
          mode: TaskMode.reactLoop,
          status: TaskStatus.running,
          created: DateTime(2026, 1, 1),
        ),
      ]);

      final loaded = await persistence.loadTasks();
      expect(loaded.length, 1);
      expect(loaded[0].id, 'new-task');
      expect(loaded[0].mode, TaskMode.reactLoop);
    });

    test('loadTasks — 畸形 JSON 返回空列表', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}agent_tasks.json');
      await file.writeAsString('not valid json {{{');

      final tasks = await persistence.loadTasks();
      expect(tasks, isEmpty);
    });

    test('loadTasks — JSON 数组包含无效元素', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}agent_tasks.json');
      await file.writeAsString(
          '[{"id": "valid", "name": "ok", "description": "", "mode": "manual", "status": "pending", "steps": [], "created": "2026-01-01T00:00:00.000"}, 123, "string"]');

      final tasks = await persistence.loadTasks();
      expect(tasks.length, greaterThanOrEqualTo(1));
      if (tasks.isNotEmpty) {
        expect(tasks[0].id, 'valid');
      }
    });
  });
}

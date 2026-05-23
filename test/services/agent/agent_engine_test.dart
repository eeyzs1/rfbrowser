import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/services/agent/agent_tool.dart';
import 'package:rfbrowser/services/agent/agent_tool_registry.dart';
import 'package:rfbrowser/services/agent_service.dart';

class _FailingTool extends AgentTool {
  _FailingTool()
    : super(
        name: 'failing_tool',
        description: 'Always fails',
        parametersSchema: const {},
      );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    return ToolResult.failure('Intentional failure');
  }
}

class _SlowTool extends AgentTool {
  _SlowTool()
    : super(
        name: 'slow_tool',
        description: 'Takes time',
        parametersSchema: const {},
      );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return ToolResult.success('Slow result');
  }
}

class _EchoTool extends AgentTool {
  _EchoTool()
    : super(
        name: 'echo_tool',
        description: 'Echoes input',
        parametersSchema: const {
          'properties': {
            'message': {'type': 'string', 'description': 'Message to echo'},
          },
          'required': ['message'],
        },
      );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    return ToolResult.success('Echo: ${args['message']}');
  }
}

class _MockAgentNotifier extends AgentNotifier {
  final AgentState _state;
  _MockAgentNotifier(this._state);
  @override
  AgentState build() => _state;
  @override
  set state(AgentState newState) => super.state = newState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentNotifier 执行引擎', () {
    late ProviderContainer container;
    late AgentNotifier agent;
    late AgentToolRegistry registry;

    setUp(() {
      registry = AgentToolRegistry();
      registry.register(_EchoTool());

      final agentState = AgentState(toolRegistry: registry);

      container = ProviderContainer(
        overrides: [
          agentProvider.overrideWith(() => _MockAgentNotifier(agentState)),
        ],
      );
      agent = container.read(agentProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('_executeManualTask', () {
      test('手动模式 — 按顺序执行所有步骤', () async {
        final task = AgentTask(
          id: 'manual-001',
          name: '手动测试',
          description: '测试手动模式',
          mode: TaskMode.manual,
          steps: [
            AgentStep(
              description: '回显消息1',
              toolName: 'echo_tool',
              args: {'message': 'hello'},
            ),
            AgentStep(
              description: '回显消息2',
              toolName: 'echo_tool',
              args: {'message': 'world'},
            ),
          ],
          status: TaskStatus.pending,
          created: DateTime.now(),
        );

        final result = await agent.executeTask(task);
        expect(result.status, TaskStatus.completed);
        expect(result.steps.length, 2);
        expect(result.steps[0].status, TaskStatus.completed);
        expect(result.steps[0].result, contains('hello'));
        expect(result.steps[1].status, TaskStatus.completed);
        expect(result.steps[1].result, contains('world'));
      });

      test('手动模式 — 步骤失败时任务失败', () async {
        registry.register(_FailingTool());

        final task = AgentTask(
          id: 'manual-fail-001',
          name: '失败测试',
          description: '测试失败步骤',
          mode: TaskMode.manual,
          steps: [
            AgentStep(
              description: '会失败的步骤',
              toolName: 'failing_tool',
              args: {},
            ),
          ],
          status: TaskStatus.pending,
          created: DateTime.now(),
        );

        final result = await agent.executeTask(task);
        expect(result.status, TaskStatus.failed);
        expect(result.steps[0].status, TaskStatus.failed);
      });

      test('手动模式 — 无步骤直接完成', () async {
        final task = AgentTask(
          id: 'manual-empty-001',
          name: '空步骤',
          description: '无步骤任务',
          mode: TaskMode.manual,
          steps: [],
          status: TaskStatus.pending,
          created: DateTime.now(),
        );

        final result = await agent.executeTask(task);
        expect(result.status, TaskStatus.completed);
      });

      test('手动模式 — 失败步骤 onFailure=skip 跳过继续', () async {
        registry.register(_FailingTool());

        final task = AgentTask(
          id: 'manual-skip-001',
          name: '跳过失败测试',
          description: '测试跳过失败步骤',
          mode: TaskMode.manual,
          steps: [
            AgentStep(
              description: '会失败但跳过',
              toolName: 'failing_tool',
              args: {},
              onFailure: 'skip',
            ),
            AgentStep(
              description: '回显消息',
              toolName: 'echo_tool',
              args: {'message': 'after_skip'},
            ),
          ],
          status: TaskStatus.pending,
          created: DateTime.now(),
        );

        final result = await agent.executeTask(task);
        expect(result.status, TaskStatus.completed);
        expect(result.steps[0].status, TaskStatus.completed);
        expect(result.steps[0].result, contains('Error (skipped)'));
        expect(result.steps[1].status, TaskStatus.completed);
      });
    });

    group('任务生命周期', () {
      test('重复 ID 的任务不会重复添加', () async {
        final task = AgentTask(
          id: 'dup-001',
          name: '重复任务',
          description: '重复测试',
          mode: TaskMode.manual,
          steps: [],
          status: TaskStatus.pending,
          created: DateTime.now(),
        );

        await agent.executeTask(task);
        await agent.executeTask(task);

        final tasks = agent.state.tasks;
        expect(tasks.where((t) => t.id == 'dup-001').length, 1);
      });

      test('取消不存在的任务不报错', () {
        expect(() => agent.cancelTask('nonexistent'), returnsNormally);
      });

      test('移除任务', () async {
        final task = AgentTask(
          id: 'remove-001',
          name: '待删除',
          description: '删除测试',
          mode: TaskMode.manual,
          steps: [],
          status: TaskStatus.pending,
          created: DateTime.now(),
        );

        await agent.executeTask(task);
        expect(agent.state.tasks.any((t) => t.id == 'remove-001'), true);

        agent.removeTask('remove-001');
        expect(agent.state.tasks.any((t) => t.id == 'remove-001'), false);
      });
    });

    group('插件工具注册', () {
      test('注册和取消插件工具', () {
        final initialCount = agent.toolRegistry.tools.length;

        agent.registerPluginTool(_SlowTool());
        expect(agent.toolRegistry.tools.length, initialCount + 1);
        expect(agent.toolRegistry.hasTool('slow_tool'), true);

        agent.unregisterPluginTool('slow_tool');
        expect(agent.toolRegistry.tools.length, initialCount);
        expect(agent.toolRegistry.hasTool('slow_tool'), false);
      });
    });

    group('条件评估', () {
      test('条件 step_0.success — 前一步成功时通过', () async {
        final task = AgentTask(
          id: 'cond-success-001',
          name: '条件测试',
          description: '条件测试',
          mode: TaskMode.manual,
          steps: [
            AgentStep(
              description: '回显',
              toolName: 'echo_tool',
              args: {'message': 'ok'},
            ),
            AgentStep(
              description: '条件步骤',
              toolName: 'echo_tool',
              args: {'message': 'conditional'},
              condition: 'step_0.success',
            ),
          ],
          status: TaskStatus.pending,
          created: DateTime.now(),
        );

        final result = await agent.executeTask(task);
        expect(result.status, TaskStatus.completed);
        expect(result.steps[1].status, TaskStatus.completed);
      });

      test('条件 step_0.contains:text — 包含指定文本时通过', () async {
        final task = AgentTask(
          id: 'cond-contains-001',
          name: '包含条件测试',
          description: '包含条件测试',
          mode: TaskMode.manual,
          steps: [
            AgentStep(
              description: '回显',
              toolName: 'echo_tool',
              args: {'message': 'hello world'},
            ),
            AgentStep(
              description: '条件步骤',
              toolName: 'echo_tool',
              args: {'message': 'found'},
              condition: 'step_0.contains:hello',
            ),
          ],
          status: TaskStatus.pending,
          created: DateTime.now(),
        );

        final result = await agent.executeTask(task);
        expect(result.status, TaskStatus.completed);
        expect(result.steps[1].status, TaskStatus.completed);
      });
    });
  });
}

// 覆盖验收标准:
// AC-8:      task_execution_strategy_test.dart 覆盖任务执行策略的状态机
// AC-P3-1-4: 3 步任务执行后每步 status == completed 依次推进
// AC-P3-1-5: pauseTask → task.status 变为 paused，当前步骤停止
// AC-P3-1-6: cancelTask → task.status 变为 cancelled
// AC-P3-1-7: 50 步限制 → task.status 变为 failed，原因 "step_limit_exceeded"
// AC-P3-1-8: 30 分钟超时自动终止

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/services/agent/agent_tool.dart';
import 'package:rfbrowser/services/agent/agent_tool_registry.dart';
import 'package:rfbrowser/services/agent/task_execution_strategy.dart';
import 'package:rfbrowser/services/ai_service.dart';
import 'package:rfbrowser/services/agent_chat_bridge.dart';

// ─── Test Tools ─────────────────────────────────────────────────────

class _EchoTool extends AgentTool {
  _EchoTool()
    : super(
        name: 'echo_tool',
        description: 'Echoes the message argument',
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

class _FailingTool extends AgentTool {
  _FailingTool() : super(name: 'failing_tool', description: 'Always fails');

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    return ToolResult.failure('Intentional failure');
  }
}

class _FlakyTool extends AgentTool {
  final int _failBeforeSuccess;
  int _calls = 0;

  _FlakyTool(this._failBeforeSuccess)
    : super(name: 'flaky_tool', description: 'Fails N times then succeeds');

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    _calls++;
    if (_calls <= _failBeforeSuccess) {
      return ToolResult.failure('Failure #$_calls');
    }
    return ToolResult.success('Success after $_failBeforeSuccess failures');
  }
}

class _RecordingTool extends AgentTool {
  final List<Map<String, dynamic>> calls = [];
  final ToolResult _result;

  _RecordingTool({
    required super.name,
    ToolResult result = const ToolResult(success: true, output: 'recorded'),
  }) : _result = result,
       super(description: 'Records calls');

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    calls.add(Map<String, dynamic>.from(args));
    return _result;
  }
}

// ─── Mock AI Notifier ───────────────────────────────────────────────
// Returns canned responses sequentially so strategies can be tested
// without real network or AI service dependencies.

class _MockAINotifier extends AINotifier {
  final List<String> _responses;
  int _index = 0;

  _MockAINotifier(this._responses);

  @override
  AIState build() => AIState();

  @override
  Future<void> sendMessage(
    String userMessage, {
    String? systemPrompt,
    String? context,
    List<Map<String, dynamic>>? tools,
    AgentChatBridge? bridge,
    String? sessionId,
  }) async {
    final userMsg = ChatMessage(role: 'user', content: userMessage);
    final response = _index < _responses.length
        ? _responses[_index++]
        : '{"done": true, "tool": "final_answer", "args": {"answer": "completed"}}';
    final assistantMsg = ChatMessage(role: 'assistant', content: response);
    state = AIState(messages: [...state.messages, userMsg, assistantMsg]);
  }
}

// ─── Helper: obtain a Ref inside tests ──────────────────────────────

final _refProvider = Provider<Ref>((ref) => ref);

// ─── Tests ──────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AgentToolRegistry — 工具注册和查找', () {
    late AgentToolRegistry registry;

    setUp(() {
      registry = AgentToolRegistry();
    });

    test('register 添加工具后可通过 getTool 获取', () {
      registry.register(_EchoTool());
      final tool = registry.getTool('echo_tool');
      expect(tool, isNotNull);
      expect(tool!.name, 'echo_tool');
    });

    test('hasTool 返回已注册工具的存在性', () {
      registry.register(_EchoTool());
      expect(registry.hasTool('echo_tool'), true);
      expect(registry.hasTool('nonexistent'), false);
    });

    test('unregister 移除已注册工具', () {
      registry.register(_EchoTool());
      expect(registry.hasTool('echo_tool'), true);
      registry.unregister('echo_tool');
      expect(registry.hasTool('echo_tool'), false);
      expect(registry.getTool('echo_tool'), isNull);
    });

    test('execute 执行已注册工具并返回 ToolResult', () async {
      registry.register(_EchoTool());
      final result = await registry.execute('echo_tool', {'message': 'hello'});
      expect(result.success, true);
      expect(result.output, 'Echo: hello');
    });

    test('execute 未注册工具返回 failure', () async {
      final result = await registry.execute('nonexistent', {});
      expect(result.success, false);
      expect(result.error, 'Unknown tool: nonexistent');
    });

    test('allTools 返回所有已注册工具列表', () {
      registry.register(_EchoTool());
      registry.register(_FailingTool());
      expect(registry.allTools.length, 2);
      expect(
        registry.allTools.map((t) => t.name).toList(),
        containsAll(['echo_tool', 'failing_tool']),
      );
    });

    test('tools 返回不可修改的 Map', () {
      registry.register(_EchoTool());
      final tools = registry.tools;
      expect(tools.length, 1);
      expect(() => tools['x'] = _EchoTool(), throwsUnsupportedError);
    });

    test('allToolDefinitions 返回所有工具定义', () {
      registry.register(_EchoTool());
      final defs = registry.allToolDefinitions();
      expect(defs.length, 1);
      expect(defs[0]['name'], 'echo_tool');
      expect(defs[0]['isDestructive'], false);
      expect(defs[0]['source'], 'builtin');
    });

    test('toolsPrompt 包含工具名称和描述', () {
      registry.register(_EchoTool());
      final prompt = registry.toolsPrompt();
      expect(prompt, contains('echo_tool'));
      expect(prompt, contains('Echoes the message argument'));
    });

    test('clear 清空所有工具', () {
      registry.register(_EchoTool());
      registry.register(_FailingTool());
      expect(registry.tools.length, 2);
      registry.clear();
      expect(registry.tools, isEmpty);
    });
  });

  group('ManualExecutionStrategy 状态机 (AC-P3-1-4)', () {
    late AgentToolRegistry registry;
    late List<AgentTask> updatedTasks;

    setUp(() {
      registry = AgentToolRegistry();
      registry.register(_EchoTool());
      updatedTasks = [];
    });

    ExecutionContext makeContext() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return ExecutionContext(
        toolRegistry: registry,
        onUpdateTask: (t) => updatedTasks.add(t),
        ref: container.read(_refProvider),
      );
    }

    test('3 步任务执行后每步 status == completed 依次推进', () async {
      registry.register(_RecordingTool(name: 'step_a'));
      registry.register(_RecordingTool(name: 'step_b'));
      registry.register(_RecordingTool(name: 'step_c'));

      final task = AgentTask(
        id: 'manual-3step',
        name: '3步任务',
        description: '测试3步任务',
        mode: TaskMode.manual,
        status: TaskStatus.running,
        steps: [
          AgentStep(description: 'A', toolName: 'step_a', args: {}),
          AgentStep(description: 'B', toolName: 'step_b', args: {}),
          AgentStep(description: 'C', toolName: 'step_c', args: {}),
        ],
      );

      final strategy = ManualExecutionStrategy(makeContext());
      final result = await strategy.execute(task);

      expect(result.status, TaskStatus.completed);
      expect(result.steps.length, 3);
      for (final step in result.steps) {
        expect(step.status, TaskStatus.completed);
      }
      expect(result.steps[0].result, 'recorded');
      expect(result.steps[1].result, 'recorded');
      expect(result.steps[2].result, 'recorded');
    });

    test('步骤失败时任务变为 failed', () async {
      registry.register(_FailingTool());

      final task = AgentTask(
        id: 'manual-fail',
        name: '失败任务',
        description: '测试失败',
        mode: TaskMode.manual,
        status: TaskStatus.running,
        steps: [
          AgentStep(description: '会失败', toolName: 'failing_tool', args: {}),
        ],
      );

      final strategy = ManualExecutionStrategy(makeContext());
      final result = await strategy.execute(task);

      expect(result.status, TaskStatus.failed);
      expect(result.steps[0].status, TaskStatus.failed);
      expect(result.result, 'Intentional failure');
    });

    test('空步骤任务直接完成', () async {
      final task = AgentTask(
        id: 'manual-empty',
        name: '空任务',
        description: '无步骤',
        mode: TaskMode.manual,
        status: TaskStatus.running,
        steps: [],
      );

      final strategy = ManualExecutionStrategy(makeContext());
      final result = await strategy.execute(task);

      expect(result.status, TaskStatus.completed);
      expect(result.completed, isNotNull);
    });

    test('onUpdateTask 在每次状态变更时被调用', () async {
      final task = AgentTask(
        id: 'manual-callback',
        name: '回调测试',
        description: '测试回调',
        mode: TaskMode.manual,
        status: TaskStatus.running,
        steps: [
          AgentStep(
            description: 'echo',
            toolName: 'echo_tool',
            args: {'message': 'hi'},
          ),
        ],
      );

      final strategy = ManualExecutionStrategy(makeContext());
      await strategy.execute(task);

      // 至少: running step → completed step → completed task
      expect(updatedTasks.length, greaterThanOrEqualTo(2));
    });
  });

  group('ManualExecutionStrategy 步骤引擎', () {
    late AgentToolRegistry registry;

    setUp(() {
      registry = AgentToolRegistry();
      registry.register(_EchoTool());
    });

    ExecutionContext makeContext() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return ExecutionContext(
        toolRegistry: registry,
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
    }

    test('onFailure=skip 跳过失败步骤继续执行', () async {
      registry.register(_FailingTool());

      final task = AgentTask(
        id: 'skip-test',
        name: '跳过测试',
        description: '测试跳过',
        mode: TaskMode.manual,
        status: TaskStatus.running,
        steps: [
          AgentStep(
            description: '会失败',
            toolName: 'failing_tool',
            args: {},
            onFailure: 'skip',
          ),
          AgentStep(
            description: '回显',
            toolName: 'echo_tool',
            args: {'message': 'after_skip'},
          ),
        ],
      );

      final strategy = ManualExecutionStrategy(makeContext());
      final result = await strategy.execute(task);

      expect(result.status, TaskStatus.completed);
      expect(result.steps[0].status, TaskStatus.completed);
      expect(result.steps[0].result, contains('Error (skipped)'));
      expect(result.steps[1].status, TaskStatus.completed);
      expect(result.steps[1].result, contains('after_skip'));
    });

    test('onFailure=abort (默认) 失败时终止任务', () async {
      registry.register(_FailingTool());

      final task = AgentTask(
        id: 'abort-test',
        name: '终止测试',
        description: '测试终止',
        mode: TaskMode.manual,
        status: TaskStatus.running,
        steps: [
          AgentStep(description: '会失败', toolName: 'failing_tool', args: {}),
          AgentStep(
            description: '不会执行',
            toolName: 'echo_tool',
            args: {'message': 'no'},
          ),
        ],
      );

      final strategy = ManualExecutionStrategy(makeContext());
      final result = await strategy.execute(task);

      expect(result.status, TaskStatus.failed);
      expect(result.steps[0].status, TaskStatus.failed);
      expect(result.steps[1].status, TaskStatus.pending);
    });

    test('条件不满足时步骤被跳过', () async {
      final task = AgentTask(
        id: 'cond-skip',
        name: '条件跳过',
        description: '测试条件跳过',
        mode: TaskMode.manual,
        status: TaskStatus.running,
        steps: [
          AgentStep(
            description: 'echo',
            toolName: 'echo_tool',
            args: {'message': 'ok'},
          ),
          AgentStep(
            description: '条件步骤',
            toolName: 'echo_tool',
            args: {'message': 'conditional'},
            condition: 'step_0.contains:nonexistent_text',
          ),
        ],
      );

      final strategy = ManualExecutionStrategy(makeContext());
      final result = await strategy.execute(task);

      expect(result.status, TaskStatus.completed);
      expect(result.steps[1].status, TaskStatus.completed);
      expect(result.steps[1].result, contains('Skipped: condition not met'));
    });

    test('retryCount > 0 时失败步骤会重试', () async {
      registry.register(_FlakyTool(1));

      final task = AgentTask(
        id: 'retry-test',
        name: '重试测试',
        description: '测试重试',
        mode: TaskMode.manual,
        status: TaskStatus.running,
        steps: [
          AgentStep(
            description: 'flaky',
            toolName: 'flaky_tool',
            args: {},
            retryCount: 1,
          ),
        ],
      );

      final strategy = ManualExecutionStrategy(makeContext());
      final result = await strategy.execute(task);

      expect(result.status, TaskStatus.completed);
      expect(result.steps[0].status, TaskStatus.completed);
      expect(result.steps[0].result, contains('Success after 1 failures'));
    });
  });

  group('checkStopConditions — 步数限制 (AC-P3-1-7)', () {
    late AgentToolRegistry registry;

    setUp(() {
      registry = AgentToolRegistry();
    });

    ManualExecutionStrategy makeStrategy() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return ManualExecutionStrategy(
        ExecutionContext(
          toolRegistry: registry,
          onUpdateTask: (t) {},
          ref: container.read(_refProvider),
        ),
      );
    }

    test('maxSteps 常量为 50', () {
      expect(TaskExecutionStrategy.maxSteps, 50);
    });

    test('currentStep < maxSteps 时返回 null (继续执行)', () {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 't',
        name: 'n',
        description: 'd',
        status: TaskStatus.running,
      );
      final stopwatch = Stopwatch()..start();

      final result = strategy.checkStopConditions(task, stopwatch, 49, 50);
      expect(result, isNull);
    });

    test('currentStep >= maxSteps 时返回 failed + step_limit_exceeded', () {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 't',
        name: 'n',
        description: 'd',
        status: TaskStatus.running,
      );
      final stopwatch = Stopwatch()..start();

      final result = strategy.checkStopConditions(task, stopwatch, 50, 50);
      expect(result, isNotNull);
      expect(result!.status, TaskStatus.failed);
      expect(result.result, 'step_limit_exceeded');
    });

    test('小 maxSteps 也能正确触发限制', () {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 't',
        name: 'n',
        description: 'd',
        status: TaskStatus.running,
      );
      final stopwatch = Stopwatch()..start();

      final result = strategy.checkStopConditions(task, stopwatch, 3, 3);
      expect(result, isNotNull);
      expect(result!.result, 'step_limit_exceeded');
    });
  });

  group('checkStopConditions — 时间限制 (AC-P3-1-8)', () {
    test('maxDuration 常量为 30 分钟', () {
      expect(TaskExecutionStrategy.maxDuration, Duration(minutes: 30));
    });

    test('新启动的 stopwatch 不会触发时间限制', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final strategy = ManualExecutionStrategy(
        ExecutionContext(
          toolRegistry: AgentToolRegistry(),
          onUpdateTask: (t) {},
          ref: container.read(_refProvider),
        ),
      );

      final task = AgentTask(
        id: 't',
        name: 'n',
        description: 'd',
        status: TaskStatus.running,
      );
      final stopwatch = Stopwatch()..start();

      final result = strategy.checkStopConditions(task, stopwatch, 0, 50);
      expect(result, isNull);
    });
  });

  group('checkStopConditions — 暂停/取消 (AC-P3-1-5, AC-P3-1-6)', () {
    late AgentToolRegistry registry;

    setUp(() {
      registry = AgentToolRegistry();
      registry.register(_EchoTool());
    });

    ManualExecutionStrategy makeStrategy() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return ManualExecutionStrategy(
        ExecutionContext(
          toolRegistry: registry,
          onUpdateTask: (t) {},
          ref: container.read(_refProvider),
        ),
      );
    }

    test('paused 任务立即停止 (AC-P3-1-5)', () {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 'paused',
        name: 'n',
        description: 'd',
        status: TaskStatus.paused,
      );
      final stopwatch = Stopwatch()..start();

      final result = strategy.checkStopConditions(task, stopwatch, 0, 50);
      expect(result, isNotNull);
      expect(result!.status, TaskStatus.paused);
    });

    test('failed 任务立即停止 (AC-P3-1-6 cancel 场景)', () {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 'cancelled',
        name: 'n',
        description: 'd',
        status: TaskStatus.failed,
        result: 'cancelled',
      );
      final stopwatch = Stopwatch()..start();

      final result = strategy.checkStopConditions(task, stopwatch, 0, 50);
      expect(result, isNotNull);
      expect(result!.status, TaskStatus.failed);
      expect(result.result, 'cancelled');
    });

    test('paused 任务执行时立即返回，步骤不执行', () async {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 'paused-exec',
        name: '暂停任务',
        description: '测试暂停',
        status: TaskStatus.paused,
        steps: [
          AgentStep(
            description: 'echo',
            toolName: 'echo_tool',
            args: {'message': 'hi'},
          ),
        ],
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.paused);
      expect(result.steps[0].status, TaskStatus.pending);
    });

    test('resume: paused → running 后可继续执行', () async {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 'resume-test',
        name: '恢复测试',
        description: '测试恢复',
        status: TaskStatus.paused,
        steps: [
          AgentStep(
            description: 'echo',
            toolName: 'echo_tool',
            args: {'message': 'resumed'},
          ),
        ],
      );

      // 暂停状态执行 → 立即停止
      final pausedResult = await strategy.execute(task);
      expect(pausedResult.status, TaskStatus.paused);

      // 恢复为 running 后执行 → 完成
      final resumedTask = pausedResult.copyWith(status: TaskStatus.running);
      final result = await strategy.execute(resumedTask);
      expect(result.status, TaskStatus.completed);
      expect(result.steps[0].status, TaskStatus.completed);
    });
  });

  group('finalizeIfRunning', () {
    late AgentToolRegistry registry;

    setUp(() {
      registry = AgentToolRegistry();
    });

    ManualExecutionStrategy makeStrategy() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return ManualExecutionStrategy(
        ExecutionContext(
          toolRegistry: registry,
          onUpdateTask: (t) {},
          ref: container.read(_refProvider),
        ),
      );
    }

    test('running 任务被标记为 completed，result 为步骤结果拼接', () {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 't',
        name: 'n',
        description: 'd',
        status: TaskStatus.running,
      );

      final result = strategy.finalizeIfRunning(task, ['result1', 'result2']);
      expect(result.status, TaskStatus.completed);
      expect(result.completed, isNotNull);
      expect(result.result, 'result1\n\nresult2');
    });

    test('failed 任务保持不变', () {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 't',
        name: 'n',
        description: 'd',
        status: TaskStatus.failed,
        result: 'already failed',
      );

      final result = strategy.finalizeIfRunning(task, ['result']);
      expect(result.status, TaskStatus.failed);
      expect(result.result, 'already failed');
    });

    test('paused 任务保持不变', () {
      final strategy = makeStrategy();
      final task = AgentTask(
        id: 't',
        name: 'n',
        description: 'd',
        status: TaskStatus.paused,
      );

      final result = strategy.finalizeIfRunning(task, ['result']);
      expect(result.status, TaskStatus.paused);
    });
  });

  group('evaluateCondition', () {
    late ManualExecutionStrategy strategy;

    setUp(() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      strategy = ManualExecutionStrategy(
        ExecutionContext(
          toolRegistry: AgentToolRegistry(),
          onUpdateTask: (t) {},
          ref: container.read(_refProvider),
        ),
      );
    });

    test('step_0.success — 成功结果返回 true', () {
      expect(strategy.evaluateCondition('step_0.success', ['OK result']), true);
    });

    test('step_0.success — Error 开头返回 false', () {
      expect(
        strategy.evaluateCondition('step_0.success', ['Error: something']),
        false,
      );
    });

    test('step_0.success — Failed 开头返回 false', () {
      expect(
        strategy.evaluateCondition('step_0.success', ['Failed: bad']),
        false,
      );
    });

    test('step_0.contains:text — 包含时返回 true', () {
      expect(
        strategy.evaluateCondition('step_0.contains:hello', ['hello world']),
        true,
      );
    });

    test('step_0.contains:text — 不包含时返回 false', () {
      expect(
        strategy.evaluateCondition('step_0.contains:xyz', ['hello world']),
        false,
      );
    });

    test('step_0.notEmpty — 非空返回 true', () {
      expect(strategy.evaluateCondition('step_0.notEmpty', ['content']), true);
    });

    test('step_0.notEmpty — 空返回 false', () {
      expect(strategy.evaluateCondition('step_0.notEmpty', ['']), false);
    });

    test('索引超出范围时返回 true (默认通过)', () {
      expect(strategy.evaluateCondition('step_5.success', ['only one']), true);
    });

    test('无法识别的条件返回 true (默认通过)', () {
      expect(strategy.evaluateCondition('unknown_condition', ['result']), true);
    });
  });

  group('executeStepWithRetry', () {
    late AgentToolRegistry registry;

    setUp(() {
      registry = AgentToolRegistry();
    });

    ExecutionContext makeContext() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return ExecutionContext(
        toolRegistry: registry,
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
    }

    test('成功执行返回 ToolResult.success', () async {
      registry.register(_EchoTool());
      final strategy = ManualExecutionStrategy(makeContext());

      final step = AgentStep(
        description: 'echo',
        toolName: 'echo_tool',
        args: {'message': 'test'},
      );

      final result = await strategy.executeStepWithRetry(step, []);
      expect(result.success, true);
      expect(result.output, 'Echo: test');
    });

    test('未知工具返回 failure', () async {
      final strategy = ManualExecutionStrategy(makeContext());

      final step = AgentStep(
        description: 'unknown',
        toolName: 'nonexistent_tool',
        args: {},
      );

      final result = await strategy.executeStepWithRetry(step, []);
      expect(result.success, false);
      expect(result.error, 'Unknown tool: nonexistent_tool');
    });

    test('retryCount=0 时失败不重试', () async {
      registry.register(_FailingTool());
      final strategy = ManualExecutionStrategy(makeContext());

      final step = AgentStep(
        description: 'fail',
        toolName: 'failing_tool',
        args: {},
        retryCount: 0,
      );

      final result = await strategy.executeStepWithRetry(step, []);
      expect(result.success, false);
      expect(result.error, 'Intentional failure');
    });

    test('retryCount=1 时第一次失败第二次成功', () async {
      registry.register(_FlakyTool(1));
      final strategy = ManualExecutionStrategy(makeContext());

      final step = AgentStep(
        description: 'flaky',
        toolName: 'flaky_tool',
        args: {},
        retryCount: 1,
      );

      final result = await strategy.executeStepWithRetry(step, []);
      expect(result.success, true);
      expect(result.output, contains('Success after 1 failures'));
    });

    test('legacy 路径 — Navigate to: 调用 navigate 工具', () async {
      final navigateTool = _RecordingTool(name: 'navigate');
      registry.register(navigateTool);
      final strategy = ManualExecutionStrategy(makeContext());

      final step = AgentStep(description: 'Navigate to: https://example.com');

      final result = await strategy.executeStepWithRetry(step, []);
      expect(result.success, true);
      expect(navigateTool.calls.length, 1);
      expect(navigateTool.calls[0]['url'], 'https://example.com');
    });

    test('legacy 路径 — 无匹配前缀返回成功', () async {
      final strategy = ManualExecutionStrategy(makeContext());

      final step = AgentStep(description: 'Some random description');

      final result = await strategy.executeStepWithRetry(step, []);
      expect(result.success, true);
      expect(result.output, 'Step completed: Some random description');
    });
  });

  group('ReactLoopExecutionStrategy — ReAct 循环', () {
    AgentToolRegistry makeRegistry() {
      final registry = AgentToolRegistry();
      registry.register(_EchoTool());
      return registry;
    }

    test('AI 返回 done=true 时立即完成', () async {
      final responses = [
        '{"done": true, "tool": "final_answer", "args": {"answer": "final result"}}',
      ];
      final container = ProviderContainer(
        overrides: [aiProvider.overrideWith(() => _MockAINotifier(responses))],
      );
      addTearDown(container.dispose);

      final context = ExecutionContext(
        toolRegistry: makeRegistry(),
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
      final strategy = ReactLoopExecutionStrategy(context);

      final task = AgentTask(
        id: 'react-done',
        name: 'React done',
        description: 'Test immediate done',
        mode: TaskMode.reactLoop,
        maxIterations: 5,
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.completed);
      expect(result.result, 'final result');
      expect(result.steps.length, 1);
      expect(result.steps[0].toolName, 'final_answer');
    });

    test('执行工具后 AI 返回 done=true 完成', () async {
      final responses = [
        '{"thought": "echo first", "tool": "echo_tool", "args": {"message": "hi"}, "done": false}',
        '{"done": true, "tool": "final_answer", "args": {"answer": "all done"}}',
      ];
      final container = ProviderContainer(
        overrides: [aiProvider.overrideWith(() => _MockAINotifier(responses))],
      );
      addTearDown(container.dispose);

      final context = ExecutionContext(
        toolRegistry: makeRegistry(),
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
      final strategy = ReactLoopExecutionStrategy(context);

      final task = AgentTask(
        id: 'react-tool-then-done',
        name: 'React tool then done',
        description: 'Test tool execution',
        mode: TaskMode.reactLoop,
        maxIterations: 5,
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.completed);
      expect(result.result, 'all done');
      expect(result.steps.length, 2);
      expect(result.steps[0].toolName, 'echo_tool');
      expect(result.steps[0].status, TaskStatus.completed);
      expect(result.steps[1].toolName, 'final_answer');
    });

    test('未知工具被跳过，循环继续', () async {
      final responses = [
        '{"thought": "use bad tool", "tool": "nonexistent", "args": {}, "done": false}',
        '{"done": true, "tool": "final_answer", "args": {"answer": "recovered"}}',
      ];
      final container = ProviderContainer(
        overrides: [aiProvider.overrideWith(() => _MockAINotifier(responses))],
      );
      addTearDown(container.dispose);

      final context = ExecutionContext(
        toolRegistry: makeRegistry(),
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
      final strategy = ReactLoopExecutionStrategy(context);

      final task = AgentTask(
        id: 'react-unknown',
        name: 'React unknown tool',
        description: 'Test unknown tool handling',
        mode: TaskMode.reactLoop,
        maxIterations: 5,
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.completed);
      expect(result.result, 'recovered');
    });

    test('工具执行失败后循环继续', () async {
      final registry = makeRegistry();
      registry.register(_FailingTool());

      final responses = [
        '{"thought": "use failing tool", "tool": "failing_tool", "args": {}, "done": false}',
        '{"done": true, "tool": "final_answer", "args": {"answer": "done after error"}}',
      ];
      final container = ProviderContainer(
        overrides: [aiProvider.overrideWith(() => _MockAINotifier(responses))],
      );
      addTearDown(container.dispose);

      final context = ExecutionContext(
        toolRegistry: registry,
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
      final strategy = ReactLoopExecutionStrategy(context);

      final task = AgentTask(
        id: 'react-fail-then-done',
        name: 'React fail then done',
        description: 'Test failure handling',
        mode: TaskMode.reactLoop,
        maxIterations: 5,
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.completed);
      expect(result.result, 'done after error');
      expect(result.steps.any((s) => s.status == TaskStatus.failed), true);
    });

    test('maxIterations 耗尽后任务完成 (非失败)', () async {
      final responses = List.generate(
        10,
        (i) =>
            '{"thought": "keep going", "tool": "echo_tool", "args": {"message": "iter $i"}, "done": false}',
      );
      final container = ProviderContainer(
        overrides: [aiProvider.overrideWith(() => _MockAINotifier(responses))],
      );
      addTearDown(container.dispose);

      final context = ExecutionContext(
        toolRegistry: makeRegistry(),
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
      final strategy = ReactLoopExecutionStrategy(context);

      final task = AgentTask(
        id: 'react-max-iter',
        name: 'React max iter',
        description: 'Test max iterations',
        mode: TaskMode.reactLoop,
        maxIterations: 3,
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.completed);
      expect(result.completed, isNotNull);
    });

    test('maxIterations=0 被 clamp 到 1 不崩溃', () async {
      final responses = [
        '{"done": true, "tool": "final_answer", "args": {"answer": "clamped"}}',
      ];
      final container = ProviderContainer(
        overrides: [aiProvider.overrideWith(() => _MockAINotifier(responses))],
      );
      addTearDown(container.dispose);

      final context = ExecutionContext(
        toolRegistry: makeRegistry(),
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
      final strategy = ReactLoopExecutionStrategy(context);

      final task = AgentTask(
        id: 'react-clamp-zero',
        name: 'React clamp zero',
        description: 'Test clamping to 1',
        mode: TaskMode.reactLoop,
        maxIterations: 0,
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.completed);
      expect(result.result, 'clamped');
    });

    test('AI 响应解析失败时循环继续', () async {
      final responses = [
        'this is not valid json',
        '{"done": true, "tool": "final_answer", "args": {"answer": "after parse error"}}',
      ];
      final container = ProviderContainer(
        overrides: [aiProvider.overrideWith(() => _MockAINotifier(responses))],
      );
      addTearDown(container.dispose);

      final context = ExecutionContext(
        toolRegistry: makeRegistry(),
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
      final strategy = ReactLoopExecutionStrategy(context);

      final task = AgentTask(
        id: 'react-parse-error',
        name: 'React parse error',
        description: 'Test parse error recovery',
        mode: TaskMode.reactLoop,
        maxIterations: 5,
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.completed);
      expect(result.result, 'after parse error');
    });

    test('done=true 无 answer 时使用步骤结果拼接', () async {
      final responses = [
        '{"thought": "echo", "tool": "echo_tool", "args": {"message": "result1"}, "done": false}',
        '{"done": true, "tool": "final_answer", "args": {}}',
      ];
      final container = ProviderContainer(
        overrides: [aiProvider.overrideWith(() => _MockAINotifier(responses))],
      );
      addTearDown(container.dispose);

      final context = ExecutionContext(
        toolRegistry: makeRegistry(),
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
      final strategy = ReactLoopExecutionStrategy(context);

      final task = AgentTask(
        id: 'react-no-answer',
        name: 'React no answer',
        description: 'Test default answer',
        mode: TaskMode.reactLoop,
        maxIterations: 5,
      );

      final result = await strategy.execute(task);
      expect(result.status, TaskStatus.completed);
      expect(result.result, contains('Echo: result1'));
    });
  });

  group('ExecutionStrategyFactory', () {
    ExecutionContext makeContext() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return ExecutionContext(
        toolRegistry: AgentToolRegistry(),
        onUpdateTask: (t) {},
        ref: container.read(_refProvider),
      );
    }

    test('manual 模式创建 ManualExecutionStrategy', () {
      final strategy = ExecutionStrategyFactory.createStrategy(
        TaskMode.manual,
        makeContext(),
      );
      expect(strategy, isA<ManualExecutionStrategy>());
    });

    test('aiPlanned 模式创建 AIPlannedExecutionStrategy', () {
      final strategy = ExecutionStrategyFactory.createStrategy(
        TaskMode.aiPlanned,
        makeContext(),
      );
      expect(strategy, isA<AIPlannedExecutionStrategy>());
    });

    test('reactLoop 模式创建 ReactLoopExecutionStrategy', () {
      final strategy = ExecutionStrategyFactory.createStrategy(
        TaskMode.reactLoop,
        makeContext(),
      );
      expect(strategy, isA<ReactLoopExecutionStrategy>());
    });
  });
}

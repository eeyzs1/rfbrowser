import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/agent_service.dart';
import 'package:rfbrowser/services/agent/agent_tool.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
  @override
  set state(VaultState newState) => super.state = newState;
}

ProviderContainer createContainer() {
  return ProviderContainer(overrides: [
    vaultProvider.overrideWith(() => TestVaultNotifier(VaultState())),
  ]);
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AgentState', () {
    test('default state has empty tasks', () {
      final state = AgentState();
      expect(state.tasks, isEmpty);
      expect(state.headlessManager, isNotNull);
      expect(state.toolRegistry, isNotNull);
    });

    test('copyWith updates tasks', () {
      final task = AgentTask(id: 't1', name: 'Test', description: 'Desc');
      final state = AgentState().copyWith(tasks: [task]);
      expect(state.tasks, hasLength(1));
      expect(state.tasks.first.id, 't1');
    });

    test('copyWith preserves headlessManager and toolRegistry', () {
      final state = AgentState();
      final manager = state.headlessManager;
      final registry = state.toolRegistry;
      final updated = state.copyWith(tasks: []);
      expect(updated.headlessManager, same(manager));
      expect(updated.toolRegistry, same(registry));
    });
  });

  group('AgentStep', () {
    test('default values are correct', () {
      final step = AgentStep(description: 'Test step');
      expect(step.toolName, isNull);
      expect(step.args, isEmpty);
      expect(step.condition, isNull);
      expect(step.retryCount, 0);
      expect(step.onFailure, isNull);
      expect(step.status, TaskStatus.pending);
      expect(step.retryAttempt, 0);
    });

    test('copyWith works correctly', () {
      final step = AgentStep(description: 'Test');
      final updated = step.copyWith(
        toolName: 'navigate',
        args: {'url': 'https://example.com'},
        status: TaskStatus.running,
      );
      expect(updated.toolName, 'navigate');
      expect(updated.args['url'], 'https://example.com');
      expect(updated.status, TaskStatus.running);
      expect(updated.description, 'Test');
    });

    test('toJson and fromJson round-trip', () {
      final step = AgentStep(
        description: 'Navigate',
        toolName: 'navigate',
        args: {'url': 'https://example.com'},
        retryCount: 2,
        onFailure: 'skip',
        status: TaskStatus.completed,
        result: 'Done',
      );
      final json = step.toJson();
      final restored = AgentStep.fromJson(json);
      expect(restored.description, 'Navigate');
      expect(restored.toolName, 'navigate');
      expect(restored.args['url'], 'https://example.com');
      expect(restored.retryCount, 2);
      expect(restored.onFailure, 'skip');
      expect(restored.status, TaskStatus.completed);
      expect(restored.result, 'Done');
    });
  });

  group('AgentTask', () {
    test('default mode is manual', () {
      final task = AgentTask(id: 't1', name: 'Test', description: 'Desc');
      expect(task.mode, TaskMode.manual);
      expect(task.maxIterations, 50);
    });

    test('copyWith preserves mode', () {
      final task = AgentTask(
        id: 't1',
        name: 'Test',
        description: 'Desc',
        mode: TaskMode.reactLoop,
        maxIterations: 20,
      );
      final updated = task.copyWith(status: TaskStatus.running);
      expect(updated.mode, TaskMode.reactLoop);
      expect(updated.maxIterations, 20);
      expect(updated.status, TaskStatus.running);
    });

    test('toJson and fromJson round-trip', () {
      final task = AgentTask(
        id: 't1',
        name: 'Research',
        description: 'Research AI',
        mode: TaskMode.aiPlanned,
        maxIterations: 30,
        steps: [
          AgentStep(description: 'Step 1', toolName: 'search_notes', args: {'query': 'AI'}),
        ],
      );
      final json = task.toJson();
      final restored = AgentTask.fromJson(json);
      expect(restored.id, 't1');
      expect(restored.name, 'Research');
      expect(restored.mode, TaskMode.aiPlanned);
      expect(restored.maxIterations, 30);
      expect(restored.steps.length, 1);
      expect(restored.steps[0].toolName, 'search_notes');
    });
  });

  group('TaskMode', () {
    test('all modes have names', () {
      for (final mode in TaskMode.values) {
        expect(mode.name, isNotEmpty);
      }
    });
  });

  group('AgentNotifier', () {
    test('build returns AgentState with toolRegistry', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      expect(notifier.state.tasks, isEmpty);
      expect(notifier.toolRegistry, isNotNull);
      expect(notifier.toolRegistry.tools, isNotEmpty);
    });

    test('getTask returns task by id', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task = AgentTask(id: 't1', name: 'Test', description: 'Desc');
      notifier.state = AgentState(tasks: [task]);
      expect(notifier.getTask('t1'), isNotNull);
      expect(notifier.getTask('t1')!.name, 'Test');
    });

    test('getTask returns null for non-existent task', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      expect(notifier.getTask('non-existent'), isNull);
    });

    test('pauseTask pauses running task', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task = AgentTask(
        id: 't1',
        name: 'Test',
        description: 'Desc',
        status: TaskStatus.running,
      );
      notifier.state = AgentState(tasks: [task]);
      notifier.pauseTask('t1');
      expect(notifier.getTask('t1')!.status, TaskStatus.paused);
    });

    test('pauseTask does nothing for non-running task', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task = AgentTask(
        id: 't1',
        name: 'Test',
        description: 'Desc',
        status: TaskStatus.pending,
      );
      notifier.state = AgentState(tasks: [task]);
      notifier.pauseTask('t1');
      expect(notifier.getTask('t1')!.status, TaskStatus.pending);
    });

    test('pauseTask does nothing for non-existent task', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      notifier.pauseTask('nonexistent');
      expect(notifier.state.tasks, isEmpty);
    });

    test('resumeTask resumes paused task', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task = AgentTask(
        id: 't1',
        name: 'Test',
        description: 'Desc',
        status: TaskStatus.paused,
      );
      notifier.state = AgentState(tasks: [task]);
      notifier.resumeTask('t1');
      expect(notifier.getTask('t1')!.status, TaskStatus.running);
    });

    test('resumeTask does nothing for non-paused task', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task = AgentTask(
        id: 't1',
        name: 'Test',
        description: 'Desc',
        status: TaskStatus.completed,
      );
      notifier.state = AgentState(tasks: [task]);
      notifier.resumeTask('t1');
      expect(notifier.getTask('t1')!.status, TaskStatus.completed);
    });

    test('cancelTask sets status to failed with cancelled result', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task = AgentTask(
        id: 't1',
        name: 'Test',
        description: 'Desc',
        status: TaskStatus.running,
      );
      notifier.state = AgentState(tasks: [task]);
      notifier.cancelTask('t1');
      final cancelled = notifier.getTask('t1')!;
      expect(cancelled.status, TaskStatus.failed);
      expect(cancelled.result, 'cancelled');
    });

    test('cancelTask handles non-existent task gracefully', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      notifier.cancelTask('nonexistent');
      expect(notifier.state.tasks, isEmpty);
    });

    test('removeTask removes task from list', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task1 = AgentTask(id: 't1', name: 'Test1', description: 'Desc1');
      final task2 = AgentTask(id: 't2', name: 'Test2', description: 'Desc2');
      notifier.state = AgentState(tasks: [task1, task2]);
      notifier.removeTask('t1');
      expect(notifier.state.tasks, hasLength(1));
      expect(notifier.state.tasks.first.id, 't2');
    });

    test('removeTask handles non-existent task', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      notifier.removeTask('nonexistent');
      expect(notifier.state.tasks, isEmpty);
    });

    test('executeTask skips if task id already exists', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task = AgentTask(
        id: 't1',
        name: 'Test',
        description: 'Desc',
        status: TaskStatus.completed,
      );
      notifier.state = AgentState(tasks: [task]);
      final result = await notifier.executeTask(task);
      expect(result.status, TaskStatus.completed);
      expect(notifier.state.tasks, hasLength(1));
    });

    test('research creates task with reactLoop mode', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.research('Flutter');
      expect(result.name, 'Research: Flutter');
      expect(result.mode, TaskMode.reactLoop);
    });

    test('summarizeUrls creates task with manual mode and tool steps', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.summarizeUrls([
        'https://example.com',
        'https://flutter.dev',
      ]);
      expect(result.name, 'Summarize URLs');
      expect(result.mode, TaskMode.manual);
      expect(result.steps.length, 3);
      expect(result.steps[0].toolName, 'extract_text');
      expect(result.steps[2].toolName, 'ai_reason');
    });

    test('extractDataFromWeb creates task with tool steps', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.extractDataFromWeb(
        'https://example.com',
        '{field: type}',
      );
      expect(result.name, 'Extract Data');
      expect(result.steps[0].toolName, 'navigate');
      expect(result.steps[1].toolName, 'extract_text');
      expect(result.steps[2].toolName, 'ai_reason');
    });

    test('autoOrganize creates task with aiPlanned mode', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.autoOrganize(['Note 1', 'Note 2']);
      expect(result.name, 'Auto Organize');
      expect(result.mode, TaskMode.aiPlanned);
    });

    test('aiPlanAndExecute creates task with specified mode', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.aiPlanAndExecute(
        'Test goal',
        mode: TaskMode.reactLoop,
      );
      expect(result.name, 'Test goal');
      expect(result.mode, TaskMode.reactLoop);
    });

    test('registerPluginTool adds tool to registry', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final initialCount = notifier.toolRegistry.tools.length;
      notifier.registerPluginTool(_TestPluginTool());
      expect(notifier.toolRegistry.tools.length, initialCount + 1);
      expect(notifier.toolRegistry.hasTool('plugin_test'), true);
    });

    test('unregisterPluginTool removes tool from registry', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      notifier.registerPluginTool(_TestPluginTool());
      expect(notifier.toolRegistry.hasTool('plugin_test'), true);
      notifier.unregisterPluginTool('plugin_test');
      expect(notifier.toolRegistry.hasTool('plugin_test'), false);
    });
  });
}

class _TestPluginTool extends AgentTool {
  _TestPluginTool()
      : super(
          name: 'plugin_test',
          description: 'A plugin test tool',
          source: 'plugin',
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async =>
      ToolResult.success('plugin result');
}

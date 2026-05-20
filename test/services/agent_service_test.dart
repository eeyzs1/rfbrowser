import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/agent_service.dart';

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
    });

    test('copyWith updates tasks', () {
      final task = AgentTask(id: 't1', name: 'Test', description: 'Desc');
      final state = AgentState().copyWith(tasks: [task]);
      expect(state.tasks, hasLength(1));
      expect(state.tasks.first.id, 't1');
    });

    test('copyWith preserves headlessManager', () {
      final state = AgentState();
      final manager = state.headlessManager;
      final updated = state.copyWith(tasks: []);
      expect(updated.headlessManager, same(manager));
    });
  });

  group('AgentNotifier', () {
    test('build returns AgentState', () {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      expect(notifier.state.tasks, isEmpty);
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

    test('executeTask creates tasks', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final task = AgentTask(
        id: 't1',
        name: 'Test',
        description: 'Desc',
        steps: [
          AgentStep(description: 'Step 1'),
          AgentStep(description: 'Step 2'),
        ],
      );
      final result = await notifier.executeTask(task);
      expect(result.status, isNotNull);
    });

    test('research creates a task and executes it', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.research('Flutter');
      expect(result.name, 'Research: Flutter');
      expect(result.steps, hasLength(3));
    });

    test('summarizeUrls creates task with steps', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.summarizeUrls([
        'https://example.com',
        'https://flutter.dev',
      ]);
      expect(result.name, 'Summarize URLs');
      expect(result.steps, hasLength(3));
    });

    test('extractDataFromWeb creates task with steps', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.extractDataFromWeb(
        'https://example.com',
        '{field: type}',
      );
      expect(result.name, 'Extract Data');
      expect(result.steps, hasLength(3));
    });

    test('autoOrganize creates task with steps', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result = await notifier.autoOrganize(['Note 1', 'Note 2']);
      expect(result.name, 'Auto Organize');
      expect(result.steps, hasLength(3));
    });

    test('research generates unique ids', () async {
      final container = createContainer();
      final notifier = container.read(agentProvider.notifier);
      final result1 = await notifier.research('A');
      expect(notifier.state.tasks, hasLength(1));
      expect(result1.status, isNot(TaskStatus.pending));
    });
  });
}
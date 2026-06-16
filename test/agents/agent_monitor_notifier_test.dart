import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/agents/monitor/agent_monitor_notifier.dart';
import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/services/agent_service.dart';

AgentTask _task(
  String id, {
  required TaskStatus status,
  String name = 'task',
  String? result,
  List<AgentStep> steps = const [],
}) => AgentTask(
  id: id,
  name: name,
  description: 'd',
  status: status,
  result: result,
  steps: steps,
);

class _FakeAgentNotifier extends AgentNotifier {
  AgentState _initial;
  _FakeAgentNotifier(this._initial);

  @override
  AgentState build() => _initial;

  void set(AgentState s) {
    _initial = s;
    state = s;
  }
}

void main() {
  group('AgentMonitorNotifier (G14-D)', () {
    test('starts empty when agent has no tasks', () {
      final container = ProviderContainer(
        overrides: [
          agentProvider.overrideWith(
            () => _FakeAgentNotifier(AgentState(tasks: const [])),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snap = container.read(agentMonitorProvider);
      expect(snap.totalTasks, 0);
      expect(snap.runningCount, 0);
      expect(snap.hasActiveWork, isFalse);
      expect(snap.recentEvents, isEmpty);
    });

    test('aggregates counts by status', () {
      final tasks = [
        _task('a', status: TaskStatus.running),
        _task('b', status: TaskStatus.running),
        _task('c', status: TaskStatus.pending),
        _task('d', status: TaskStatus.completed),
        _task('e', status: TaskStatus.completed),
        _task('f', status: TaskStatus.completed),
        _task('g', status: TaskStatus.failed, result: 'boom'),
        _task('h', status: TaskStatus.paused),
      ];

      final container = ProviderContainer(
        overrides: [
          agentProvider.overrideWith(
            () => _FakeAgentNotifier(AgentState(tasks: tasks)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snap = container.read(agentMonitorProvider);
      expect(snap.totalTasks, 8);
      expect(snap.runningCount, 2);
      expect(snap.pendingCount, 1);
      expect(snap.completedCount, 3);
      expect(snap.failedCount, 1);
      expect(snap.pausedCount, 1);
      expect(snap.lastError, 'boom');
      expect(snap.lastFailedTask?.id, 'g');
      expect(snap.hasActiveWork, isTrue);
    });

    test('counts tool calls and steps', () {
      final tasks = [
        _task(
          'a',
          status: TaskStatus.completed,
          steps: [
            const AgentStep(description: 's1', toolName: 'web_search'),
            const AgentStep(description: 's2', toolName: 'note_create'),
            const AgentStep(description: 's3'), // no tool
          ],
        ),
        _task(
          'b',
          status: TaskStatus.completed,
          steps: [const AgentStep(description: 's4', toolName: 'note_read')],
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          agentProvider.overrideWith(
            () => _FakeAgentNotifier(AgentState(tasks: tasks)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snap = container.read(agentMonitorProvider);
      expect(snap.totalSteps, 4);
      expect(snap.totalToolCalls, 3);
    });

    test('emits a transition event when a task changes status', () async {
      final notifier = _FakeAgentNotifier(
        AgentState(
          tasks: [_task('x', status: TaskStatus.running, name: 'first task')],
        ),
      );

      final container = ProviderContainer(
        overrides: [agentProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      // Initial read: no events (we don't emit "created" for the
      // initial state — only status transitions are tracked).
      var snap = container.read(agentMonitorProvider);
      expect(snap.recentEvents, isEmpty);

      // Simulate a status change.
      notifier.set(
        AgentState(
          tasks: [_task('x', status: TaskStatus.completed, name: 'first task')],
        ),
      );

      // Allow microtasks for the listener callback.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      snap = container.read(agentMonitorProvider);
      expect(snap.recentEvents.length, 1);
      // The single event is the transition.
      final last = snap.recentEvents.last;
      expect(last.message, 'running → completed');
      expect(last.task.id, 'x');
    });

    test('event ring buffer caps at 50 entries', () async {
      final notifier = _FakeAgentNotifier(AgentState(tasks: const []));
      final container = ProviderContainer(
        overrides: [agentProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);
      // Read once to fire the listener.
      container.read(agentMonitorProvider);

      // Simulate 60 task creations in sequence.
      for (var i = 0; i < 60; i++) {
        notifier.set(
          AgentState(
            tasks: [_task('t$i', status: TaskStatus.pending, name: 'n$i')],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final snap = container.read(agentMonitorProvider);
      expect(snap.recentEvents.length, 50);
    });

    test('reset() clears counters and the event log', () async {
      final notifier = _FakeAgentNotifier(
        AgentState(
          tasks: [_task('a', status: TaskStatus.completed, name: 'first')],
        ),
      );
      final container = ProviderContainer(
        overrides: [agentProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);
      container.read(agentMonitorProvider);

      final monitor = container.read(agentMonitorProvider.notifier);
      monitor.reset();
      final snap = container.read(agentMonitorProvider);
      expect(snap.totalTasks, 0);
      expect(snap.recentEvents, isEmpty);
    });
  });
}

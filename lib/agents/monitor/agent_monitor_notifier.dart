import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent_task.dart';
import '../../services/agent_service.dart';

/// G14-D: snapshot used by the Agent Monitor page and by telemetry exports.
class AgentMonitorSnapshot {
  final int runningCount;
  final int pendingCount;
  final int pausedCount;
  final int completedCount;
  final int failedCount;
  final int totalTasks;
  final int totalToolCalls;
  final int totalSteps;
  final DateTime startedAt;
  final DateTime lastUpdatedAt;
  final String? lastError;
  final AgentTask? lastFailedTask;
  final List<AgentMonitorEvent> recentEvents;
  final Duration uptime;

  const AgentMonitorSnapshot({
    required this.runningCount,
    required this.pendingCount,
    required this.pausedCount,
    required this.completedCount,
    required this.failedCount,
    required this.totalTasks,
    required this.totalToolCalls,
    required this.totalSteps,
    required this.startedAt,
    required this.lastUpdatedAt,
    required this.recentEvents,
    required this.uptime,
    this.lastError,
    this.lastFailedTask,
  });

  /// True when there's at least one in-flight or paused task that needs
  /// the user's attention.
  bool get hasActiveWork => runningCount > 0 || pendingCount > 0;
}

/// A short, append-only log entry shown in the monitor timeline.
class AgentMonitorEvent {
  final DateTime at;
  final AgentTask task;
  final TaskStatus status;
  final String message;

  const AgentMonitorEvent({
    required this.at,
    required this.task,
    required this.status,
    required this.message,
  });
}

/// Riverpod state holder for the live monitor view. Subscribes to the
/// underlying `agentProvider` and recomputes counters on every change.
class AgentMonitorNotifier extends Notifier<AgentMonitorSnapshot> {
  static const int _maxRecentEvents = 50;

  final Queue<AgentMonitorEvent> _recent = Queue<AgentMonitorEvent>();
  ProviderSubscription<AgentState>? _sub;
  AgentState? _lastSeenState;
  final DateTime _startedAt = DateTime.now();

  @override
  AgentMonitorSnapshot build() {
    ref.onDispose(() => _sub?.close());

    // Compute initial state synchronously from the current agent state
    // (avoids the race where `fireImmediately: true` would mutate
    //  `state` AFTER `build()` already returned its initial value).
    final initialAgent = ref.read(agentProvider);
    _lastSeenState = initialAgent;
    final initialSnap = _aggregate(initialAgent, emitEvents: false);
    state = initialSnap;

    // Then subscribe to future changes.
    _sub = ref.listen<AgentState>(agentProvider, (prev, next) {
      if (identical(prev, next)) return;
      _recompute(next);
    });

    return initialSnap;
  }

  AgentMonitorSnapshot _empty() => AgentMonitorSnapshot(
    runningCount: 0,
    pendingCount: 0,
    pausedCount: 0,
    completedCount: 0,
    failedCount: 0,
    totalTasks: 0,
    totalToolCalls: 0,
    totalSteps: 0,
    startedAt: _startedAt,
    lastUpdatedAt: _startedAt,
    recentEvents: const [],
    uptime: Duration.zero,
  );

  void _recompute(AgentState agent) {
    state = _aggregate(agent, emitEvents: true);
  }

  AgentMonitorSnapshot _aggregate(
    AgentState agent, {
    required bool emitEvents,
  }) {
    final tasks = agent.tasks;
    int running = 0, pending = 0, paused = 0, completed = 0, failed = 0;
    int toolCalls = 0;
    int totalSteps = 0;
    AgentTask? lastFailed;

    for (final t in tasks) {
      totalSteps += t.steps.length;
      toolCalls += t.steps.where((s) => s.toolName != null).length;
      switch (t.status) {
        case TaskStatus.running:
          running++;
          break;
        case TaskStatus.pending:
          pending++;
          break;
        case TaskStatus.paused:
          paused++;
          break;
        case TaskStatus.completed:
          completed++;
          break;
        case TaskStatus.failed:
          failed++;
          lastFailed = t;
          break;
      }
    }

    if (emitEvents) {
      _emitTransitions(_lastSeenState, agent);
    }
    _lastSeenState = agent;

    return AgentMonitorSnapshot(
      runningCount: running,
      pendingCount: pending,
      pausedCount: paused,
      completedCount: completed,
      failedCount: failed,
      totalTasks: tasks.length,
      totalToolCalls: toolCalls,
      totalSteps: totalSteps,
      startedAt: _startedAt,
      lastUpdatedAt: DateTime.now(),
      lastError: lastFailed?.result,
      lastFailedTask: lastFailed,
      recentEvents: List<AgentMonitorEvent>.unmodifiable(_recent),
      uptime: DateTime.now().difference(_startedAt),
    );
  }

  void _emitTransitions(AgentState? prev, AgentState next) {
    if (prev == null) return;
    final prevById = {for (final t in prev.tasks) t.id: t};
    for (final t in next.tasks) {
      final p = prevById[t.id];
      if (p == null) {
        // New task.
        _append(
          AgentMonitorEvent(
            at: DateTime.now(),
            task: t,
            status: t.status,
            message: 'Task created: ${t.name}',
          ),
        );
        continue;
      }
      if (p.status != t.status) {
        _append(
          AgentMonitorEvent(
            at: DateTime.now(),
            task: t,
            status: t.status,
            message: '${p.status.name} → ${t.status.name}',
          ),
        );
      }
    }
  }

  void _append(AgentMonitorEvent ev) {
    if (_recent.length >= _maxRecentEvents) {
      _recent.removeFirst();
    }
    _recent.addLast(ev);
  }

  /// Manually reset all counters and the recent event log. Does not affect
  /// the underlying agent state — it's a UI-side clear.
  void reset() {
    _recent.clear();
    _lastSeenState = null;
    state = _empty();
  }
}

/// Provider exposed for the UI (Agent Monitor page, status bar, etc.).
final agentMonitorProvider =
    NotifierProvider<AgentMonitorNotifier, AgentMonitorSnapshot>(
      AgentMonitorNotifier.new,
    );

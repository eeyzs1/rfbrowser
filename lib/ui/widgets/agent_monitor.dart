import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/agent_service.dart';
import '../../data/models/agent_task.dart';

class AgentMonitor extends ConsumerWidget {
  const AgentMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentState = ref.watch(agentProvider);
    final theme = Theme.of(context);

    if (agentState.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text('No agent tasks', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Start a research or extraction task',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: agentState.tasks.length,
      itemBuilder: (context, index) {
        final task = agentState.tasks[index];
        return _TaskCard(task: task);
      },
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final AgentTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(task.status, theme);
    final statusIcon = _statusIcon(task.status);
    final completedSteps = task.steps.where((s) => s.status == TaskStatus.completed).length;
    final totalSteps = task.steps.length;
    final progress = totalSteps > 0 ? completedSteps / totalSteps : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.status == TaskStatus.running) ...[
                  IconButton(
                    icon: const Icon(Icons.pause, size: 16),
                    onPressed: () => ref.read(agentProvider.notifier).pauseTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Pause',
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, size: 16),
                    onPressed: () => ref.read(agentProvider.notifier).cancelTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Cancel',
                  ),
                ],
                if (task.status == TaskStatus.paused)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    onPressed: () => ref.read(agentProvider.notifier).resumeTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Resume',
                  ),
                if (task.status == TaskStatus.completed || task.status == TaskStatus.failed)
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () => ref.read(agentProvider.notifier).removeTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Remove',
                  ),
              ],
            ),
            if (totalSteps > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.colorScheme.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$completedSteps/$totalSteps steps',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
            const SizedBox(height: 8),
            ...task.steps.map((step) => _StepRow(step: step)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(TaskStatus status, ThemeData theme) {
    switch (status) {
      case TaskStatus.pending:
        return theme.hintColor;
      case TaskStatus.running:
        return theme.colorScheme.primary;
      case TaskStatus.paused:
        return theme.colorScheme.tertiary;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.failed:
        return theme.colorScheme.error;
    }
  }

  IconData _statusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.running:
        return Icons.sync;
      case TaskStatus.paused:
        return Icons.pause_circle;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.failed:
        return Icons.error;
    }
  }
}

class _StepRow extends StatelessWidget {
  final AgentStep step;

  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(step.status, theme);
    final icon = _statusIcon(step.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              step.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: step.status == TaskStatus.completed
                    ? theme.hintColor
                    : theme.textTheme.bodySmall?.color,
                decoration: step.status == TaskStatus.completed
                    ? TextDecoration.lineThrough
                    : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(TaskStatus status, ThemeData theme) {
    switch (status) {
      case TaskStatus.pending:
        return theme.hintColor;
      case TaskStatus.running:
        return theme.colorScheme.primary;
      case TaskStatus.paused:
        return theme.colorScheme.tertiary;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.failed:
        return theme.colorScheme.error;
    }
  }

  IconData _statusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.radio_button_unchecked;
      case TaskStatus.running:
        return Icons.sync;
      case TaskStatus.paused:
        return Icons.pause;
      case TaskStatus.completed:
        return Icons.check;
      case TaskStatus.failed:
        return Icons.close;
    }
  }
}

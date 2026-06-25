// ignore_for_file: unused_element, unused_element_parameter
part of 'speed_dial_fab.dart';

class _TaskCard extends ConsumerWidget {
  final AgentTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _statusColor(task.status, theme);
    final statusIcon = _statusIcon(task.status);
    final completedSteps = task.steps
        .where((s) => s.status == TaskStatus.completed)
        .length;
    final totalSteps = task.steps.length;
    final progress = totalSteps > 0 ? completedSteps / totalSteps : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _ModeBadge(mode: task.mode),
                if (task.status == TaskStatus.running) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.pause, size: 14),
                    onPressed: () =>
                        ref.read(agentProvider.notifier).pauseTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, size: 14),
                    onPressed: () =>
                        ref.read(agentProvider.notifier).cancelTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                  ),
                ],
                if (task.status == TaskStatus.paused)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 14),
                    onPressed: () =>
                        ref.read(agentProvider.notifier).resumeTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                  ),
                if (task.status == TaskStatus.completed ||
                    task.status == TaskStatus.failed)
                  IconButton(
                    icon: const Icon(Icons.close, size: 12),
                    onPressed: () =>
                        ref.read(agentProvider.notifier).removeTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                  ),
              ],
            ),
            if (totalSteps > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.colorScheme.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.agentStepProgress(completedSteps, totalSteps),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
            if (task.steps.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...task.steps.take(5).map((step) => _StepRow(step: step)),
              if (task.steps.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '... +${task.steps.length - 5}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _statusColor(TaskStatus status, ThemeData theme) {
  return switch (status) {
    TaskStatus.pending => theme.hintColor,
    TaskStatus.running => theme.colorScheme.primary,
    TaskStatus.paused => theme.colorScheme.tertiary,
    TaskStatus.completed => theme.colorScheme.primary,
    TaskStatus.failed => theme.colorScheme.error,
  };
}

IconData _statusIcon(TaskStatus status) {
  return switch (status) {
    TaskStatus.pending => Icons.schedule,
    TaskStatus.running => Icons.sync,
    TaskStatus.paused => Icons.pause_circle,
    TaskStatus.completed => Icons.check_circle,
    TaskStatus.failed => Icons.error,
  };
}

class _ModeBadge extends StatelessWidget {
  final TaskMode mode;

  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (mode) {
      TaskMode.manual => (l10n.agentModeManual, theme.hintColor),
      TaskMode.aiPlanned => (
        l10n.agentModeAiPlanned,
        theme.colorScheme.primary,
      ),
      TaskMode.reactLoop => (l10n.agentModeReact, theme.colorScheme.tertiary),
    };

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontFamily: 'monospace'),
      ),
    );
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          if (step.toolName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                step.toolName!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              step.description,
              style: theme.textTheme.labelSmall?.copyWith(
                color: step.status == TaskStatus.completed
                    ? theme.hintColor
                    : null,
                decoration: step.status == TaskStatus.completed
                    ? TextDecoration.lineThrough
                    : null,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

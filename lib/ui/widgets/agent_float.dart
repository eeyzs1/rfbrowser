import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/agent_service.dart';
import '../../data/models/agent_task.dart';
import '../theme/design_tokens.dart';
import '../layout/scene_scaffold.dart';

class AgentFloat extends ConsumerStatefulWidget {
  final SceneType? currentScene;

  const AgentFloat({super.key, this.currentScene});

  @override
  ConsumerState<AgentFloat> createState() => _AgentFloatState();
}

class _AgentFloatState extends ConsumerState<AgentFloat>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isPressed = false;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: DesignDuration.aiFloatExpand,
    )..value = _isExpanded ? 1.0 : 0.0;
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.duration = DesignDuration.aiFloatExpand;
        _animationController.forward();
      } else {
        _animationController.duration = DesignDuration.aiFloatCollapse;
        _animationController.reverse();
      }
    });
  }

  void _collapse() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _animationController.duration = DesignDuration.aiFloatCollapse;
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _collapse,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.black38),
            ),
          ),
        if (_isExpanded)
          Positioned(
            right: DesignSpacing.lg + 56,
            bottom: 72,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                  shadowColor: DesignShadow.lg.color,
                  child: Container(
                    width: 400,
                    height: 520,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      child: Stack(
                        children: [
                          const _AgentPanelContent(),
                          Positioned(
                            top: DesignSpacing.xs,
                            right: DesignSpacing.xs,
                            child: Semantics(
                              button: true,
                              label: MaterialLocalizations.of(
                                context,
                              ).closeButtonLabel,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: _collapse,
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).closeButtonLabel,
                                constraints: const BoxConstraints(
                                  minWidth: DesignTouchTarget.iconButtonSize,
                                  minHeight: DesignTouchTarget.iconButtonSize,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black26,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: DesignSpacing.lg,
          bottom: DesignSpacing.lg,
          child: Semantics(
            button: true,
            label: _isExpanded ? 'Close Agent' : 'Open Agent',
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _toggle();
              },
              onTapCancel: () => setState(() => _isPressed = false),
              child: AnimatedScale(
                scale: _isPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeInOut,
                child: FloatingActionButton(
                  heroTag: 'agent_float',
                  onPressed: null,
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.smart_toy,
                    size: 20,
                    color: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AgentPanelContent extends ConsumerStatefulWidget {
  const _AgentPanelContent();

  @override
  ConsumerState<_AgentPanelContent> createState() => _AgentPanelContentState();
}

class _AgentPanelContentState extends ConsumerState<_AgentPanelContent> {
  final _goalController = TextEditingController();
  final _goalFocusNode = FocusNode();
  TaskMode _selectedMode = TaskMode.reactLoop;
  bool _isExecuting = false;

  @override
  void dispose() {
    _goalController.dispose();
    _goalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final agentState = ref.watch(agentProvider);
    final tasks = agentState.tasks;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 40, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.smart_toy,
                    size: 18,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.agent,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildModeSelector(theme, l10n),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _goalController,
                      focusNode: _goalFocusNode,
                      decoration: InputDecoration(
                        hintText: l10n.agentGoalHint,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignRadius.sm),
                        ),
                      ),
                      onSubmitted: (_) => _executeGoal(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isExecuting ? null : _executeGoal,
                    icon: _isExecuting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.play_arrow, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiary,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? _buildEmptyState(theme, l10n)
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) =>
                      _TaskCard(task: tasks[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(ThemeData theme, AppLocalizations l10n) {
    return SegmentedButton<TaskMode>(
      segments: [
        ButtonSegment(
          value: TaskMode.manual,
          label: Text(
            l10n.agentModeManual,
            style: const TextStyle(fontSize: 10),
          ),
        ),
        ButtonSegment(
          value: TaskMode.aiPlanned,
          label: Text(
            l10n.agentModeAiPlanned,
            style: const TextStyle(fontSize: 10),
          ),
        ),
        ButtonSegment(
          value: TaskMode.reactLoop,
          label: Text(
            l10n.agentModeReact,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ],
      selected: {_selectedMode},
      onSelectionChanged: (modes) {
        setState(() => _selectedMode = modes.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(
          const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy, size: 40, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(l10n.agentNoTasks, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              l10n.agentNoTasksHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _QuickActionChip(
                  icon: Icons.search,
                  label: l10n.agentQuickResearch,
                  onTap: () {
                    _goalController.text = '';
                    setState(() => _selectedMode = TaskMode.reactLoop);
                    _goalFocusNode.requestFocus();
                  },
                ),
                _QuickActionChip(
                  icon: Icons.summarize,
                  label: l10n.agentQuickSummarize,
                  onTap: () {
                    _goalController.text = '';
                    setState(() => _selectedMode = TaskMode.aiPlanned);
                    _goalFocusNode.requestFocus();
                  },
                ),
                _QuickActionChip(
                  icon: Icons.auto_fix_high,
                  label: l10n.agentQuickOrganize,
                  onTap: () {
                    _goalController.text = '';
                    setState(() => _selectedMode = TaskMode.aiPlanned);
                    _goalFocusNode.requestFocus();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeGoal() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) return;

    setState(() => _isExecuting = true);
    _goalController.clear();

    try {
      final agent = ref.read(agentProvider.notifier);
      switch (_selectedMode) {
        case TaskMode.manual:
          final task = AgentTask(
            id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
            name: goal,
            description: goal,
            mode: TaskMode.manual,
          );
          await agent.executeTask(task);
        case TaskMode.aiPlanned:
          await agent.aiPlanAndExecute(goal, mode: TaskMode.aiPlanned);
        case TaskMode.reactLoop:
          await agent.aiPlanAndExecute(goal, mode: TaskMode.reactLoop);
      }
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 14, color: theme.colorScheme.tertiary),
      label: Text(label, style: theme.textTheme.labelSmall),
      onPressed: onTap,
    );
  }
}

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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
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
      TaskStatus.pending => Icons.radio_button_unchecked,
      TaskStatus.running => Icons.sync,
      TaskStatus.paused => Icons.pause,
      TaskStatus.completed => Icons.check,
      TaskStatus.failed => Icons.close,
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/agent_service.dart';
import '../../data/models/agent_task.dart';
import '../pages/ai_chat_panel.dart';
import '../theme/design_tokens.dart';

enum _PanelType { none, ai, agent }

class SpeedDialFAB extends ConsumerStatefulWidget {
  const SpeedDialFAB({super.key});

  @override
  ConsumerState<SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends ConsumerState<SpeedDialFAB>
    with SingleTickerProviderStateMixin {
  bool _speedDialOpen = false;
  _PanelType _activePanel = _PanelType.none;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: DesignDuration.aiFloatExpand,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isAnythingOpen =>
      _speedDialOpen || _activePanel != _PanelType.none;

  void _toggleSpeedDial() {
    setState(() {
      if (_speedDialOpen) {
        _speedDialOpen = false;
        _animController.reverse();
      } else {
        _speedDialOpen = true;
        _activePanel = _PanelType.none;
        _animController.forward();
      }
    });
  }

  void _openPanel(_PanelType type) {
    setState(() {
      _speedDialOpen = false;
      _activePanel = type;
      _animController.reset();
      _animController.forward();
    });
  }

  void _closeAll() {
    setState(() {
      _speedDialOpen = false;
      _activePanel = _PanelType.none;
    });
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        if (_isAnythingOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeAll,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.black38),
            ),
          ),

        if (_activePanel == _PanelType.ai)
          Positioned(
            right: DesignSpacing.lg,
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
                    width: 360,
                    height: 480,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      child: Stack(
                        children: [
                          const AIChatPanel(),
                          Positioned(
                            top: DesignSpacing.xs,
                            right: DesignSpacing.xs,
                            child: Semantics(
                              button: true,
                              label: MaterialLocalizations.of(context)
                                  .closeButtonLabel,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: _closeAll,
                                tooltip: MaterialLocalizations.of(context)
                                    .closeButtonLabel,
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

        if (_activePanel == _PanelType.agent)
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
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      border: Border.all(color: theme.dividerColor),
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
                              label: MaterialLocalizations.of(context)
                                  .closeButtonLabel,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: _closeAll,
                                tooltip: MaterialLocalizations.of(context)
                                    .closeButtonLabel,
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

        if (_speedDialOpen) ...[
          _buildSpeedDialItem(
            theme,
            label: l10n.aiAssistant,
            icon: Icons.psychology,
            color: theme.colorScheme.secondary,
            onColor: theme.colorScheme.onSecondary,
            bottomOffset: DesignSpacing.lg + 72,
            onTap: () => _openPanel(_PanelType.ai),
          ),
          _buildSpeedDialItem(
            theme,
            label: l10n.agent,
            icon: Icons.smart_toy,
            color: theme.colorScheme.tertiary,
            onColor: theme.colorScheme.onTertiary,
            bottomOffset: DesignSpacing.lg + 128,
            onTap: () => _openPanel(_PanelType.agent),
          ),
        ],

        Positioned(
          right: 20,
          bottom: 20,
          child: SizedBox(
            width: 60,
            height: 60,
            child: FloatingActionButton(
              heroTag: 'speed_dial_fab',
              onPressed: _toggleSpeedDial,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: theme.colorScheme.primary,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isAnythingOpen ? Icons.close : Icons.auto_awesome,
                  key: ValueKey(_isAnythingOpen),
                  size: 28,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialItem(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required Color color,
    required Color onColor,
    required double bottomOffset,
    required VoidCallback onTap,
  }) {
    return Positioned(
      right: DesignSpacing.lg + 4,
      bottom: bottomOffset,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                  boxShadow: const [DesignShadow.sm],
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: onTap,
                backgroundColor: color,
                child: Icon(icon, color: onColor, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Agent panel content (extracted from agent_float.dart)
// ──────────────────────────────────────────────────────────────

class _AgentPanelContent extends ConsumerStatefulWidget {
  const _AgentPanelContent();

  @override
  ConsumerState<_AgentPanelContent> createState() =>
      _AgentPanelContentState();
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
                          borderRadius:
                              BorderRadius.circular(DesignRadius.sm),
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
    final modeDescriptions = <TaskMode, String>{
      TaskMode.manual: l10n.agentModeManualDesc,
      TaskMode.aiPlanned: l10n.agentModeAiPlannedDesc,
      TaskMode.reactLoop: l10n.agentModeReactDesc,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<TaskMode>(
          segments: [
            ButtonSegment(
              value: TaskMode.manual,
              icon: const Icon(Icons.list_alt, size: 14),
              label: Text(l10n.agentModeManual,
                  style: const TextStyle(fontSize: 10)),
            ),
            ButtonSegment(
              value: TaskMode.aiPlanned,
              icon: const Icon(Icons.psychology, size: 14),
              label: Text(l10n.agentModeAiPlanned,
                  style: const TextStyle(fontSize: 10)),
            ),
            ButtonSegment(
              value: TaskMode.reactLoop,
              icon: const Icon(Icons.autorenew, size: 14),
              label: Text(l10n.agentModeReact,
                  style: const TextStyle(fontSize: 10)),
            ),
          ],
          selected: {_selectedMode},
          onSelectionChanged: (modes) {
            setState(() => _selectedMode = modes.first);
          },
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(
            modeDescriptions[_selectedMode] ?? '',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              fontSize: 10,
            ),
          ),
        ),
      ],
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
            Text(
              l10n.agentNoTasks,
              style: theme.textTheme.bodyMedium,
            ),
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
    final completedSteps =
        task.steps.where((s) => s.status == TaskStatus.completed).length;
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
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, size: 14),
                    onPressed: () =>
                        ref.read(agentProvider.notifier).cancelTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                  ),
                ],
                if (task.status == TaskStatus.paused)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 14),
                    onPressed: () =>
                        ref.read(agentProvider.notifier).resumeTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                  ),
                if (task.status == TaskStatus.completed ||
                    task.status == TaskStatus.failed)
                  IconButton(
                    icon: const Icon(Icons.close, size: 12),
                    onPressed: () =>
                        ref.read(agentProvider.notifier).removeTask(task.id),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
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
              ...task.steps.take(5).map(
                    (step) => _StepRow(step: step),
                  ),
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
      TaskMode.aiPlanned =>
        (l10n.agentModeAiPlanned, theme.colorScheme.primary),
      TaskMode.reactLoop =>
        (l10n.agentModeReact, theme.colorScheme.tertiary),
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
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontFamily: 'monospace',
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
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/agent_service.dart';
import '../../data/models/agent_task.dart';
import '../theme/design_tokens.dart';
import '../layout/scene_scaffold.dart';

part 'agent_float_widgets.dart';

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

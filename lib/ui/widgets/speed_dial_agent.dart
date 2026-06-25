// ignore_for_file: unused_element, unused_element_parameter
part of 'speed_dial_fab.dart';

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
              label: Text(
                l10n.agentModeManual,
                style: const TextStyle(fontSize: 10),
              ),
            ),
            ButtonSegment(
              value: TaskMode.aiPlanned,
              icon: const Icon(Icons.psychology, size: 14),
              label: Text(
                l10n.agentModeAiPlanned,
                style: const TextStyle(fontSize: 10),
              ),
            ),
            ButtonSegment(
              value: TaskMode.reactLoop,
              icon: const Icon(Icons.autorenew, size: 14),
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

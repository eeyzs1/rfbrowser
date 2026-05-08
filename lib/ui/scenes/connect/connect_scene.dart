import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/knowledge_service.dart';
import '../../widgets/filter_panel.dart';
import '../../widgets/node_detail_panel.dart';
import '../../widgets/ai_float.dart';
import '../../widgets/resizable_panel.dart';
import '../../pages/graph_page.dart';
import '../../pages/canvas_page.dart';

enum ConnectViewMode { graph, canvas }

class ConnectScene extends ConsumerStatefulWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleRightPanel;

  const ConnectScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.onToggleLeftPanel,
    this.onToggleRightPanel,
  });

  @override
  ConsumerState<ConnectScene> createState() => _ConnectSceneState();
}

class _ConnectSceneState extends ConsumerState<ConnectScene> {
  ConnectViewMode _viewMode = ConnectViewMode.graph;

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final theme = Theme.of(context);

    return Stack(
      children: [
        Row(
          children: [
            if (widget.leftPanelExpanded)
              const ResizablePanel(
                initialWidth: 220,
                minWidth: 160,
                maxWidth: 380,
                child: FilterPanel(),
              ),
            if (!widget.leftPanelExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onToggleLeftPanel,
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(right: BorderSide(color: theme.dividerColor)),
                    ),
                    child: Icon(Icons.chevron_right, size: 14, color: theme.hintColor),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _buildViewModeSwitcher(theme),
                  Expanded(
                    child: knowledgeState.notes.isEmpty
                        ? _buildConnectEmptyState(context)
                        : _viewMode == ConnectViewMode.graph
                            ? const GraphView()
                            : const CanvasPage(),
                  ),
                ],
              ),
            ),
            if (!widget.rightPanelExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onToggleRightPanel,
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(left: BorderSide(color: theme.dividerColor)),
                    ),
                    child: Icon(Icons.chevron_left, size: 14, color: theme.hintColor),
                  ),
                ),
              ),
            if (widget.rightPanelExpanded)
              ResizablePanel(
                initialWidth: 280,
                minWidth: 200,
                maxWidth: 450,
                isLeft: false,
                child: NodeDetailPanel(onClose: widget.onToggleRightPanel),
              ),
          ],
        ),
        const Positioned.fill(child: AIFloat()),
      ],
    );
  }

  Widget _buildViewModeSwitcher(ThemeData theme) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          _viewModeTab(theme, ConnectViewMode.graph, Icons.hub, '图谱'),
          _viewModeTab(theme, ConnectViewMode.canvas, Icons.dashboard, '画布'),
        ],
      ),
    );
  }

  Widget _viewModeTab(ThemeData theme, ConnectViewMode mode, IconData icon, String label) {
    final isActive = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? theme.colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isActive ? theme.colorScheme.primary : theme.hintColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive ? theme.colorScheme.primary : theme.hintColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _viewMode == ConnectViewMode.graph ? Icons.hub : Icons.dashboard,
            size: 48,
            color: theme.hintColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _viewMode == ConnectViewMode.graph
                ? '知识图谱将在创建笔记后显示'
                : '画布将在添加卡片后显示',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

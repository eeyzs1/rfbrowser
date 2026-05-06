import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/knowledge_service.dart';
import '../../widgets/filter_panel.dart';
import '../../widgets/node_detail_panel.dart';
import '../../widgets/ai_float.dart';
import '../../pages/graph_page.dart';

class ConnectScene extends ConsumerWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;

  const ConnectScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knowledgeState = ref.watch(knowledgeProvider);

    return Stack(
      children: [
        Row(
          children: [
            if (leftPanelExpanded)
              const SizedBox(width: 220, child: FilterPanel()),
            Expanded(
              child: knowledgeState.notes.isEmpty
                  ? _buildConnectEmptyState(context)
                  : const GraphView(),
            ),
            if (rightPanelExpanded)
              const SizedBox(width: 280, child: NodeDetailPanel()),
          ],
        ),
        const Positioned(right: 0, bottom: 0, child: AIFloat()),
      ],
    );
  }

  Widget _buildConnectEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hub,
            size: 48,
            color: theme.hintColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '知识图谱将在创建笔记后显示',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

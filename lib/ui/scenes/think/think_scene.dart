import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/knowledge_service.dart';
import '../../widgets/note_sidebar.dart';
import '../../widgets/backlinks_panel.dart';
import '../../widgets/inline_ai_editor.dart';
import '../../widgets/quick_search_bar.dart';
import '../../widgets/ai_float.dart';
import '../../pages/editor_page.dart';

class ThinkScene extends ConsumerWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final VoidCallback? onCreateNote;

  const ThinkScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.onCreateNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final hasActiveNote = knowledgeState.activeNote != null;

    return Column(
      children: [
        const QuickSearchBar(),
        Expanded(
          child: Stack(
            children: [
              Row(
                children: [
                  if (leftPanelExpanded)
                    const SizedBox(width: 240, child: NoteSidebar()),
                  Expanded(
                    child: hasActiveNote
                        ? InlineAIEditor(child: const EditorView())
                        : _buildThinkEmptyState(context, ref),
                  ),
                  if (rightPanelExpanded)
                    const SizedBox(width: 260, child: BacklinksPanel()),
                ],
              ),
              const Positioned(right: 0, bottom: 0, child: AIFloat()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThinkEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_note,
            size: 48,
            color: theme.hintColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '选择一条笔记开始编辑',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onCreateNote,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建笔记'),
          ),
        ],
      ),
    );
  }
}

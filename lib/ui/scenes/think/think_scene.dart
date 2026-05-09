import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/knowledge_service.dart';
import '../../widgets/note_sidebar.dart';
import '../../widgets/backlinks_panel.dart';
import '../../widgets/inline_ai_editor.dart';
import '../../widgets/quick_search_bar.dart';
import '../../widgets/ai_float.dart';
import '../../widgets/resizable_panel.dart';
import '../../pages/editor_page.dart';
import '../../../data/models/note.dart';

class ThinkScene extends ConsumerWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleRightPanel;
  final VoidCallback? onCreateNote;
  final VoidCallback? onNoteOpened;

  const ThinkScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.onToggleLeftPanel,
    this.onToggleRightPanel,
    this.onCreateNote,
    this.onNoteOpened,
  });

  void _openNote(WidgetRef ref, Note note) {
    ref.read(knowledgeProvider.notifier).openNote(note.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final hasActiveNote = knowledgeState.activeNote != null;
    final theme = Theme.of(context);

    return Column(
      children: [
        QuickSearchBar(
          onNoteSelected: (note) => _openNote(ref, note),
        ),
        Expanded(
          child: Stack(
            children: [
              Row(
                children: [
                  if (leftPanelExpanded)
                    ResizablePanel(
                      initialWidth: 240,
                      minWidth: 180,
                      maxWidth: 400,
                      child: NoteSidebar(onNoteOpened: onNoteOpened),
                    ),
                  if (!leftPanelExpanded)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onToggleLeftPanel,
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
                    child: hasActiveNote
                        ? InlineAIEditor(child: const EditorView())
                        : _buildThinkEmptyState(context, ref),
                  ),
                  if (!rightPanelExpanded)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onToggleRightPanel,
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
                  if (rightPanelExpanded)
                    ResizablePanel(
                      initialWidth: 260,
                      minWidth: 180,
                      maxWidth: 400,
                      isLeft: false,
                      child: BacklinksPanel(onClose: onToggleRightPanel),
                    ),
                ],
              ),
              const Positioned.fill(child: AIFloat()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThinkEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
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
            l.selectNoteToEdit,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onCreateNote,
            icon: const Icon(Icons.add, size: 16),
            label: Text(l.newNote),
          ),
        ],
      ),
    );
  }
}

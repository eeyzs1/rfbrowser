import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../../services/ai_service.dart';
import '../theme/design_tokens.dart';

class InlineAIEditor extends ConsumerStatefulWidget {
  final Widget child;

  const InlineAIEditor({super.key, required this.child});

  @override
  ConsumerState<InlineAIEditor> createState() => _InlineAIEditorState();
}

class _InlineAIEditorState extends ConsumerState<InlineAIEditor> {
  bool _showSuggestions = false;

  void _requestSuggestion() {
    final knowledgeState = ref.read(knowledgeProvider);
    final activeNote = knowledgeState.activeNote;
    if (activeNote == null) return;

    ref.read(aiProvider.notifier).sendMessage(
          '基于以下笔记内容提供改进建议（简洁地）:\n${activeNote.content}',
        );
    setState(() => _showSuggestions = true);
  }

  void _completeWikilink() {
    final knowledgeState = ref.read(knowledgeProvider);
    final activeNote = knowledgeState.activeNote;
    if (activeNote == null) return;

    setState(() => _showSuggestions = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return Stack(
      children: [
        widget.child,
        Positioned(
          right: DesignSpacing.md,
          top: DesignSpacing.md,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'inline_ai',
                onPressed: _requestSuggestion,
                tooltip: l.aiSuggestion,
                child: const Icon(Icons.auto_awesome, size: 18),
              ),
              const SizedBox(height: DesignSpacing.sm),
              FloatingActionButton.small(
                heroTag: 'wikilink_complete',
                onPressed: _completeWikilink,
                tooltip: l.insertWikilink,
                child: const Icon(Icons.attach_file, size: 18),
              ),
            ],
          ),
        ),
        if (_showSuggestions)
          Positioned(
            right: 56,
            bottom: DesignSpacing.lg,
            child: _buildSuggestionPanel(theme),
          ),
      ],
    );
  }

  Widget _buildSuggestionPanel(ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    final aiState = ref.watch(aiProvider);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(DesignRadius.md),
      child: Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(DesignRadius.md),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSpacing.sm,
                vertical: DesignSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    l.aiSuggestion,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showSuggestions = false),
                    child: const Icon(Icons.close, size: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DesignSpacing.sm),
                child: aiState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Text(
                          aiState.messages.isNotEmpty
                              ? aiState.messages.last.content
                              : l.clickAiForSuggestion,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

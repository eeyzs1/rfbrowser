import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../../services/ai_service.dart';
import '../../data/models/note.dart';
import '../theme/design_tokens.dart';

/// Inline AI assistant + wikilink completion overlay for the Think scene's editor.
///
/// The widget wraps [child] (typically the [EditorView]) with two FABs:
///  • "AI suggestion" — streams advice for the active note via [aiProvider].
///  • "Insert wikilink" — opens a candidate picker; tapping a note appends
///    ` [[Note Title]]` to the active note's content via [knowledgeProvider].
class InlineAIEditor extends ConsumerStatefulWidget {
  final Widget child;

  const InlineAIEditor({super.key, required this.child});

  @override
  ConsumerState<InlineAIEditor> createState() => _InlineAIEditorState();
}

class _InlineAIEditorState extends ConsumerState<InlineAIEditor> {
  bool _showSuggestions = false;
  bool _wikilinkMode = false;

  void _requestSuggestion() {
    final knowledgeState = ref.read(knowledgeProvider);
    final activeNote = knowledgeState.activeNote;
    if (activeNote == null) return;

    ref
        .read(aiProvider.notifier)
        .sendMessage('基于以下笔记内容提供改进建议（简洁地）:\n${activeNote.content}');
    setState(() {
      _showSuggestions = true;
      _wikilinkMode = false;
    });
  }

  void _completeWikilink() {
    final knowledgeState = ref.read(knowledgeProvider);
    final activeNote = knowledgeState.activeNote;
    if (activeNote == null) return;

    setState(() {
      _showSuggestions = true;
      _wikilinkMode = true;
    });
  }

  Future<void> _insertWikilink(Note target) async {
    final knowledgeState = ref.read(knowledgeProvider);
    final activeNote = knowledgeState.activeNote;
    if (activeNote == null) return;

    // Avoid duplicating an existing exact-match wikilink at the end of the note.
    final insertion = ' [[${target.title}]]';
    final newContent = activeNote.content.endsWith(insertion)
        ? activeNote.content
        : '${activeNote.content}$insertion';

    await ref
        .read(knowledgeProvider.notifier)
        .saveNote(
          activeNote.copyWith(content: newContent, modified: DateTime.now()),
        );

    if (!mounted) return;
    setState(() => _showSuggestions = false);
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
                child: const Icon(Icons.link, size: 18),
              ),
            ],
          ),
        ),
        if (_showSuggestions)
          Positioned(
            right: 56,
            bottom: DesignSpacing.lg,
            child: _wikilinkMode
                ? _buildWikilinkPanel(theme, l)
                : _buildSuggestionPanel(theme, l),
          ),
      ],
    );
  }

  Widget _buildSuggestionPanel(ThemeData theme, AppLocalizations l) {
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
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
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

  Widget _buildWikilinkPanel(ThemeData theme, AppLocalizations l) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final activeNote = knowledgeState.activeNote;
    // Exclude the currently-open note from suggestions.
    final candidates = knowledgeState.notes
        .where((n) => n.id != activeNote?.id)
        .toList(growable: false);

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(DesignRadius.md),
      child: Container(
        width: 300,
        height: 280,
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
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    l.insertWikilink,
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
              child: activeNote == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(DesignSpacing.sm),
                        child: Text(
                          'Open a note first',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    )
                  : candidates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(DesignSpacing.sm),
                        child: Text(
                          'No other notes to link',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: candidates.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (ctx, i) {
                        final note = candidates[i];
                        return InkWell(
                          onTap: () => _insertWikilink(note),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignSpacing.sm,
                              vertical: DesignSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 14,
                                  color: theme.hintColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    note.title,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

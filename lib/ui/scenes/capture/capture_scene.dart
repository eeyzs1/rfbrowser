import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/browser_service.dart';
import '../../../services/knowledge_service.dart';
import '../../../services/ai_service.dart';
import '../../../data/models/note.dart';
import '../../widgets/note_sidebar.dart';
import '../../widgets/clip_toolbar.dart';
import '../../widgets/ai_float.dart';
import '../../widgets/resizable_panel.dart';
import '../../pages/browser_page.dart';

enum _RightPanelMode { summary, notePreview }

class CaptureScene extends ConsumerStatefulWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleRightPanel;
  final VoidCallback? onNoteOpened;

  const CaptureScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.onToggleLeftPanel,
    this.onToggleRightPanel,
    this.onNoteOpened,
  });

  @override
  ConsumerState<CaptureScene> createState() => _CaptureSceneState();
}

class _CaptureSceneState extends ConsumerState<CaptureScene> {
  _RightPanelMode _rightPanelMode = _RightPanelMode.summary;

  void _onNotePreview(String noteId) {
    setState(() => _rightPanelMode = _RightPanelMode.notePreview);
    if (!widget.rightPanelExpanded) {
      widget.onToggleRightPanel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(browserProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final theme = Theme.of(context);

    return Stack(
      children: [
        Row(
          children: [
            if (widget.leftPanelExpanded)
              ResizablePanel(
                initialWidth: 240,
                minWidth: 180,
                maxWidth: 400,
                child: NoteSidebar(
                  onNoteOpened: widget.onNoteOpened,
                  onNotePreview: _onNotePreview,
                  onBookmarkOpened: (url) {
                    final bs = ref.read(browserProvider);
                    final existingTab = bs.tabs
                        .where((t) => t.url == url)
                        .firstOrNull;
                    if (existingTab != null) {
                      ref
                          .read(browserProvider.notifier)
                          .setActiveTab(existingTab.id);
                    } else {
                      ref.read(browserProvider.notifier).createTab(url: url);
                    }
                  },
                ),
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
                      border: Border(
                        right: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  const Expanded(child: BrowserView()),
                  const ClipToolbar(),
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
                      border: Border(
                        left: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      size: 14,
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ),
            if (widget.rightPanelExpanded)
              ResizablePanel(
                initialWidth: 280,
                minWidth: 200,
                maxWidth: 450,
                isLeft: false,
                child: _rightPanelMode == _RightPanelMode.notePreview
                    ? _NotePreviewPanel(
                        note: knowledgeState.activeNote,
                        onClose: widget.onToggleRightPanel,
                        onEdit: widget.onNoteOpened,
                        onBack: () => setState(
                          () => _rightPanelMode = _RightPanelMode.summary,
                        ),
                      )
                    : _AiSummaryPanel(
                        url: browserState.activeTab?.url,
                        pageTitle: browserState.activeTab?.title,
                        activeNote: knowledgeState.activeNote,
                        onClose: widget.onToggleRightPanel,
                        onBack: knowledgeState.activeNote != null
                            ? () => setState(
                                () => _rightPanelMode =
                                    _RightPanelMode.notePreview,
                              )
                            : null,
                      ),
              ),
          ],
        ),
        const Positioned.fill(child: AIFloat()),
      ],
    );
  }
}

enum _SummaryMode { idle, loading, done, error }

class _AiSummaryPanel extends ConsumerStatefulWidget {
  final String? url;
  final String? pageTitle;
  final Note? activeNote;
  final VoidCallback? onClose;
  final VoidCallback? onBack;

  const _AiSummaryPanel({
    this.url,
    this.pageTitle,
    this.activeNote,
    this.onClose,
    this.onBack,
  });

  @override
  ConsumerState<_AiSummaryPanel> createState() => _AiSummaryPanelState();
}

class _AiSummaryPanelState extends ConsumerState<_AiSummaryPanel> {
  _SummaryMode _mode = _SummaryMode.idle;
  String? _summary;
  String? _error;
  bool _summarizeNote = false;

  bool get _canSummarize => _summarizeNote
      ? widget.activeNote != null
      : (widget.url != null && widget.url!.isNotEmpty);

  String _sourceLabel(AppLocalizations l) =>
      _summarizeNote ? l.note : l.webPage;

  void _requestSummary() {
    if (!_canSummarize) return;

    setState(() {
      _mode = _SummaryMode.loading;
      _error = null;
    });

    final aiNotifier = ref.read(aiProvider.notifier);

    if (_summarizeNote && widget.activeNote != null) {
      final note = widget.activeNote!;
      aiNotifier.sendMessage(
        'Please summarize the main content and key points of this note in Chinese:\n\nTitle: ${note.title}\n\nContent:\n${note.content}',
        systemPrompt:
            'You are a helpful research assistant. Provide concise, well-structured summaries in Chinese. Focus on key arguments, findings, and insights.',
      );
    } else {
      final pageInfo = '${widget.pageTitle ?? 'Page'}\n${widget.url!}';
      aiNotifier.sendMessage(
        'Please summarize the main content and key points of this web page in Chinese:\n\n$pageInfo',
        systemPrompt:
            'You are a helpful research assistant. Provide concise, well-structured summaries in Chinese. Focus on key arguments, findings, and insights.',
      );
    }
  }

  void _saveAsNote() async {
    if (_summary == null || _summary!.isEmpty) return;
    final l = AppLocalizations.of(context);
    if (l == null) return;
    final title = l.summaryTitle(
      _sourceLabel(l),
      widget.pageTitle ?? widget.activeNote?.title ?? 'Untitled',
    );
    await ref
        .read(knowledgeProvider.notifier)
        .createNote(title: title, content: _summary!);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(l.savedAsNote(title)),
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      _mode = _SummaryMode.idle;
      _summary = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen(aiProvider, (prev, next) {
      final lastMsg = next.messages.isNotEmpty ? next.messages.last : null;
      if (lastMsg != null &&
          lastMsg.role == 'assistant' &&
          !lastMsg.isStreaming) {
        final prevLastMsg = prev?.messages.isNotEmpty == true
            ? prev!.messages.last
            : null;
        if (prevLastMsg != lastMsg) {
          setState(() {
            _summary = lastMsg.content;
            _mode = _SummaryMode.done;
            _error = next.error;
          });
        }
      } else if (next.isLoading &&
          lastMsg != null &&
          lastMsg.role == 'assistant' &&
          lastMsg.isStreaming) {
        setState(() {
          _summary = lastMsg.content;
          _mode = _SummaryMode.loading;
        });
      } else if (!next.isLoading &&
          next.error != null &&
          _mode == _SummaryMode.loading) {
        setState(() {
          _mode = _SummaryMode.error;
          _error = next.error;
        });
      }
    });

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final l = AppLocalizations.of(context);
    if (l == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.aiSourceSummary(_sourceLabel(l)),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_mode == _SummaryMode.idle) _toggleSourceBtn(theme),
          if (_canSummarize && _mode != _SummaryMode.loading)
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              onPressed: _requestSummary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: l.generateSummary,
            ),
          if (_mode == _SummaryMode.done)
            IconButton(
              icon: Icon(
                Icons.save_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              onPressed: _saveAsNote,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: l.saveAsNote,
            ),
          if (_mode == _SummaryMode.done || _mode == _SummaryMode.error)
            IconButton(
              icon: Icon(Icons.arrow_back, size: 16, color: theme.hintColor),
              onPressed: _reset,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: l.goBack,
            ),
          if (widget.onBack != null)
            IconButton(
              icon: Icon(Icons.arrow_back, size: 16, color: theme.hintColor),
              onPressed: widget.onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: l.backToNotePreview,
            ),
          if (widget.onClose != null)
            IconButton(
              icon: Icon(Icons.chevron_right, size: 16, color: theme.hintColor),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: l.closePanel,
            ),
        ],
      ),
    );
  }

  Widget _toggleSourceBtn(ThemeData theme) {
    final l = AppLocalizations.of(context);
    if (l == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: Icon(Icons.swap_horiz, size: 16, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: l.switchSummaryTarget,
      onSelected: (value) {
        setState(() {
          _summarizeNote = value == 'note';
          _reset();
        });
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'page',
          child: Row(
            children: [
              Icon(
                Icons.language,
                size: 14,
                color: !_summarizeNote
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
              const SizedBox(width: 8),
              Text(
                l.webPageSummary,
                style: !_summarizeNote
                    ? TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'note',
          child: Row(
            children: [
              Icon(
                Icons.description,
                size: 14,
                color: _summarizeNote
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
              const SizedBox(width: 8),
              Text(
                l.noteSummary,
                style: _summarizeNote
                    ? TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    final l = AppLocalizations.of(context);
    if (l == null) return const SizedBox.shrink();
    if (!_canSummarize) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _summarizeNote
                    ? Icons.description_outlined
                    : Icons.open_in_browser,
                size: 32,
                color: theme.hintColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                _summarizeNote ? l.selectNoteForSummary : l.openPageForSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_mode == _SummaryMode.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 32,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _requestSummary,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(l.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_mode == _SummaryMode.idle) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.summarize,
                size: 32,
                color: theme.hintColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                l.clickToGenerateSummary(_sourceLabel(l)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _requestSummary,
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: Text(l.generateSourceSummary(_sourceLabel(l))),
              ),
            ],
          ),
        ),
      );
    }

    if (_mode == _SummaryMode.loading &&
        (_summary == null || _summary!.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_summarizeNote && widget.url != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.url!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_summarizeNote && widget.activeNote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.activeNote!.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SelectableText(
            _summary ?? '',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          if (_mode == _SummaryMode.loading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
              ),
            ),
          if (_mode == _SummaryMode.done) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveAsNote,
                icon: const Icon(Icons.save_outlined, size: 14),
                label: Text(l.saveAsNote),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotePreviewPanel extends StatelessWidget {
  final dynamic note;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onBack;

  const _NotePreviewPanel({this.note, this.onClose, this.onEdit, this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    if (l == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.notePreview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onBack != null)
                  IconButton(
                    icon: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: theme.hintColor,
                    ),
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: l.aiSummary,
                  ),
                if (onEdit != null)
                  IconButton(
                    icon: Icon(
                      Icons.edit_note,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: l.editNote,
                  ),
                if (onClose != null)
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: theme.hintColor,
                    ),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: l.closePanel,
                  ),
              ],
            ),
          ),
          Expanded(
            child: note == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 32,
                          color: theme.hintColor.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.clickNoteToPreview,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title ?? '',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (note.tags != null && note.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            children: note.tags
                                .map<Widget>(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const Divider(height: 20),
                        Text(
                          note.content ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_note, size: 16),
                            label: Text(l.openInEditor),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

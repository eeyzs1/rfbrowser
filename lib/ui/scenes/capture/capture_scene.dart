import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/browser_service.dart';
import '../../../services/knowledge_service.dart';
import '../../../services/ai_service.dart';
import '../../../data/models/note.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/note_sidebar.dart';
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

    return Stack(
      children: [
        Row(
          children: [
            AnimatedSize(
              duration: DesignDuration.panelSlide,
              curve: Curves.easeInOut,
              alignment: Alignment.centerLeft,
              child: widget.leftPanelExpanded
                  ? ResizablePanel(
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
                    )
                  : const SizedBox.shrink(),
            ),
            if (!widget.leftPanelExpanded)
              _PanelCollapseButton(
                alignment: Alignment.centerLeft,
                icon: Icons.chevron_right,
                onTap: widget.onToggleLeftPanel,
              ),
            Expanded(child: BrowserView()),
            if (!widget.rightPanelExpanded)
              _PanelCollapseButton(
                alignment: Alignment.centerRight,
                icon: Icons.chevron_left,
                onTap: widget.onToggleRightPanel,
              ),
            AnimatedSize(
              duration: DesignDuration.panelSlide,
              curve: Curves.easeInOut,
              alignment: Alignment.centerRight,
              child: widget.rightPanelExpanded
                  ? ResizablePanel(
                      initialWidth: 320,
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
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const Positioned.fill(child: AIFloat()),
      ],
    );
  }
}

class _PanelCollapseButton extends StatefulWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback? onTap;

  const _PanelCollapseButton({
    required this.alignment,
    required this.icon,
    this.onTap,
  });

  @override
  State<_PanelCollapseButton> createState() => _PanelCollapseButtonState();
}

class _PanelCollapseButtonState extends State<_PanelCollapseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: _isHovered
          ? DesignColors.primaryHover
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (hovered) => setState(() => _isHovered = hovered),
        child: Container(
          width: DesignTouchTarget.panelCollapseWidth,
          constraints: const BoxConstraints(minHeight: DesignTouchTarget.minSize),
          alignment: widget.alignment,
          decoration: BoxDecoration(
            border: Border(
              left: widget.alignment == Alignment.centerRight
                  ? BorderSide(color: theme.dividerColor)
                  : BorderSide.none,
              right: widget.alignment == Alignment.centerLeft
                  ? BorderSide(color: theme.dividerColor)
                  : BorderSide.none,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered ? theme.colorScheme.primary : theme.hintColor,
          ),
        ),
      ),
    );
  }
}

enum _SummaryMode { idle, loading, done, error }

enum _ErrorType { network, rateLimit, noContent, unknown }

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
  _ErrorType _errorType = _ErrorType.unknown;
  bool _summarizeNote = false;

  bool get _canSummarize => _summarizeNote
      ? widget.activeNote != null
      : (widget.url != null && widget.url!.isNotEmpty);

  String _sourceLabel(AppLocalizations l) =>
      _summarizeNote ? l.note : l.webPage;

  _ErrorType _classifyError(String? error) {
    if (error == null) return _ErrorType.unknown;
    final lower = error.toLowerCase();
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('socket')) {
      return _ErrorType.network;
    }
    if (lower.contains('rate') ||
        lower.contains('limit') ||
        lower.contains('429') ||
        lower.contains('quota')) {
      return _ErrorType.rateLimit;
    }
    if (lower.contains('empty') ||
        lower.contains('no content') ||
        lower.contains('no text')) {
      return _ErrorType.noContent;
    }
    return _ErrorType.unknown;
  }

  String _errorRecoveryHint(AppLocalizations l) {
    return switch (_errorType) {
      _ErrorType.network => l.errorNetworkHint,
      _ErrorType.rateLimit => l.errorRateLimitHint,
      _ErrorType.noContent => l.errorNoContentHint,
      _ErrorType.unknown => l.errorUnknownHint,
    };
  }

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
          _errorType = _classifyError(next.error);
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
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.md,
        vertical: DesignSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: DesignSpacing.sm),
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
                size: 18,
                color: theme.colorScheme.primary,
              ),
              onPressed: _requestSummary,
              tooltip: l.generateSummary,
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
          if (_mode == _SummaryMode.done)
            IconButton(
              icon: Icon(
                Icons.save,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              onPressed: _saveAsNote,
              tooltip: l.saveAsNote,
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
          if (_mode == _SummaryMode.done || _mode == _SummaryMode.error)
            IconButton(
              icon: Icon(Icons.arrow_back, size: 18, color: theme.hintColor),
              onPressed: _reset,
              tooltip: l.goBack,
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
          if (widget.onBack != null)
            IconButton(
              icon: Icon(Icons.arrow_back, size: 18, color: theme.hintColor),
              onPressed: widget.onBack,
              tooltip: l.backToNotePreview,
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
          if (widget.onClose != null)
            IconButton(
              icon: Icon(Icons.chevron_right, size: 18, color: theme.hintColor),
              onPressed: widget.onClose,
              tooltip: l.closePanel,
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
        ],
      ),
    );
  }

  Widget _toggleSourceBtn(ThemeData theme) {
    final l = AppLocalizations.of(context);
    if (l == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: Icon(Icons.swap_horiz, size: 18, color: theme.hintColor),
      tooltip: l.switchSummaryTarget,
      constraints: const BoxConstraints(
        minWidth: DesignTouchTarget.iconButtonSize,
        minHeight: DesignTouchTarget.iconButtonSize,
      ),
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
                size: 16,
                color: !_summarizeNote
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
              const SizedBox(width: DesignSpacing.sm),
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
                size: 16,
                color: _summarizeNote
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
              const SizedBox(width: DesignSpacing.sm),
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
          padding: const EdgeInsets.all(DesignSpacing.lg),
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
              const SizedBox(height: DesignSpacing.sm),
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
          padding: const EdgeInsets.all(DesignSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 32,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: DesignSpacing.sm),
              Text(
                _error ?? 'Unknown error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: DesignSpacing.sm),
              Text(
                _errorRecoveryHint(l),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignSpacing.md),
              OutlinedButton.icon(
                onPressed: _requestSummary,
                icon: const Icon(Icons.refresh, size: 16),
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
          padding: const EdgeInsets.all(DesignSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.summarize,
                size: 32,
                color: theme.hintColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: DesignSpacing.sm),
              Text(
                l.clickToGenerateSummary(_sourceLabel(l)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignSpacing.md),
              FilledButton.icon(
                onPressed: _requestSummary,
                icon: const Icon(Icons.auto_awesome, size: 16),
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
      padding: const EdgeInsets.all(DesignSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_summarizeNote && widget.url != null)
            Padding(
              padding: const EdgeInsets.only(bottom: DesignSpacing.sm),
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
              padding: const EdgeInsets.only(bottom: DesignSpacing.sm),
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
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          if (_mode == _SummaryMode.loading)
            Padding(
              padding: const EdgeInsets.only(top: DesignSpacing.sm),
              child: LinearProgressIndicator(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
              ),
            ),
          if (_mode == _SummaryMode.done) ...[
            const SizedBox(height: DesignSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveAsNote,
                icon: const Icon(Icons.save, size: 16),
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
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.md,
              vertical: DesignSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: DesignSpacing.sm),
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
                      size: 18,
                      color: theme.hintColor,
                    ),
                    onPressed: onBack,
                    tooltip: l.aiSummary,
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                  ),
                if (onEdit != null)
                  IconButton(
                    icon: Icon(
                      Icons.edit_note,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: onEdit,
                    tooltip: l.editNote,
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                  ),
                if (onClose != null)
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.hintColor,
                    ),
                    onPressed: onClose,
                    tooltip: l.closePanel,
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
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
                        const SizedBox(height: DesignSpacing.sm),
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
                    padding: const EdgeInsets.all(DesignSpacing.md),
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
                          const SizedBox(height: DesignSpacing.sm),
                          Wrap(
                            spacing: DesignSpacing.xs,
                            children: note.tags
                                .map<Widget>(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DesignSpacing.sm,
                                      vertical: DesignSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        DesignRadius.sm,
                                      ),
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
                        const SizedBox(height: DesignSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_note, size: 18),
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

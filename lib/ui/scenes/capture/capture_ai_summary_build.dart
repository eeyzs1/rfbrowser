// ignore_for_file: unused_element, unused_element_parameter
part of 'capture_scene.dart';

/// Build methods for the AI summary panel.
mixin _AiSummaryPanelBuildMixin on _AiSummaryPanelBase {
  Widget buildAiSummaryPanel(BuildContext context) {
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
          setSummaryState(
            mode: _SummaryMode.done,
            text: lastMsg.content,
            error: next.error,
          );
        }
      } else if (next.isLoading &&
          lastMsg != null &&
          lastMsg.role == 'assistant' &&
          lastMsg.isStreaming) {
        setSummaryState(
          mode: _SummaryMode.loading,
          text: lastMsg.content,
        );
      } else if (!next.isLoading &&
          next.error != null &&
          summaryMode == _SummaryMode.loading) {
        setSummaryState(
          mode: _SummaryMode.error,
          error: next.error,
          errorType: classifyError(next.error),
        );
      }
    });

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          buildHeader(theme),
          Expanded(child: buildContent(theme)),
        ],
      ),
    );
  }

  Widget buildHeader(ThemeData theme) {
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
              l.aiSourceSummary(sourceLabel(l)),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (summaryMode == _SummaryMode.idle) buildToggleSourceBtn(theme),
          if (canSummarize && summaryMode != _SummaryMode.loading)
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              onPressed: requestSummary,
              tooltip: l.generateSummary,
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
          if (summaryMode == _SummaryMode.done)
            IconButton(
              icon: Icon(
                Icons.save,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              onPressed: saveAsNote,
              tooltip: l.saveAsNote,
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
          if (summaryMode == _SummaryMode.done ||
              summaryMode == _SummaryMode.error)
            IconButton(
              icon: Icon(Icons.arrow_back, size: 18, color: theme.hintColor),
              onPressed: reset,
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

  Widget buildToggleSourceBtn(ThemeData theme) {
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
        setSummarizeNote(value == 'note');
        reset();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'page',
          child: Row(
            children: [
              Icon(
                Icons.language,
                size: 16,
                color: !summarizeNote
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(
                l.webPageSummary,
                style: !summarizeNote
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
                color: summarizeNote
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(
                l.noteSummary,
                style: summarizeNote
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

  Widget buildContent(ThemeData theme) {
    final l = AppLocalizations.of(context);
    if (l == null) return const SizedBox.shrink();
    if (!canSummarize) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                summarizeNote
                    ? Icons.description_outlined
                    : Icons.open_in_browser,
                size: 32,
                color: theme.hintColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: DesignSpacing.sm),
              Text(
                summarizeNote ? l.selectNoteForSummary : l.openPageForSummary,
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

    if (summaryMode == _SummaryMode.error) {
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
                summaryError ?? 'Unknown error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: DesignSpacing.sm),
              Text(
                errorRecoveryHint(l),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignSpacing.md),
              OutlinedButton.icon(
                onPressed: requestSummary,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (summaryMode == _SummaryMode.idle) {
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
                l.clickToGenerateSummary(sourceLabel(l)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignSpacing.md),
              FilledButton.icon(
                onPressed: requestSummary,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(l.generateSourceSummary(sourceLabel(l))),
              ),
            ],
          ),
        ),
      );
    }

    if (summaryMode == _SummaryMode.loading &&
        (summaryText == null || summaryText!.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!summarizeNote && widget.url != null)
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
          if (summarizeNote && widget.activeNote != null)
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
            summaryText ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          if (summaryMode == _SummaryMode.loading)
            Padding(
              padding: const EdgeInsets.only(top: DesignSpacing.sm),
              child: LinearProgressIndicator(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
              ),
            ),
          if (summaryMode == _SummaryMode.done) ...[
            const SizedBox(height: DesignSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saveAsNote,
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

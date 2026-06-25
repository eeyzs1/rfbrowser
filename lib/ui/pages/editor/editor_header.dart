// ignore_for_file: unused_element, unused_element_parameter

part of '../editor_page.dart';

mixin _EditorHeaderMixin on _EditorViewStateBase {
  @override
  Widget _buildHeader(ThemeData theme, dynamic note, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.md,
        vertical: DesignSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.tags != null && note.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 4,
                      children: note.tags
                          .take(5)
                          .map<Widget>(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 0,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '#$tag',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          if (_isDirty)
            Padding(
              padding: const EdgeInsets.only(right: DesignSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignSpacing.sm,
                  vertical: DesignSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: DesignColors.semanticWarning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l.unsaved,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: DesignColors.semanticWarning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_showSavedIndicator)
            Padding(
              padding: const EdgeInsets.only(right: DesignSpacing.sm),
              child: AnimatedOpacity(
                opacity: _showSavedIndicator ? 1.0 : 0.0,
                duration: DesignDuration.toastHide,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignSpacing.sm,
                    vertical: DesignSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: DesignColors.semanticSuccess.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DesignRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: DesignColors.semanticSuccess,
                      ),
                      const SizedBox(width: DesignSpacing.xs),
                      Text(
                        l.saved,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: DesignColors.semanticSuccess,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (note.rawHtmlPath != null || note.sourceUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: DesignSpacing.xs),
              child: Tooltip(
                message: l.viewOriginalPage,
                child: IconButton(
                  icon: const Icon(Icons.language, size: 16),
                  onPressed: () => _switchViewMode(
                    _viewMode == _EditorViewMode.original
                        ? _EditorViewMode.edit
                        : _EditorViewMode.original,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: DesignTouchTarget.iconButtonSize,
                    minHeight: DesignTouchTarget.iconButtonSize,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _viewMode == _EditorViewMode.original
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : null,
                    foregroundColor: _viewMode == _EditorViewMode.original
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
          if (note.screenshotPath != null)
            Padding(
              padding: const EdgeInsets.only(right: DesignSpacing.xs),
              child: Tooltip(
                message: l.viewScreenshot,
                child: IconButton(
                  icon: const Icon(Icons.screenshot, size: 16),
                  onPressed: () => _showScreenshot(note),
                  constraints: const BoxConstraints(
                    minWidth: DesignTouchTarget.iconButtonSize,
                    minHeight: DesignTouchTarget.iconButtonSize,
                  ),
                ),
              ),
            ),
          SegmentedButton<_EditorViewMode>(
            segments: [
              ButtonSegment(
                value: _EditorViewMode.edit,
                label: Text(l.editMode),
                icon: Icon(Icons.edit, size: 14),
              ),
              ButtonSegment(
                value: _EditorViewMode.preview,
                label: Text(l.previewMode),
                icon: Icon(Icons.visibility, size: 14),
              ),
              ButtonSegment(
                value: _EditorViewMode.split,
                label: Text(l.splitView),
                icon: Icon(Icons.vertical_split, size: 14),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (modes) => _switchViewMode(modes.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(theme.textTheme.labelSmall),
              padding: WidgetStatePropertyAll(
                const EdgeInsets.symmetric(
                  horizontal: DesignSpacing.sm,
                  vertical: DesignSpacing.xs,
                ),
              ),
            ),
          ),
          const SizedBox(width: DesignSpacing.xs),
          IconButton(
            icon: const Icon(Icons.save, size: 16),
            onPressed: _isDirty ? _saveNote : null,
            tooltip: l.save,
            constraints: const BoxConstraints(
              minWidth: DesignTouchTarget.iconButtonSize,
              minHeight: DesignTouchTarget.iconButtonSize,
            ),
          ),
        ],
      ),
    );
  }
}

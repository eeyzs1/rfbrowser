// ignore_for_file: unused_element, unused_element_parameter
part of 'capture_scene.dart';

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
      color: _isHovered ? DesignColors.primaryHover : theme.colorScheme.surface,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (hovered) => setState(() => _isHovered = hovered),
        child: Container(
          width: DesignTouchTarget.panelCollapseWidth,
          constraints: const BoxConstraints(
            minHeight: DesignTouchTarget.minSize,
          ),
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

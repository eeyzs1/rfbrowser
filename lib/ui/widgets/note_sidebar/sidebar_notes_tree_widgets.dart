part of '../note_sidebar.dart';

/// Widget builders for the notes tree: folder rows and note rows.
///
/// [_noteFolderRow] and [_noteRow] used to be inline functions on the
/// sidebar state that called the PARENT `setState` on every hover
/// enter/exit, rebuilding all ~5000 row widgets. They are now small
/// [StatefulWidget]s that manage their own hover state locally, so a
/// hover change only rebuilds the single affected row.

/// Small icon button used inside folder/note rows. Mirrors the `_ib`
/// helper on `_NoteSidebarStateBase` but as a top-level function so the
/// row [StatefulWidget]s (which are not mixins) can use it.
Widget _rowIconButton(
  BuildContext context,
  IconData icon,
  VoidCallback? onPressed,
  String tooltip,
) {
  return IconButton(
    icon: Icon(
      icon,
      size: 12,
      color: Theme.of(context).hintColor.withValues(alpha: 0.7),
    ),
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    tooltip: tooltip,
  );
}

/// A single folder row in the notes tree. Hover state is local so it
/// never triggers a full sidebar rebuild.
class _NoteFolderRow extends StatefulWidget {
  final String name;
  final int depth;
  final bool isExpanded;
  final bool isRoot;
  final int noteCount;
  final String folderPath;
  final bool hasChildren;
  final AppLocalizations l;
  final double baseFontSize;
  final bool isDraggingNote;
  final VoidCallback onToggle;
  final VoidCallback onNewNote;
  final VoidCallback onNewFolder;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final ValueChanged<String> onAcceptNote;

  const _NoteFolderRow({
    required this.name,
    required this.depth,
    required this.isExpanded,
    required this.isRoot,
    required this.noteCount,
    required this.folderPath,
    required this.hasChildren,
    required this.l,
    required this.baseFontSize,
    required this.isDraggingNote,
    required this.onToggle,
    required this.onNewNote,
    required this.onNewFolder,
    this.onRename,
    this.onDelete,
    required this.onAcceptNote,
  });

  @override
  State<_NoteFolderRow> createState() => _NoteFolderRowState();
}

class _NoteFolderRowState extends State<_NoteFolderRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => widget.isDraggingNote,
      onAcceptWithDetails: (details) => widget.onAcceptNote(details.data),
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onSecondaryTapUp: (d) => _showFolderContextMenu(
              context,
              d.globalPosition,
              widget.onNewNote,
              widget.onNewFolder,
              widget.onRename,
              widget.onDelete,
              widget.l,
            ),
            child: Container(
              padding: EdgeInsets.only(left: widget.depth * 14.0 + 4.0),
              color: isDragOver
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : _isHovered
                      ? theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3)
                      : null,
              child: InkWell(
                onTap: widget.onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isExpanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 14,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        widget.isExpanded
                            ? Icons.folder_open
                            : Icons.folder,
                        size: 15,
                        color: widget.isRoot
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary
                                .withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.isRoot && widget.name.isEmpty
                              ? 'Vault'
                              : widget.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: widget.baseFontSize,
                            fontWeight: FontWeight.w600,
                            color: widget.isRoot
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isHovered && !widget.isRoot) ...[
                        _rowIconButton(
                          context,
                          Icons.edit_outlined,
                          widget.onRename,
                          widget.l.rename,
                        ),
                        _rowIconButton(
                          context,
                          Icons.delete_outline,
                          widget.onDelete,
                          widget.l.delete,
                        ),
                      ],
                      if (_isHovered) ...[
                        _rowIconButton(
                          context,
                          Icons.add,
                          widget.onNewNote,
                          widget.l.newNote,
                        ),
                        _rowIconButton(
                          context,
                          Icons.create_new_folder,
                          widget.onNewFolder,
                          widget.l.newSubfolder,
                        ),
                      ],
                      if (!_isHovered && widget.noteCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${widget.noteCount}',
                            style: TextStyle(
                              fontSize: widget.baseFontSize - 2,
                              color:
                                  theme.hintColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A single note row in the notes tree. Hover state is local so it
/// never triggers a full sidebar rebuild.
class _NoteRow extends StatefulWidget {
  final Note note;
  final int depth;
  final bool isActive;
  final AppLocalizations l;
  final double baseFontSize;
  final VoidCallback onTap;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  const _NoteRow({
    required this.note,
    required this.depth,
    required this.isActive,
    required this.l,
    required this.baseFontSize,
    required this.onTap,
    required this.onMove,
    required this.onDelete,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  @override
  State<_NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<_NoteRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Draggable<String>(
      data: widget.note.id,
      onDragStarted: widget.onDragStarted,
      onDragEnd: (_) => widget.onDragEnd(),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.sm,
            vertical: DesignSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.note.title,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontSize: widget.baseFontSize),
              ),
            ],
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          padding: EdgeInsets.only(left: widget.depth * 14.0 + 4.0),
          color: widget.isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DesignSpacing.xs,
                horizontal: DesignSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: widget.isActive
                        ? theme.colorScheme.primary
                        : theme.hintColor,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.note.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: widget.baseFontSize,
                        color: widget.isActive
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight:
                            widget.isActive ? FontWeight.w600 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isHovered) ...[
                    _rowIconButton(
                      context,
                      Icons.drive_file_move_outline,
                      widget.onMove,
                      widget.l.move,
                    ),
                    _rowIconButton(
                      context,
                      Icons.close,
                      widget.onDelete,
                      widget.l.delete,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the folder right-click context menu. Top-level so the
/// [_NoteFolderRow] widget (which is not a mixin) can call it.
void _showFolderContextMenu(
  BuildContext context,
  Offset pos,
  VoidCallback onNewNote,
  VoidCallback onNewFolder,
  VoidCallback? onRename,
  VoidCallback? onDelete,
  AppLocalizations l,
) {
  final theme = Theme.of(context);
  final items = <PopupMenuEntry<String>>[
    PopupMenuItem(
      value: 'new_note',
      child: Row(
        children: [
          Icon(Icons.add, size: 14, color: theme.hintColor),
          const SizedBox(width: 8),
          Text(l.newNote),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'new_folder',
      child: Row(
        children: [
          Icon(Icons.create_new_folder, size: 14, color: theme.hintColor),
          const SizedBox(width: 8),
          Text(l.newSubfolder),
        ],
      ),
    ),
  ];
  if (onRename != null) {
    items.add(
      PopupMenuItem(
        value: 'rename',
        child: Row(
          children: [
            Icon(Icons.edit, size: 14, color: theme.hintColor),
            const SizedBox(width: 8),
            Text(l.rename),
          ],
        ),
      ),
    );
  }
  if (onDelete != null) {
    items.add(const PopupMenuDivider());
    items.add(
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(
              Icons.delete_outline,
              size: 14,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              l.delete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
    items: items,
  ).then((v) {
    switch (v) {
      case 'new_note':
        onNewNote();
      case 'new_folder':
        onNewFolder();
      case 'rename':
        onRename?.call();
      case 'delete':
        onDelete?.call();
    }
  });
}

part of '../note_sidebar.dart';

/// Widget builders for the notes tree: folder rows, note rows, and the
/// folder context menu. Extracted into its own part file because the
/// drag-and-drop + hover-state UI makes them the largest chunk of the
/// tree renderer.
mixin _SidebarNotesTreeWidgetsMixin on _NoteSidebarStateBase {
  Widget _noteFolderRow({
    required String name,
    required int depth,
    required bool isExpanded,
    required bool isRoot,
    required int noteCount,
    required String folderPath,
    required AppLocalizations l,
    required VoidCallback onToggle,
    required VoidCallback onNewNote,
    required VoidCallback onNewFolder,
    VoidCallback? onRename,
    VoidCallback? onDelete,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => _draggingNoteId != null,
      onAcceptWithDetails: (details) {
        if (_draggingNoteId != null) {
          ref
              .read(knowledgeProvider.notifier)
              .moveNote(_draggingNoteId!, folderPath)
              .then((_) {
                _scanDiskFolders();
              });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;
        final theme = Theme.of(context);
        final isHovered = _hoveredNoteFolder == folderPath;
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredNoteFolder = folderPath),
          onExit: (_) => setState(() => _hoveredNoteFolder = null),
          child: GestureDetector(
            onSecondaryTapUp: (d) => _showFolderContextMenu(
              d.globalPosition,
              onNewNote,
              onNewFolder,
              onRename,
              onDelete,
              l,
            ),
            child: Container(
              padding: EdgeInsets.only(left: depth * 14.0 + 4.0),
              color: isDragOver
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : isHovered
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    )
                  : null,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_more : Icons.chevron_right,
                        size: 14,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        isExpanded ? Icons.folder_open : Icons.folder,
                        size: 15,
                        color: isRoot
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          isRoot && name.isEmpty ? 'Vault' : name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: _baseFontSize,
                            fontWeight: FontWeight.w600,
                            color: isRoot ? theme.colorScheme.primary : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHovered && !isRoot) ...[
                        _ib(Icons.edit_outlined, onRename, l.rename),
                        _ib(Icons.delete_outline, onDelete, l.delete),
                      ],
                      if (isHovered) ...[
                        _ib(Icons.add, onNewNote, l.newNote),
                        _ib(
                          Icons.create_new_folder,
                          onNewFolder,
                          l.newSubfolder,
                        ),
                      ],
                      if (!isHovered && noteCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '$noteCount',
                            style: TextStyle(
                              fontSize: _baseFontSize - 2,
                              color: theme.hintColor.withValues(alpha: 0.6),
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

  Widget _noteRow(
    Note note,
    int depth,
    bool isActive,
    bool isHovered,
    AppLocalizations l,
  ) {
    return Draggable<String>(
      data: note.id,
      onDragStarted: () => setState(() => _draggingNoteId = note.id),
      onDragEnd: (_) => setState(() => _draggingNoteId = null),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.sm,
            vertical: DesignSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                note.title,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: _baseFontSize),
              ),
            ],
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredNoteId = note.id),
        onExit: (_) => setState(() => _hoveredNoteId = null),
        child: Container(
          padding: EdgeInsets.only(left: depth * 14.0 + 4.0),
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : null,
          child: InkWell(
            onTap: () {
              ref.read(knowledgeProvider.notifier).openNote(note.id);
              if (widget.onNotePreview != null) {
                widget.onNotePreview!(note.id);
              } else {
                widget.onNoteOpened?.call();
              }
            },
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
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: _baseFontSize,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: isActive ? FontWeight.w600 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isHovered) ...[
                    _ib(
                      Icons.drive_file_move_outline,
                      () => _showMoveNoteDialog(note),
                      l.move,
                    ),
                    _ib(
                      Icons.close,
                      () => _confirmDeleteNote(note.title, note.id),
                      l.delete,
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

  void _showFolderContextMenu(
    Offset pos,
    VoidCallback onNewNote,
    VoidCallback onNewFolder,
    VoidCallback? onRename,
    VoidCallback? onDelete,
    AppLocalizations l,
  ) {
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: 'new_note',
        child: Row(
          children: [
            Icon(Icons.add, size: 14, color: Theme.of(context).hintColor),
            const SizedBox(width: 8),
            Text(l.newNote),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'new_folder',
        child: Row(
          children: [
            Icon(
              Icons.create_new_folder,
              size: 14,
              color: Theme.of(context).hintColor,
            ),
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
              Icon(Icons.edit, size: 14, color: Theme.of(context).hintColor),
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
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                l.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
}

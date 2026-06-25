part of '../canvas_page.dart';

/// Canvas background context menu (right-click on empty canvas) for adding
/// new cards (note, text, image, link, container, from-knowledge-note) and
/// performing operations on the current selection (edit, duplicate, delete).
mixin _CanvasContextMenuCardsMixin on _CanvasViewStateBase {
  @override
  void _showContextMenu(
    BuildContext context,
    TapUpDetails details,
    CanvasData canvasData,
    Offset worldPos,
  ) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx + 1,
        details.globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'note',
          child: Row(
            children: [
              Icon(
                Icons.description,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l.noteCard),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'text',
          child: Row(
            children: [
              Icon(
                Icons.text_fields,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l.textCard),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              Icon(Icons.image, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(l.imageCard),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'link',
          child: Row(
            children: [
              Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(l.linkCard),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'container',
          child: Row(
            children: [
              Icon(
                Icons.crop_square,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l.container),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'fromNote',
          child: Row(
            children: [
              Icon(
                Icons.library_books,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l.fromKnowledgeNote),
            ],
          ),
        ),
        if (canvasData.selectedCardIds.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.editCard),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(
                  Icons.content_copy,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l.duplicateCard),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(l.deleteCard),
              ],
            ),
          ),
        ],
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'note':
          _addCardAt(worldPos, type: CanvasCardType.note);
        case 'text':
          _addCardAt(worldPos, type: CanvasCardType.text);
        case 'image':
          _addCardAt(worldPos, type: CanvasCardType.image);
        case 'link':
          _addCardAt(worldPos, type: CanvasCardType.link);
        case 'container':
          _addContainerAt(worldPos);
        case 'fromNote':
          _addCardFromNote(worldPos);
        case 'edit':
          if (canvasData.selectedCardIds.isNotEmpty) {
            _startInlineEditing(canvasData.selectedCardIds.first);
          }
        case 'duplicate':
          if (canvasData.selectedCardIds.isNotEmpty) {
            _duplicateCard(canvasData.selectedCardIds.first, worldPos);
          }
        case 'delete':
          _deleteSelectedCards();
      }
    });
  }
}

part of '../card_properties_panel.dart';

/// Info and action buttons section: size, note, connections, edit, duplicate, delete.
mixin _ActionButtonsMixin on _CardPropertiesPanelBase {
  Widget buildSizeSection(ThemeData theme, CanvasCard card) {
    return propSection(
      theme,
      'Size',
      Text(
        '${card.width.round()} × ${card.height.round()}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget buildNoteSection(ThemeData theme, CanvasCard card) {
    return propSection(
      theme,
      'Note',
      Text(
        card.noteId!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.hintColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget buildConnectionsSection(
    ThemeData theme,
    AppLocalizations l,
    List<CanvasConnection> connections,
  ) {
    return propSection(
      theme,
      l.backlinks,
      Text('${connections.length}', style: theme.textTheme.bodySmall),
    );
  }

  Widget buildEditDuplicateButtons(
    ThemeData theme,
    AppLocalizations l,
    WidgetRef ref,
    CanvasCard card,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => ref
                .read(canvasProvider.notifier)
                .startInlineEditing(card.id),
            icon: Icon(Icons.edit, size: 14),
            label: Text(l.editCard),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              minimumSize: Size.zero,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              final newCard = CanvasCard(
                id: 'card_${DateTime.now().millisecondsSinceEpoch}',
                type: card.type,
                x: card.x + 40,
                y: card.y + 40,
                width: card.width,
                height: card.height,
                title: card.title,
                content: card.content,
                colorValue: card.colorValue,
                fontSize: card.fontSize,
                style: card.style,
              );
              ref.read(canvasProvider.notifier).addCard(newCard);
              ref.read(canvasProvider.notifier).selectCard(newCard.id);
            },
            icon: Icon(Icons.content_copy, size: 14),
            label: Text(l.duplicateCard),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              minimumSize: Size.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDeleteButton(
    ThemeData theme,
    AppLocalizations l,
    WidgetRef ref,
    CanvasCard card,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(canvasProvider.notifier).removeCard(card.id);
          ref.read(canvasProvider.notifier).selectCard(null);
        },
        icon: Icon(
          Icons.delete_outline,
          size: 14,
          color: theme.colorScheme.error,
        ),
        label: Text(l.deleteCard),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
        ),
      ),
    );
  }
}

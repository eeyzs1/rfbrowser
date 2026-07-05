part of '../card_properties_panel.dart';

/// Basic properties section: header, title, font size, card color.
mixin _BasicPropertiesMixin on _CardPropertiesPanelBase {
  Widget buildHeader(ThemeData theme, WidgetRef ref, CanvasCard card) {
    return Row(
      children: [
        Icon(
          cardTypeIcon(card.type),
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          card.type.label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            ref.read(canvasProvider.notifier).finishInlineEditing();
            ref.read(canvasProvider.notifier).selectCard(null);
            onClose();
          },
          child: Icon(Icons.close, size: 14, color: theme.hintColor),
        ),
      ],
    );
  }

  Widget buildTitleSection(
    ThemeData theme,
    AppLocalizations l,
    CanvasCard card,
  ) {
    return propSection(
      theme,
      l.noteTitle,
      Text(
        card.title.isEmpty ? l.untagged : card.title,
        style: theme.textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget buildFontSizeSection(
    ThemeData theme,
    AppLocalizations l,
    WidgetRef ref,
    CanvasCard card,
    AppSettings settings,
    double cardFontSize,
  ) {
    return propSection(
      theme,
      l.fontSize,
      Row(
        children: [
          Expanded(
            child: Slider(
              value: cardFontSize,
              min: 8,
              max: 32,
              divisions: 24,
              label: cardFontSize.round().toString(),
              onChanged: (v) {
                final defaultSize = settings.editorFontSize * 0.85;
                ref
                    .read(canvasProvider.notifier)
                    .updateCard(
                      card.copyWith(
                        fontSize: (v - defaultSize).abs() < 0.5 ? 0 : v,
                      ),
                    );
              },
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              cardFontSize.round().toString(),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCardColorSection(
    ThemeData theme,
    AppLocalizations l,
    WidgetRef ref,
    CanvasCard card,
  ) {
    return propSection(
      theme,
      l.cardColor,
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: _cardColorPresets
            .map(
              (color) => GestureDetector(
                onTap: () => ref
                    .read(canvasProvider.notifier)
                    .updateCard(card.copyWith(colorValue: color.toARGB32())),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: card.colorValue == color.toARGB32()
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      width: card.colorValue == color.toARGB32() ? 2 : 0.5,
                    ),
                  ),
                  child: card.colorValue == color.toARGB32()
                      ? Icon(
                          Icons.check,
                          size: 12,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

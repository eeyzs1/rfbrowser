import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/services/canvas_service.dart';
import 'package:rfbrowser/services/settings_service.dart';

const List<Color> _cardColorPresets = [
  Color(0xFFFFFFFF),
  Color(0xFFE3F2FD),
  Color(0xFFE8F5E9),
  Color(0xFFFFF3E0),
  Color(0xFFFCE4EC),
  Color(0xFFF3E5F5),
  Color(0xFFE0F7FA),
  Color(0xFFFFEBEE),
  Color(0xFFF1F8E9),
  Color(0xFFEDE7F6),
];

const List<Color> _borderColorPresets = [
  Color(0xFFE0E0E0),
  Color(0xFF90CAF9),
  Color(0xFFA5D6A7),
  Color(0xFFFFCC80),
  Color(0xFFEF9A9A),
  Color(0xFFCE93D8),
  Color(0xFF80DEEA),
  Color(0xFFE0E0E0),
  Color(0xFF000000),
  Color(0xFFFFFFFF),
];

class CardPropertiesPanel extends ConsumerWidget {
  final VoidCallback onClose;

  const CardPropertiesPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final canvasData = ref.watch(canvasProvider);
    final selectedIds = canvasData.selectedCardIds;
    if (selectedIds.isEmpty) return const SizedBox.shrink();
    final selectedId = selectedIds.first;
    final card = canvasData.cards.where((c) => c.id == selectedId).firstOrNull;
    if (card == null) return const SizedBox.shrink();

    final settings = ref.watch(settingsProvider);
    final cardFontSize = card.fontSize > 0
        ? card.fontSize
        : settings.editorFontSize * 0.85;
    final connections = canvasData.connections
        .where((c) => c.fromCardId == card.id || c.toCardId == card.id)
        .toList();
    final s = card.style ?? CanvasCardStyle.defaults;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Icon(
              _cardTypeIcon(card.type),
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
        ),
        const SizedBox(height: 12),
        _propSection(
          theme,
          l.noteTitle,
          Text(
            card.title.isEmpty ? l.untagged : card.title,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        _propSection(
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
        ),
        const SizedBox(height: 8),
        _propSection(
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
                        .updateCard(
                          card.copyWith(colorValue: color.toARGB32()),
                        ),
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
        ),
        const SizedBox(height: 12),
        _sectionDivider(theme),
        const SizedBox(height: 8),
        Text(
          'Style',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _propSection(
          theme,
          'Border Color',
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _borderColorPresets
                .map(
                  (color) => GestureDetector(
                    onTap: () => ref
                        .read(canvasProvider.notifier)
                        .updateCard(
                          card.copyWith(
                            style: s.copyWith(borderColor: color.toARGB32()),
                          ),
                        ),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: s.borderColor == color.toARGB32()
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          width: s.borderColor == color.toARGB32() ? 2 : 0.5,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        _propSection(
          theme,
          'Border Width',
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: s.borderWidth,
                  min: 0,
                  max: 4,
                  divisions: 8,
                  label: s.borderWidth.toStringAsFixed(1),
                  onChanged: (v) => ref
                      .read(canvasProvider.notifier)
                      .updateCard(
                        card.copyWith(style: s.copyWith(borderWidth: v)),
                      ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  s.borderWidth.toStringAsFixed(1),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _propSection(
          theme,
          'Border Style',
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: CardBorderStyle.values
                  .map(
                    (bs) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(
                          bs.name,
                          style: theme.textTheme.labelSmall,
                        ),
                        selected: s.borderStyle == bs,
                        onSelected: (_) => ref
                            .read(canvasProvider.notifier)
                            .updateCard(
                              card.copyWith(style: s.copyWith(borderStyle: bs)),
                            ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _propSection(
          theme,
          'Corner Radius',
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: s.borderRadius,
                  min: 0,
                  max: 24,
                  divisions: 12,
                  label: s.borderRadius.round().toString(),
                  onChanged: (v) => ref
                      .read(canvasProvider.notifier)
                      .updateCard(
                        card.copyWith(style: s.copyWith(borderRadius: v)),
                      ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  s.borderRadius.round().toString(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _propSection(
          theme,
          'Opacity',
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: s.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: s.opacity.toStringAsFixed(1),
                  onChanged: (v) => ref
                      .read(canvasProvider.notifier)
                      .updateCard(card.copyWith(style: s.copyWith(opacity: v))),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  s.opacity.toStringAsFixed(1),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _propSection(
          theme,
          'Shadow',
          Switch(
            value: s.shadow,
            onChanged: (v) => ref
                .read(canvasProvider.notifier)
                .updateCard(card.copyWith(style: s.copyWith(shadow: v))),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(height: 6),
        _propSection(
          theme,
          'Gradient',
          Row(
            children: [
              Text(
                'Off',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: s.gradientColor != null
                      ? theme.hintColor
                      : theme.colorScheme.primary,
                ),
              ),
              Switch(
                value: s.gradientColor != null,
                onChanged: (v) => ref
                    .read(canvasProvider.notifier)
                    .updateCard(
                      card.copyWith(
                        style: v
                            ? s.copyWith(gradientColor: 0xFFE0E0E0)
                            : s.copyWith(clearGradient: true),
                      ),
                    ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(
                'On',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: s.gradientColor != null
                      ? theme.colorScheme.primary
                      : theme.hintColor,
                ),
              ),
              if (s.gradientColor != null) ...[
                const SizedBox(width: 8),
                ..._borderColorPresets
                    .take(5)
                    .map(
                      (color) => GestureDetector(
                        onTap: () => ref
                            .read(canvasProvider.notifier)
                            .updateCard(
                              card.copyWith(
                                style: s.copyWith(
                                  gradientColor: color.toARGB32(),
                                ),
                              ),
                            ),
                        child: Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: s.gradientColor == color.toARGB32()
                                  ? theme.colorScheme.primary
                                  : theme.dividerColor,
                              width: s.gradientColor == color.toARGB32()
                                  ? 1.5
                                  : 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
        if (s.gradientColor != null)
          _propSection(
            theme,
            'Gradient Direction',
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: GradientDirection.values
                    .map(
                      (gd) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          label: Icon(_gradientDirectionIcon(gd), size: 12),
                          selected: s.gradientDirection == gd,
                          onSelected: (_) => ref
                              .read(canvasProvider.notifier)
                              .updateCard(
                                card.copyWith(
                                  style: s.copyWith(gradientDirection: gd),
                                ),
                              ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _propSection(
          theme,
          'Reset Style',
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref
                  .read(canvasProvider.notifier)
                  .updateCard(card.copyWith(clearStyle: true)),
              icon: Icon(Icons.refresh, size: 12),
              label: Text('Reset to Default', style: theme.textTheme.labelSmall),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionDivider(theme),
        const SizedBox(height: 8),
        _propSection(
          theme,
          'Size',
          Text(
            '${card.width.round()} × ${card.height.round()}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        if (card.noteId != null)
          _propSection(
            theme,
            'Note',
            Text(
              card.noteId!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (connections.isNotEmpty) ...[
          const SizedBox(height: 8),
          _propSection(
            theme,
            l.backlinks,
            Text('${connections.length}', style: theme.textTheme.bodySmall),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref
                    .read(canvasProvider.notifier)
                    .startInlineEditing(card.id),
                icon: Icon(Icons.edit, size: 14),
                label: Text(l.editCard, style: theme.textTheme.labelMedium),
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
                label: Text(l.duplicateCard, style: theme.textTheme.labelMedium),
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
        ),
        const SizedBox(height: 8),
        SizedBox(
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
            label: Text(
              l.deleteCard,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
          ),
        ),
      ],
    );
  }

  IconData _gradientDirectionIcon(GradientDirection gd) => switch (gd) {
    GradientDirection.topToBottom => Icons.south,
    GradientDirection.bottomToTop => Icons.north,
    GradientDirection.leftToRight => Icons.east,
    GradientDirection.rightToLeft => Icons.west,
    GradientDirection.topLeftToBottomRight => Icons.south_east,
    GradientDirection.topRightToBottomLeft => Icons.south_west,
  };

  IconData _cardTypeIcon(CanvasCardType type) {
    return switch (type) {
      CanvasCardType.note => Icons.description_outlined,
      CanvasCardType.text => Icons.text_fields,
      CanvasCardType.image => Icons.image_outlined,
      CanvasCardType.link => Icons.link,
      CanvasCardType.container => Icons.crop_square,
      CanvasCardType.rectangle => Icons.rectangle,
      CanvasCardType.roundedRect => Icons.rounded_corner,
      CanvasCardType.ellipse => Icons.circle,
      CanvasCardType.diamond => Icons.diamond,
      CanvasCardType.hexagon => Icons.hexagon,
      CanvasCardType.parallelogram => Icons.change_history,
      CanvasCardType.triangle => Icons.details,
      CanvasCardType.cylinder => Icons.view_column,
      CanvasCardType.star => Icons.star_outline,
      CanvasCardType.swimlaneH => Icons.view_stream,
      CanvasCardType.swimlaneV => Icons.view_week,
      CanvasCardType.table => Icons.table_chart,
      CanvasCardType.freehand => Icons.draw,
    };
  }

  Widget _propSection(ThemeData theme, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
          ),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }

  Widget _sectionDivider(ThemeData theme) {
    return Divider(color: theme.dividerColor.withValues(alpha: 0.3), height: 1);
  }
}

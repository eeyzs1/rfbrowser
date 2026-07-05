import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/services/canvas_service.dart';
import 'package:rfbrowser/services/settings_service.dart';

part 'card_properties/card_properties_helpers.dart';
part 'card_properties/card_properties_basic.dart';
part 'card_properties/card_properties_style.dart';
part 'card_properties/card_properties_actions.dart';

abstract class _CardPropertiesPanelBase extends ConsumerWidget {
  final VoidCallback onClose;

  const _CardPropertiesPanelBase({super.key, required this.onClose});

  Widget propSection(ThemeData theme, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }

  Widget sectionDivider(ThemeData theme) {
    return Divider(color: theme.dividerColor.withValues(alpha: 0.3), height: 1);
  }

  IconData gradientDirectionIcon(GradientDirection gd) => switch (gd) {
    GradientDirection.topToBottom => Icons.south,
    GradientDirection.bottomToTop => Icons.north,
    GradientDirection.leftToRight => Icons.east,
    GradientDirection.rightToLeft => Icons.west,
    GradientDirection.topLeftToBottomRight => Icons.south_east,
    GradientDirection.topRightToBottomLeft => Icons.south_west,
  };

  IconData cardTypeIcon(CanvasCardType type) {
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
}

class CardPropertiesPanel extends _CardPropertiesPanelBase
    with _BasicPropertiesMixin, _StylePropertiesMixin, _ActionButtonsMixin {
  const CardPropertiesPanel({super.key, required super.onClose});

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
        buildHeader(theme, ref, card),
        const SizedBox(height: 12),
        buildTitleSection(theme, l, card),
        const SizedBox(height: 8),
        buildFontSizeSection(theme, l, ref, card, settings, cardFontSize),
        const SizedBox(height: 8),
        buildCardColorSection(theme, l, ref, card),
        buildStyleHeader(theme),
        buildBorderColorSection(theme, ref, card, s),
        const SizedBox(height: 6),
        buildBorderWidthSection(theme, ref, card, s),
        const SizedBox(height: 4),
        buildBorderStyleSection(theme, ref, card, s),
        const SizedBox(height: 6),
        buildCornerRadiusSection(theme, ref, card, s),
        const SizedBox(height: 6),
        buildOpacitySection(theme, ref, card, s),
        const SizedBox(height: 6),
        buildShadowSection(theme, ref, card, s),
        const SizedBox(height: 6),
        buildGradientSection(theme, ref, card, s),
        if (s.gradientColor != null)
          buildGradientDirectionSection(theme, ref, card, s),
        const SizedBox(height: 8),
        buildResetStyleSection(theme, ref, card),
        const SizedBox(height: 12),
        sectionDivider(theme),
        const SizedBox(height: 8),
        buildSizeSection(theme, card),
        const SizedBox(height: 8),
        if (card.noteId != null) buildNoteSection(theme, card),
        if (connections.isNotEmpty) ...[
          const SizedBox(height: 8),
          buildConnectionsSection(theme, l, connections),
        ],
        const SizedBox(height: 16),
        buildEditDuplicateButtons(theme, l, ref, card),
        const SizedBox(height: 8),
        buildDeleteButton(theme, l, ref, card),
      ],
    );
  }
}

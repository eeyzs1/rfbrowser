part of '../card_properties_panel.dart';

/// Style properties section: border, corner radius, opacity, shadow, gradient.
mixin _StylePropertiesMixin on _CardPropertiesPanelBase {
  Widget buildStyleHeader(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        sectionDivider(theme),
        const SizedBox(height: 8),
        Text(
          'Style',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget buildBorderColorSection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
    CanvasCardStyle s,
  ) {
    return propSection(
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
    );
  }

  Widget buildBorderWidthSection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
    CanvasCardStyle s,
  ) {
    return propSection(
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
                  .updateCard(card.copyWith(style: s.copyWith(borderWidth: v))),
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
    );
  }

  Widget buildBorderStyleSection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
    CanvasCardStyle s,
  ) {
    return propSection(
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
                    label: Text(bs.name, style: theme.textTheme.labelSmall),
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
    );
  }

  Widget buildCornerRadiusSection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
    CanvasCardStyle s,
  ) {
    return propSection(
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
    );
  }

  Widget buildOpacitySection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
    CanvasCardStyle s,
  ) {
    return propSection(
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
    );
  }

  Widget buildShadowSection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
    CanvasCardStyle s,
  ) {
    return propSection(
      theme,
      'Shadow',
      Switch(
        value: s.shadow,
        onChanged: (v) => ref
            .read(canvasProvider.notifier)
            .updateCard(card.copyWith(style: s.copyWith(shadow: v))),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget buildGradientSection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
    CanvasCardStyle s,
  ) {
    return propSection(
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
                            style: s.copyWith(gradientColor: color.toARGB32()),
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
    );
  }

  Widget buildGradientDirectionSection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
    CanvasCardStyle s,
  ) {
    return propSection(
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
                    label: Icon(gradientDirectionIcon(gd), size: 12),
                    selected: s.gradientDirection == gd,
                    onSelected: (_) => ref
                        .read(canvasProvider.notifier)
                        .updateCard(
                          card.copyWith(
                            style: s.copyWith(gradientDirection: gd),
                          ),
                        ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget buildResetStyleSection(
    ThemeData theme,
    WidgetRef ref,
    CanvasCard card,
  ) {
    return propSection(
      theme,
      'Reset Style',
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => ref
              .read(canvasProvider.notifier)
              .updateCard(card.copyWith(clearStyle: true)),
          icon: Icon(Icons.refresh, size: 12),
          label: Text('Reset to Default'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
          ),
        ),
      ),
    );
  }
}

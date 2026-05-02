import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/settings_dialogs.dart';

class ComponentSettingsSection extends ConsumerWidget {
  const ComponentSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.components,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l.buttonShape,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildButtonStyleSelector(context, ref, settings, l),
        ),
        if (settings.buttonStyle == AppButtonStyle.rounded) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  l.cornerRadius,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${settings.borderRadius.toInt()}px',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Slider(
              value: settings.borderRadius,
              min: 0,
              max: 50,
              divisions: 50,
              label: '${settings.borderRadius.toInt()}px',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setBorderRadius(v),
            ),
          ),
        ],
        ListTile(
          title: Text(l.density),
          subtitle: Text(_densityLabel(settings.density, l)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showDensityDialog(context, ref, settings.density, l),
        ),
        ListTile(
          title: Text(l.iconSize),
          subtitle: Text('${settings.iconSize}px'),
          trailing: SizedBox(
            width: 200,
            child: Slider(
              value: settings.iconSize.toDouble(),
              min: 12,
              max: 36,
              divisions: 24,
              label: '${settings.iconSize}px',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setIconSize(v.round()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _buildPreviewButton(theme, settings, l),
        ),
      ],
    );
  }

  Widget _buildButtonStyleSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    AppLocalizations l,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: AppButtonStyle.values.map((style) {
        final isSelected = settings.buttonStyle == style;
        final label = switch (style) {
          AppButtonStyle.rounded => l.rounded,
          AppButtonStyle.sharp => l.sharp,
          AppButtonStyle.pill => l.pill,
        };
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () =>
                  ref.read(settingsProvider.notifier).setButtonStyle(style),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : Border.all(color: theme.dividerColor, width: 1),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.hintColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreviewButton(
    ThemeData theme,
    AppSettings settings,
    AppLocalizations l,
  ) {
    final br = settings.effectiveBorderRadius;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(br),
      ),
      child: Column(
        children: [
          Text(
            l.preview,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(br),
                    ),
                  ),
                  child: Text(l.filled),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(br),
                    ),
                  ),
                  child: Text(l.outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _densityLabel(ComponentDensity d, AppLocalizations l) => switch (d) {
    ComponentDensity.compact => l.compact,
    ComponentDensity.comfortable => l.comfortable,
    ComponentDensity.spacious => l.spacious,
  };

  void _showDensityDialog(
    BuildContext context,
    WidgetRef ref,
    ComponentDensity current,
    AppLocalizations l,
  ) {
    showSelectionDialog<ComponentDensity>(
      context: context,
      title: l.componentDensity,
      selectedValue: current,
      options: ComponentDensity.values
          .map((d) => SelectionOption(value: d, label: _densityLabel(d, l)))
          .toList(),
    ).then((value) {
      if (value != null) {
        ref.read(settingsProvider.notifier).setDensity(value);
      }
    });
  }
}

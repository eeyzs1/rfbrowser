import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/color_picker_dialog.dart';

class _PresetTheme {
  final String id;
  final String label;
  final IconData icon;
  const _PresetTheme(this.id, this.label, this.icon);
}

const _presets = [
  _PresetTheme('sky', 'Sky', Icons.cloud),
  _PresetTheme('violet', 'Violet', Icons.auto_awesome),
  _PresetTheme('rose', 'Rose', Icons.favorite),
  _PresetTheme('emerald', 'Emerald', Icons.eco),
  _PresetTheme('amber', 'Amber', Icons.wb_sunny),
  _PresetTheme('indigo', 'Indigo', Icons.nights_stay),
  _PresetTheme('teal', 'Teal', Icons.water_drop),
  _PresetTheme('orange', 'Orange', Icons.local_fire_department),
  _PresetTheme('pink', 'Pink', Icons.local_florist),
  _PresetTheme('slate', 'Slate', Icons.invert_colors_on),
];

class ThemeSettingsSection extends ConsumerWidget {
  const ThemeSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.theme,
      children: [
        SwitchListTile(
          title: Text(l.darkMode),
          subtitle: Text(l.toggleDarkLight),
          value: settings.isDarkMode,
          onChanged: (_) =>
              ref.read(settingsProvider.notifier).toggleDarkMode(),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            l.accentColor,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildPresetGrid(context, ref, settings, l),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: OutlinedButton.icon(
            onPressed: () async {
              final color = await ColorPickerDialog.show(
                context,
                settings.accentColor,
              );
              if (color != null) {
                ref.read(settingsProvider.notifier).setAccentColor(color);
              }
            },
            icon: const Icon(Icons.palette, size: 16),
            label: Text(l.customColor),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildPresetGrid(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    AppLocalizations l,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _presets.map((preset) {
        final presetColor = getPresetColor(preset.id);
        final isSelected = settings.themePreset == preset.id;
        return GestureDetector(
          onTap: () =>
              ref.read(settingsProvider.notifier).setThemePreset(preset.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: presetColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: presetColor, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(preset.icon, size: 16, color: presetColor),
                const SizedBox(height: 2),
                Text(
                  preset.label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? presetColor
                        : Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

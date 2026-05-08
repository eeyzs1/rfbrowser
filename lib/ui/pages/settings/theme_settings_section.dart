import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/color_picker_dialog.dart';

class _PresetColor {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _PresetColor(this.id, this.label, this.icon, this.color);
}

const _themePresets = [
  _PresetColor('ocean', 'Ocean', Icons.waves, Color(0xFF0EA5E9)),
  _PresetColor('violet', 'Violet', Icons.auto_awesome, Color(0xFF8B5CF6)),
  _PresetColor('rose', 'Rose', Icons.favorite, Color(0xFFF43F5E)),
  _PresetColor('emerald', 'Emerald', Icons.eco, Color(0xFF10B981)),
  _PresetColor('amber', 'Amber', Icons.wb_sunny, Color(0xFFF59E0B)),
  _PresetColor('indigo', 'Indigo', Icons.nights_stay, Color(0xFF6366F1)),
  _PresetColor('teal', 'Teal', Icons.water_drop, Color(0xFF14B8A6)),
  _PresetColor('coral', 'Coral', Icons.local_fire_department, Color(0xFFFF6B6B)),
  _PresetColor('mint', 'Mint', Icons.local_florist, Color(0xFF2DD4BF)),
  _PresetColor('slate', 'Slate', Icons.invert_colors_on, Color(0xFF64748B)),
];

const _bgPresets = [
  _PresetColor('midnight', 'Midnight', Icons.dark_mode, Color(0xFF0F172A)),
  _PresetColor('obsidian', 'Obsidian', Icons.circle, Color(0xFF000000)),
  _PresetColor('espresso', 'Espresso', Icons.coffee, Color(0xFF3E2723)),
  _PresetColor('deepSea', 'Deep Sea', Icons.water, Color(0xFF004D61)),
  _PresetColor('plum', 'Plum', Icons.local_florist, Color(0xFF4A1942)),
  _PresetColor('linen', 'Linen', Icons.checkroom, Color(0xFFD6D3D1)),
  _PresetColor('fog', 'Fog', Icons.cloud_outlined, Color(0xFFCBD5E1)),
  _PresetColor('dune', 'Dune', Icons.beach_access, Color(0xFFD4C5B2)),
];

const _surfacePresets = [
  _PresetColor('slate', 'Slate', Icons.layers, Color(0xFF1E293B)),
  _PresetColor('graphite', 'Graphite', Icons.gradient, Color(0xFF374151)),
  _PresetColor('bronze', 'Bronze', Icons.shield, Color(0xFF5D4037)),
  _PresetColor('steel', 'Steel', Icons.construction, Color(0xFF455A64)),
  _PresetColor('mist', 'Mist', Icons.foggy, Color(0xFFC8CCD0)),
  _PresetColor('sandstone', 'Sandstone', Icons.texture, Color(0xFFC4B5A0)),
  _PresetColor('sage', 'Sage', Icons.eco, Color(0xFFB8C5B4)),
  _PresetColor('lavender', 'Lavender', Icons.local_florist, Color(0xFFC8C0D4)),
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
        const SizedBox(height: 8),
        _buildColorSection(
          context, ref, settings, theme, l,
          title: l.themeColor,
          presets: _themePresets,
          currentVal: settings.accentColorValue,
          setter: (c) => ref.read(settingsProvider.notifier).setAccentColor(c),
          isAccent: true,
        ),
        const Divider(height: 24),
        _buildColorSection(
          context, ref, settings, theme, l,
          title: l.backgroundColor,
          presets: _bgPresets,
          currentVal: settings.scaffoldBgColorValue,
          setter: (c) => ref.read(settingsProvider.notifier).setScaffoldBgColor(c),
          isAccent: false,
        ),
        const Divider(height: 24),
        _buildColorSection(
          context, ref, settings, theme, l,
          title: l.surfaceColor,
          presets: _surfacePresets,
          currentVal: settings.surfaceColorValue,
          setter: (c) => ref.read(settingsProvider.notifier).setSurfaceColor(c),
          isAccent: false,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildColorSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    ThemeData theme,
    AppLocalizations l, {
    required String title,
    required List<_PresetColor> presets,
    required int currentVal,
    required void Function(Color) setter,
    required bool isAccent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: LayoutBuilder(builder: (context, constraints) {
            const itemSize = 56.0;
            const gap = 6.0;
            final cols = ((constraints.maxWidth + gap) / (itemSize + gap)).floor();
            return Wrap(
              alignment: WrapAlignment.start,
              spacing: gap,
              runSpacing: gap,
              children: presets.map((preset) {
                final isSelected = currentVal == preset.color.toARGB32();
                return SizedBox(
                  width: (constraints.maxWidth - (cols - 1) * gap) / cols,
                  child: GestureDetector(
                    onTap: () => setter(preset.color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: itemSize,
                      decoration: BoxDecoration(
                        color: isAccent
                            ? preset.color.withValues(alpha: 0.12)
                            : preset.color,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: isAccent ? preset.color : theme.colorScheme.primary, width: 2.5)
                            : Border.all(color: isAccent ? Colors.transparent : Colors.white.withValues(alpha: 0.08), width: 1),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: (isAccent ? preset.color : theme.colorScheme.primary).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            preset.icon,
                            size: 18,
                            color: isAccent
                                ? preset.color
                                : _contrastText(preset.color),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            preset.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isAccent
                                  ? preset.color
                                  : _contrastText(preset.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: OutlinedButton.icon(
            onPressed: () async {
              final current = Color(currentVal);
              final color = await ColorPickerDialog.show(context, current);
              if (color != null) setter(color);
            },
            icon: const Icon(Icons.palette, size: 16),
            label: Text(l.customColor),
          ),
        ),
      ],
    );
  }

  Color _contrastText(Color bg) {
    final lum = bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114;
    return lum > 128 ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  }
}

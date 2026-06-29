import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../../core/color_extensions.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/color_picker_dialog.dart';

class _PresetColor {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _PresetColor(this.id, this.label, this.icon, this.color);
}

// 主题强调色：16 项，色相环均匀分布，相邻颜色色相差 ≥22.5°，视觉差异明显。
// Label 全局唯一：与 _bgPresets/_surfacePresets/_fontPresets 不重名，便于
// 集成测试用 find.text 精确定位每个预设。
const _themePresets = [
  _PresetColor('scarlet', 'Scarlet', Icons.local_fire_department, Color(0xFFDC2626)),
  _PresetColor('red', 'Red', Icons.fire_extinguisher, Color(0xFFEF4444)),
  _PresetColor('sunset', 'Sunset', Icons.wb_twilight, Color(0xFFF97316)),
  _PresetColor('marigold', 'Marigold', Icons.wb_sunny, Color(0xFFF59E0B)),
  _PresetColor('yellow', 'Yellow', Icons.light_mode, Color(0xFFEAB308)),
  _PresetColor('lime', 'Lime', Icons.grass, Color(0xFF84CC16)),
  _PresetColor('emerald', 'Emerald', Icons.eco, Color(0xFF10B981)),
  _PresetColor('teal', 'Teal', Icons.water_drop, Color(0xFF14B8A6)),
  _PresetColor('cyan', 'Cyan', Icons.tsunami, Color(0xFF06B6D4)),
  _PresetColor('ocean', 'Ocean', Icons.waves, Color(0xFF0EA5E9)),
  _PresetColor('indigo', 'Indigo', Icons.nights_stay, Color(0xFF6366F1)),
  _PresetColor('violet', 'Violet', Icons.auto_awesome, Color(0xFF8B5CF6)),
  _PresetColor('purple', 'Purple', Icons.blender, Color(0xFFA855F7)),
  _PresetColor('magenta', 'Magenta', Icons.brush, Color(0xFFD946EF)),
  _PresetColor('pink', 'Pink', Icons.local_florist, Color(0xFFEC4899)),
  _PresetColor('strawberry', 'Strawberry', Icons.favorite, Color(0xFFF43F5E)),
];

// 背景色：16 项，8 深色 + 8 浅色，浅色含暖/冷两类确保差异。
// Label 全局唯一（参见 _themePresets 注释）。
const _bgPresets = [
  _PresetColor('midnight', 'Midnight', Icons.dark_mode, Color(0xFF0F172A)),
  _PresetColor('obsidian', 'Obsidian', Icons.circle, Color(0xFF000000)),
  _PresetColor('mocha', 'Mocha', Icons.coffee, Color(0xFF3E2723)),
  _PresetColor('deepSea', 'Deep Sea', Icons.water, Color(0xFF004D61)),
  _PresetColor('onyx', 'Onyx', Icons.brightness_3, Color(0xFF1A1A2E)),
  _PresetColor('forest', 'Forest', Icons.forest, Color(0xFF1B2A1B)),
  _PresetColor('wine', 'Wine', Icons.wine_bar, Color(0xFF4A1942)),
  _PresetColor('slateDark', 'Slate Dark', Icons.layers, Color(0xFF1E293B)),
  _PresetColor('cream', 'Cream', Icons.breakfast_dining, Color(0xFFFAF3E0)),
  _PresetColor('mist', 'Mist', Icons.cloud_outlined, Color(0xFFE0E7FF)),
  _PresetColor('parchment', 'Parchment', Icons.description, Color(0xFFF5E6D3)),
  _PresetColor('sagebrush', 'Sagebrush', Icons.eco, Color(0xFFE6F4EA)),
  _PresetColor('dune', 'Dune', Icons.beach_access, Color(0xFFD4C5B2)),
  _PresetColor('pearl', 'Pearl', Icons.diamond, Color(0xFFF0F0F0)),
  _PresetColor('blush', 'Blush', Icons.local_florist, Color(0xFFFCE7F3)),
  _PresetColor('linen', 'Linen', Icons.checkroom, Color(0xFFECEFF1)),
];

// 表面色：16 项，4 暗色 + 12 浅色，浅色暖冷交替确保差异。
// Label 全局唯一（参见 _themePresets 注释）。
const _surfacePresets = [
  _PresetColor('slateBlue', 'Slate Blue', Icons.layers, Color(0xFF1E3A5F)),
  _PresetColor('graphite', 'Graphite', Icons.gradient, Color(0xFF374151)),
  _PresetColor('bronze', 'Bronze', Icons.shield, Color(0xFF5D4037)),
  _PresetColor('cinnamon', 'Cinnamon', Icons.coffee, Color(0xFF8B5E3C)),
  _PresetColor('ivory', 'Ivory', Icons.light_mode, Color(0xFFE8E0D0)),
  _PresetColor('sky', 'Sky', Icons.cloud, Color(0xFFB8D4E8)),
  _PresetColor('sandstone', 'Sandstone', Icons.texture, Color(0xFFC4B5A0)),
  _PresetColor('sage', 'Sage', Icons.eco, Color(0xFFB8C5B4)),
  _PresetColor('peach', 'Peach', Icons.sunny, Color(0xFFE5C4A0)),
  _PresetColor('lavender', 'Lavender', Icons.local_florist, Color(0xFFC8C0D4)),
  _PresetColor('pearlSurface', 'Pearl Surface', Icons.diamond, Color(0xFFD4CFC9)),
  _PresetColor('mint', 'Mint', Icons.local_florist, Color(0xFFC8E6C9)),
  _PresetColor('rose', 'Rose', Icons.favorite, Color(0xFFEAD5DD)),
  _PresetColor('amber', 'Amber', Icons.wb_sunny, Color(0xFFF5DEB3)),
  _PresetColor('clay', 'Clay', Icons.terrain, Color(0xFFD4A574)),
  _PresetColor('steel', 'Steel', Icons.construction, Color(0xFFB0BEC5)),
];

// 字体色：16 项，覆盖白/灰/黑/暖/冷/强调色，相邻颜色差异明显。
// Label 全局唯一（参见 _themePresets 注释）。
const _fontPresets = [
  _PresetColor('white', 'White', Icons.text_fields, Color(0xFFFFFFFF)),
  _PresetColor('ivoryWhite', 'Ivory White', Icons.text_fields, Color(0xFFFFF8E7)),
  _PresetColor('butter', 'Butter', Icons.text_fields, Color(0xFFFAF3E0)),
  _PresetColor('pearlWhite', 'Pearl White', Icons.text_fields, Color(0xFFF0F0F0)),
  _PresetColor('warmGray', 'Warm Gray', Icons.text_fields, Color(0xFFB8AFA6)),
  _PresetColor('gray', 'Gray', Icons.text_fields, Color(0xFF94A3B8)),
  _PresetColor('slate', 'Slate', Icons.text_fields, Color(0xFF64748B)),
  _PresetColor('charcoal', 'Charcoal', Icons.text_fields, Color(0xFF2A2A2A)),
  _PresetColor('black', 'Black', Icons.text_fields, Color(0xFF000000)),
  _PresetColor('sepia', 'Sepia', Icons.text_fields, Color(0xFF5C4B37)),
  _PresetColor('coffee', 'Coffee', Icons.text_fields, Color(0xFF3E2723)),
  _PresetColor('caramel', 'Caramel', Icons.text_fields, Color(0xFFAE8B5C)),
  _PresetColor('sand', 'Sand', Icons.text_fields, Color(0xFFEAD7B7)),
  _PresetColor('honey', 'Honey', Icons.text_fields, Color(0xFFFFB74D)),
  _PresetColor('crimson', 'Crimson', Icons.text_fields, Color(0xFFB91C1C)),
  _PresetColor('navy', 'Navy', Icons.text_fields, Color(0xFF1E3A5F)),
];

class ThemeSettingsSection extends ConsumerWidget {
  const ThemeSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 用 select 只 watch 本 section 关心的 8 个字段（参见
    // editor_settings_section.dart 中的详细注释）。其他 section 字段变化
    // 不会触发本 section 重建。
    final themeMode = ref.watch(
      settingsProvider.select((s) => s.themeMode),
    );
    final accentColorValue = ref.watch(
      settingsProvider.select((s) => s.accentColorValue),
    );
    final scaffoldBgColorValue = ref.watch(
      settingsProvider.select((s) => s.scaffoldBgColorValue),
    );
    final surfaceColorValue = ref.watch(
      settingsProvider.select((s) => s.surfaceColorValue),
    );
    final fontColorValue = ref.watch(
      settingsProvider.select((s) => s.fontColorValue),
    );
    final themeTintOpacity = ref.watch(
      settingsProvider.select((s) => s.themeTintOpacity),
    );
    final surfaceOpacity = ref.watch(
      settingsProvider.select((s) => s.surfaceOpacity),
    );
    final backgroundOpacity = ref.watch(
      settingsProvider.select((s) => s.backgroundOpacity),
    );
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.theme,
      children: [
        const SizedBox(height: 8),
        _buildThemeModeSelector(context, ref, themeMode, theme, l),
        const Divider(height: 24),
        _buildColorSection(
          context,
          ref,
          theme,
          l,
          title: l.themeColor,
          presets: _themePresets,
          currentVal: accentColorValue,
          setter: (c) => ref.read(settingsProvider.notifier).setAccentColor(c),
          isAccent: true,
        ),
        const Divider(height: 24),
        _buildColorSection(
          context,
          ref,
          theme,
          l,
          title: l.backgroundColor,
          presets: _bgPresets,
          currentVal: scaffoldBgColorValue,
          setter: (c) =>
              ref.read(settingsProvider.notifier).setScaffoldBgColor(c),
          isAccent: false,
        ),
        const Divider(height: 24),
        _buildColorSection(
          context,
          ref,
          theme,
          l,
          title: l.surfaceColor,
          presets: _surfacePresets,
          currentVal: surfaceColorValue,
          setter: (c) => ref.read(settingsProvider.notifier).setSurfaceColor(c),
          isAccent: false,
        ),
        const Divider(height: 24),
        _buildColorSection(
          context,
          ref,
          theme,
          l,
          title: l.fontColor,
          presets: _fontPresets,
          // fontColorValue 为 null（Auto）时用 -1，不匹配任何预设
          currentVal: fontColorValue ?? -1,
          setter: (c) => ref.read(settingsProvider.notifier).setFontColor(c),
          isAccent: false,
        ),
        const Divider(height: 24),
        _buildOpacitySliders(
          context,
          ref,
          theme,
          l,
          themeTintOpacity: themeTintOpacity,
          surfaceOpacity: surfaceOpacity,
          backgroundOpacity: backgroundOpacity,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildThemeModeSelector(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
    ThemeData theme,
    AppLocalizations l,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            l.themeModeLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto, size: 16),
                label: Text(l.followSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode, size: 16),
                label: Text(l.lightMode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode, size: 16),
                label: Text(l.darkMode),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (modes) {
              ref
                  .read(settingsProvider.notifier)
                  .setThemeMode(modes.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorSection(
    BuildContext context,
    WidgetRef ref,
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
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          // ExcludeSemantics：色块网格只是视觉选择器，父级已有标题标签。
          // 40+ 色块 × 4 section = 160+ AXTree 节点，在主题色变化导致全树重建时
          // 会触发 Windows accessibility_bridge AXTree 更新失败（"Failed to update
          // ui::AXTree, error: NNN will not be in the tree"），最终进程崩溃。
          // 包裹后这些纯视觉色块不再向语义树贡献节点，从根源上消除崩溃。
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const itemSize = 56.0;
                const gap = 6.0;
                final cols = ((constraints.maxWidth + gap) / (itemSize + gap))
                    .floor();
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
                        // Container 替代 AnimatedContainer：
                        // 200ms 动画在主题色变化触发全树重建时，会让 40+ 色块同时
                        // 启动 border/shadow 动画 → 每帧都向 AXTree 提交更新 → 累积
                        // 超过 accessibility bridge 处理阈值 → AXTree 更新失败 → 崩溃。
                        // 去掉动画后状态切换是即时的单次重绘，不产生动画帧序列。
                        child: Container(
                          height: itemSize,
                          decoration: BoxDecoration(
                            color: isAccent
                                ? preset.color.withValues(alpha: 0.12)
                                : preset.color,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: isAccent
                                        ? preset.color
                                        : theme.colorScheme.primary,
                                    width: 2.5,
                                  )
                                : Border.all(
                                    color: isAccent
                                        ? Colors.transparent
                                        : theme.colorScheme.onSurface.withValues(
                                            alpha: 0.08,
                                          ),
                                    width: 1,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color:
                                          (isAccent
                                                  ? preset.color
                                                  : theme.colorScheme.primary)
                                              .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                preset.icon,
                                size: 16,
                                color: isAccent
                                    ? preset.color
                                    : _contrastText(preset.color),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Text(
                                  preset.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isAccent
                                        ? preset.color
                                        : _contrastText(preset.color),
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
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

  Color _contrastText(Color bg) => bg.contrastText;

  Widget _buildOpacitySliders(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations l, {
    required double themeTintOpacity,
    required double surfaceOpacity,
    required double backgroundOpacity,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            l.opacity,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ListTile(
          title: Text(l.themeTintOpacity),
          subtitle: Text('${(themeTintOpacity * 100).round()}%'),
          trailing: SizedBox(
            width: 200,
            // ExcludeSemantics：Slider 拖拽时 onChanged 每帧触发，叠加全树重建，
            // 导致 Windows accessibility_bridge AXTree diff 失败。包裹后 Slider
            // 不再贡献语义节点，旁边的 subtitle Text 仍可朗读当前百分比。
            child: ExcludeSemantics(
              child: Slider(
                value: themeTintOpacity,
                min: 0.2,
                max: 1.0,
                divisions: 8,
                label: '${(themeTintOpacity * 100).round()}%',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setThemeTintOpacityLive(v),
                onChangeEnd: (v) => ref
                    .read(settingsProvider.notifier)
                    .setThemeTintOpacity(v),
              ),
            ),
          ),
        ),
        ListTile(
          title: Text(l.surfaceOpacity),
          subtitle: Text('${(surfaceOpacity * 100).round()}%'),
          trailing: SizedBox(
            width: 200,
            child: ExcludeSemantics(
              child: Slider(
                value: surfaceOpacity,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: '${(surfaceOpacity * 100).round()}%',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setSurfaceOpacityLive(v),
                onChangeEnd: (v) => ref
                    .read(settingsProvider.notifier)
                    .setSurfaceOpacity(v),
              ),
            ),
          ),
        ),
        ListTile(
          title: Text(l.backgroundOpacity),
          subtitle: Text('${(backgroundOpacity * 100).round()}%'),
          trailing: SizedBox(
            width: 200,
            child: ExcludeSemantics(
              child: Slider(
                value: backgroundOpacity,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: '${(backgroundOpacity * 100).round()}%',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setBackgroundOpacityLive(v),
                onChangeEnd: (v) => ref
                    .read(settingsProvider.notifier)
                    .setBackgroundOpacity(v),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

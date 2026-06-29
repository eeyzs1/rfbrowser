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
    // 用 select 只 watch 本 section 关心的 4 个字段（borderRadius、iconSize、
    // buttonStyle、density）。参见 editor_settings_section.dart 中的详细注释。
    // effectiveBorderRadius 是 derived value（borderRadius 或 buttonStyle
    // 决定），所以只需要 watch 这 4 个字段。
    final borderRadius = ref.watch(
      settingsProvider.select((s) => s.borderRadius),
    );
    final iconSize = ref.watch(settingsProvider.select((s) => s.iconSize));
    final buttonStyle = ref.watch(
      settingsProvider.select((s) => s.buttonStyle),
    );
    final density = ref.watch(settingsProvider.select((s) => s.density));
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
          child: _buildButtonStyleSelector(
            context,
            ref,
            buttonStyle: buttonStyle,
            borderRadius: borderRadius,
            l: l,
          ),
        ),
        if (buttonStyle == AppButtonStyle.rounded) ...[
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
                  '${borderRadius.toInt()}px',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            // ExcludeSemantics：Slider 的 onChanged 每帧触发，每次都更新
            // settingsProvider → 重建整个设置页 → 向 AXTree 提交新语义树。
            // Slider 自身的语义节点会在每帧 announcing value，叠加全树重建，
            // 导致 Windows accessibility_bridge AXTree diff 失败。包裹后
            // Slider 不再贡献语义节点，旁边的 Text 仍可朗读当前值。
            child: ExcludeSemantics(
              child: Slider(
                value: borderRadius,
                min: 0,
                max: 50,
                divisions: 50,
                label: '${borderRadius.toInt()}px',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setBorderRadiusLive(v),
                onChangeEnd: (v) =>
                    ref.read(settingsProvider.notifier).setBorderRadius(v),
              ),
            ),
          ),
        ],
        ListTile(
          title: Text(l.density),
          subtitle: Text(_densityLabel(density, l)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showDensityDialog(context, ref, density, l),
        ),
        ListTile(
          title: Text(l.iconSize),
          subtitle: Text('$iconSize px'),
          trailing: SizedBox(
            width: 200,
            child: ExcludeSemantics(
              child: Slider(
                value: iconSize.toDouble(),
                min: 12,
                max: 36,
                divisions: 24,
                label: '$iconSize px',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setIconSizeLive(v.round()),
                onChangeEnd: (v) => ref
                    .read(settingsProvider.notifier)
                    .setIconSize(v.round()),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _buildPreviewButton(
            theme,
            buttonStyle: buttonStyle,
            borderRadius: borderRadius,
            l: l,
          ),
        ),
      ],
    );
  }

  Widget _buildButtonStyleSelector(
    BuildContext context,
    WidgetRef ref, {
    required AppButtonStyle buttonStyle,
    required double borderRadius,
    required AppLocalizations l,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: AppButtonStyle.values.map((style) {
        final isSelected = buttonStyle == style;
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
              // Container 替代 AnimatedContainer：
              // 200ms 动画在选中状态切换时会产生 12 帧动画序列，每帧都向
              // AXTree 提交语义节点更新。叠加 Slider 的 onChanged 和全树重建，
              // 会触发 Windows accessibility_bridge AXTree diff 失败。
              child: Container(
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
                    style: theme.textTheme.bodySmall?.copyWith(
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
    ThemeData theme, {
    required AppButtonStyle buttonStyle,
    required double borderRadius,
    required AppLocalizations l,
  }) {
    // effectiveBorderRadius 是 derived：根据 buttonStyle 计算。
    final br = buttonStyle == AppButtonStyle.rounded
        ? borderRadius
        : 0.0;
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

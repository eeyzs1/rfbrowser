import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';

class EditorSettingsSection extends ConsumerWidget {
  const EditorSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 用 select 只 watch 关心的字段，避免 settings 整体变化时本 section 重建。
    // 这是绕过 Flutter Windows accessibility_bridge AXTree diff 失败的关键：
    // 5 个 section 都 watch 整个 settingsProvider → 任何字段变化都触发 5 个
    // section 同时重建 → SemanticsNode 在同一帧内大批量重排 →
    // accessibility_bridge.cc:114 "will not be in the tree" 错误。
    // 用 select 后，本 section 只在 alwaysShowWelcomePage 或 editorFontSize
    // 真正变化时才重建，单次 diff 规模从 ~250 节点降到 ~50 节点。
    final alwaysShowWelcomePage = ref.watch(
      settingsProvider.select((s) => s.alwaysShowWelcomePage),
    );
    final editorFontSize = ref.watch(
      settingsProvider.select((s) => s.editorFontSize),
    );
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.editorSection,
      children: [
        SwitchListTile(
          title: Text(l.alwaysShowWelcomePage),
          subtitle: Text(l.alwaysShowWelcomePageDesc),
          value: alwaysShowWelcomePage,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setAlwaysShowWelcomePage(v),
        ),
        ListTile(
          title: Text(l.fontSize),
          subtitle: Text('${editorFontSize.toInt()}px'),
          trailing: SizedBox(
            width: 200,
            // ExcludeSemantics：Slider 拖拽时每帧触发 AXTree 更新，包裹后
            // 不再贡献语义节点，旁边的 subtitle Text 仍可朗读当前字号。
            child: ExcludeSemantics(
              child: Slider(
                value: editorFontSize,
                min: 8,
                max: 48,
                divisions: 40,
                label: '${editorFontSize.toInt()}px',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setEditorFontSizeLive(v),
                onChangeEnd: (v) =>
                    ref.read(settingsProvider.notifier).setEditorFontSize(v),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

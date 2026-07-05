import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'category_header.dart';
import 'theme_settings_section.dart';
import 'component_settings_section.dart';
import 'language_settings_section.dart';
import 'editor_settings_section.dart';
import 'quick_moves_settings_section.dart';

/// 通用设置子页面：Theme + Component + Language + Editor + QuickMoves。
///
/// 从原 settings_page.dart 的 General category 拆出，单独成页以降低单页
/// SemanticsNode 总量，缓解 Windows accessibility_bridge AXTree diff 失败。
///
/// 导航：由 SettingsPage 通过条件渲染切换显示（不用 Navigator.push），
/// onBack 回调返回主页。详见 settings_page.dart 的根因说明。
///
/// 使用 Flutter 默认 ListView 行为（默认 cacheExtent + 自动 keep alive），
/// 让视口外 item 保持 mounted，避免滚动时频繁 mount/unmount 触发
/// semantics 节点时序竞争。
class GeneralSettingsPage extends StatelessWidget {
  final VoidCallback onBack;

  const GeneralSettingsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final items = <Widget>[
      CategoryHeader(title: l.settingsCategoryGeneral),
      const SizedBox(height: 8),
      const ThemeSettingsSection(),
      const SizedBox(height: 16),
      const ComponentSettingsSection(),
      const SizedBox(height: 16),
      const LanguageSettingsSection(),
      const SizedBox(height: 16),
      const EditorSettingsSection(),
      const SizedBox(height: 16),
      const QuickMovesSettingsSection(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text(l.settingsCategoryGeneral),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

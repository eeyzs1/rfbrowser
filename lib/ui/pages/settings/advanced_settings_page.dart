import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'category_header.dart';
import 'sync_settings_section.dart';
import 'plugin_settings_section.dart';
import 'about_section.dart';

/// 高级设置子页面：Sync + Plugin + About。
///
/// 从原 settings_page.dart 的 Advanced category 拆出，单独成页以降低单页
/// SemanticsNode 总量，缓解 Windows accessibility_bridge AXTree diff 失败。
///
/// 导航：由 SettingsPage 通过条件渲染切换显示（不用 Navigator.push），
/// onBack 回调返回主页。详见 settings_page.dart 的根因说明。
///
/// 使用 Flutter 默认 ListView 行为（默认 cacheExtent + 自动 keep alive），
/// 让视口外 item 保持 mounted，避免滚动时频繁 mount/unmount 触发
/// semantics 节点时序竞争。
class AdvancedSettingsPage extends StatelessWidget {
  final VoidCallback onBack;

  const AdvancedSettingsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final items = <Widget>[
      CategoryHeader(title: l.settingsCategoryAdvanced),
      const SizedBox(height: 8),
      const SyncSettingsSection(),
      const SizedBox(height: 16),
      const PluginSettingsSection(),
      const SizedBox(height: 16),
      const AboutSection(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text(l.settingsCategoryAdvanced),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

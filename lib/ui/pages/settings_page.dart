import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'settings/general_settings_page.dart';
import 'settings/ai_settings_page.dart';
import 'settings/advanced_settings_page.dart';

/// 设置页。用条件渲染（switch）在主页与 3 个子页面之间切换，而不用
/// Navigator.push。
///
/// 根因诊断（2026-07-03）：Navigator.push 会在 Overlay 中堆叠多个
/// OverlayEntry（MainLayout + SettingsPage + 子页面 + 过渡层），每个
/// OverlayEntry 贡献一个全屏空 SemanticsNode 容器。这些空容器节点在
/// native accessibility_bridge 的 AXTree Unserialize 过程中成为 orphan
/// （"NNN will not be in the tree and is not the new root"）→ AXTree
/// 损坏 → 后续每帧连锁失败 → 进程崩溃。
///
/// SettingsPage 本身也通过 MainLayout 的条件渲染显示（不用 Navigator.push），
/// 消除所有 Overlay 多层。子页面切换在 SettingsPage 内部用 setState 完成。
///
/// [onBack] 回调用于从主页返回 MainLayout（替代 Navigator.pop）。
/// 子页面通过内部的 _backToHome 返回主页。
class SettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsPage({super.key, this.onBack});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 0 = 主页，1 = General，2 = AI，3 = Advanced。
  int _selectedIndex = 0;

  void _backToHome() => setState(() => _selectedIndex = 0);
  void _goTo(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return switch (_selectedIndex) {
      1 => GeneralSettingsPage(onBack: _backToHome),
      2 => AISettingsPage(onBack: _backToHome),
      3 => AdvancedSettingsPage(onBack: _backToHome),
      _ => _buildHomePage(),
    };
  }

  Widget _buildHomePage() {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Text(l.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CategoryTile(
            icon: Icons.tune,
            title: l.settingsCategoryGeneral,
            onTap: () => _goTo(1),
          ),
          _CategoryTile(
            icon: Icons.smart_toy,
            title: l.settingsCategoryAI,
            onTap: () => _goTo(2),
          ),
          _CategoryTile(
            icon: Icons.settings_suggest,
            title: l.settingsCategoryAdvanced,
            onTap: () => _goTo(3),
          ),
        ],
      ),
    );
  }
}

/// 分类入口 tile：Card + ListTile + CircleAvatar + chevron_right。
/// 点击通过 setState 切换到对应子页面（不使用 Navigator.push）。
class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../memory_browser_page.dart';
import '../skills_management_page.dart';
import 'category_header.dart';
import 'ai_settings_section.dart';
import 'agent_settings_section.dart';
import 'memory_settings_section.dart';
import 'shortcut_settings_section.dart';

/// AI 与自动化设置子页面：AISettings + AgentSettings + MemorySettings
/// + MemoryAdvancedSettings + MemoryBrowser tile + Skills tile + Shortcut。
///
/// 从原 settings_page.dart 的 AI category 拆出，单独成页以降低单页
/// SemanticsNode 总量，缓解 Windows accessibility_bridge AXTree diff 失败。
///
/// 导航：由 SettingsPage 通过条件渲染切换显示（不用 Navigator.push），
/// onBack 回调返回主页。详见 settings_page.dart 的根因说明。
///
/// 使用 Flutter 默认 ListView 行为（默认 cacheExtent + 自动 keep alive），
/// 让视口外 item 保持 mounted，避免滚动时频繁 mount/unmount 触发
/// semantics 节点时序竞争。
class AISettingsPage extends ConsumerWidget {
  final VoidCallback onBack;

  const AISettingsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    final items = <Widget>[
      CategoryHeader(title: l.settingsCategoryAI),
      const SizedBox(height: 8),
      const AISettingsSection(),
      const SizedBox(height: 16),
      const AgentSettingsSection(),
      const SizedBox(height: 16),
      const MemorySettingsSection(),
      const SizedBox(height: 16),
      const MemoryAdvancedSettingsSection(),
      const SizedBox(height: 16),
      const _MemoryBrowserTile(),
      const SizedBox(height: 16),
      const _SkillsSettingsTile(),
      const SizedBox(height: 16),
      const ShortcutSettingsSection(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text(l.settingsCategoryAI),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

/// 从 settings_page.dart 原样迁入。导航到 MemoryBrowserPage。
class _MemoryBrowserTile extends StatelessWidget {
  const _MemoryBrowserTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Icon(
          Icons.psychology,
          size: 18,
          color: theme.colorScheme.primary,
        ),
      ),
      title: const Text('Memory Browser'),
      subtitle: Text(
        'Browse fragments, summaries, and Hebbian links',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MemoryBrowserPage()),
        );
      },
    );
  }
}

/// 从 settings_page.dart 原样迁入。导航到 SkillsManagementPage。
class _SkillsSettingsTile extends ConsumerWidget {
  const _SkillsSettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Icon(
          Icons.auto_awesome,
          size: 18,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(l.skills),
      subtitle: Text(
        l.extrazerodoSkillEmptyHint,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SkillsManagementPage()),
        );
      },
    );
  }
}

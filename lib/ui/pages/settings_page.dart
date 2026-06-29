import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'settings/theme_settings_section.dart';
import 'settings/component_settings_section.dart';
import 'settings/language_settings_section.dart';
import 'settings/ai_settings_section.dart';
import 'settings/agent_settings_section.dart';
import 'settings/editor_settings_section.dart';
import 'settings/memory_settings_section.dart';
import 'settings/shortcut_settings_section.dart';
import 'settings/sync_settings_section.dart';
import 'settings/plugin_settings_section.dart';
import 'settings/quick_moves_settings_section.dart';
import 'settings/about_section.dart';
import 'memory_browser_page.dart';
import 'skills_management_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    // 关键修复：用 ListView.builder 替代 ListView(children: [...])。
    //
    // 之前 ListView(children: [...]) 一次性挂载所有 12 个 section ×
    // 5-10 个 widget = ~700-1000 个 SemanticsNode。滚动时视口移动，
    // SemanticsNode 的"父节点"在 viewport SemanticsNode 的 children
    // 中反复切换（in-viewport ↔ out-of-viewport）。Flutter 的
    // accessibility_bridge.cc:51-56 注释明确指出：
    //
    //   "AXTree cannot move a node in a single update.
    //    This must be split across two updates:
    //    * Update 1: remove nodes from their old parents.
    //    * Update 2: re-add nodes (including their children) to their new parents."
    //
    // 滚动每帧产生大量 move 请求 → Chromium ui::AXTree diff 算法
    // 拒绝 → 输出 "Failed to update ui::AXTree, error: 54 will not be
    // in the tree and is not the new root"。67 次连续 = 67 帧滚动。
    //
    // ListView.builder 只挂载当前可见 + 缓冲区的 sections，~200 节点
    // 而非 ~1000，滚动时移动的节点数大幅减少，AXTree diff 可处理。
    //
    // 注：每项是一个 Widget（不是 Widget[]），所以 SizedBox(height: 16)
    // 等间距元素也是独立 item，确保滚动时挂载/卸载的是单项。
    final items = <Widget>[
      _CategoryHeader(title: l.settingsCategoryGeneral),
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
      const SizedBox(height: 24),
      _CategoryHeader(title: l.settingsCategoryAI),
      const SizedBox(height: 8),
      const AISettingsSection(),
      const SizedBox(height: 16),
      const AgentSettingsSection(),
      const SizedBox(height: 16),
      const MemorySettingsSection(),
      const SizedBox(height: 16),
      const _MemoryBrowserTile(),
      const SizedBox(height: 16),
      const _SkillsSettingsTile(),
      const SizedBox(height: 16),
      const ShortcutSettingsSection(),
      const SizedBox(height: 24),
      _CategoryHeader(title: l.settingsCategoryAdvanced),
      const SizedBox(height: 8),
      const SyncSettingsSection(),
      const SizedBox(height: 16),
      const PluginSettingsSection(),
      const SizedBox(height: 16),
      const AboutSection(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        // 关键修复 1：cacheExtent: 0 — 真正卸载视口外 items
        // ListView.builder 默认 cacheExtent=250，会把视口外 ±250px 的 items 保留
        // 在 SemanticsNode 树中（标记为 isHidden）。每个 section ~250px 高，所以
        // 视口外有 2-3 个 sections 在缓存里。滚动时这些 hidden 节点的位置变化
        // 导致 Chromium ui::AXTree diff 失败（"error 54"）。
        // 复现测试显示：滚动前 111 lines，滚动后 124 lines（Δ=+13，全部是
        // 进入 cacheExtent 的新 hidden 节点）。cacheExtent: 0 后视口外立即卸载。
        //
        // 关键修复 2：KeyedSubtree + ValueKey(index)
        // const 列表中同一 widget instance 在 ListView 跨位置时会被 Flutter
        // 视为"同一个 element 移动位置"，导致 isHidden 标记而不是卸载。
        // 加 Key 后 Flutter 知道是不同 item，强制挂载/卸载。
        //
        // scrollCacheExtent: ScrollCacheExtent.pixels(0) 替代已废弃的
        // cacheExtent: 0（Flutter 3.41+ 后 cacheExtent 被废弃）。
        // 保留 addAutomaticKeepAlives: false 配合强制卸载。
        // 移除 addRepaintBoundaries: false —— 该标志与 AXTree 无关，纯粹
        // 禁用每项 RepaintBoundary 隔离，导致滚动时整个 ListView 重绘，
        // 是不必要的性能损耗。保留默认 true 恢复每项重绘隔离。
        scrollCacheExtent: ScrollCacheExtent.pixels(0),
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) => KeyedSubtree(
          key: ValueKey<int>(index),
          child: items[index],
        ),
      ),
    );
  }
}

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

class _CategoryHeader extends StatelessWidget {
  final String title;

  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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

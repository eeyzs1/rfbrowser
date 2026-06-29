import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/browser_service.dart';
import '../../../data/models/browser_tab.dart';
import '../../theme/design_tokens.dart';
import '../../../l10n/app_localizations.dart';

class BrowserTabBar extends ConsumerStatefulWidget {
  final BrowserState browserState;
  final AppLocalizations l;
  final void Function(BrowserTab tab) onCloseTab;
  final void Function(BrowserTab tab) onShowContextMenu;

  const BrowserTabBar({
    super.key,
    required this.browserState,
    required this.l,
    required this.onCloseTab,
    required this.onShowContextMenu,
  });

  @override
  ConsumerState<BrowserTabBar> createState() => _BrowserTabBarState();
}

class _BrowserTabBarState extends ConsumerState<BrowserTabBar> {
  static const int _maxVisibleTabs = 15;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabs = widget.browserState.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    final visibleTabs = tabs.length > _maxVisibleTabs
        ? tabs.sublist(0, _maxVisibleTabs)
        : tabs;
    final overflowCount = tabs.length > _maxVisibleTabs
        ? tabs.length - _maxVisibleTabs
        : 0;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              scrollDirection: Axis.horizontal,
              itemCount: visibleTabs.length + 1,
              onReorderItem: (oldIndex, newIndex) {
                if (newIndex >= visibleTabs.length) return;
                final adjustedOld = oldIndex < visibleTabs.length
                    ? oldIndex
                    : oldIndex - 1;
                if (adjustedOld != newIndex) {
                  ref
                      .read(browserProvider.notifier)
                      .reorderTab(adjustedOld, newIndex);
                }
              },
              itemBuilder: (context, index) {
                if (index == visibleTabs.length) {
                  return _buildNewTabButton(theme);
                }
                final tab = visibleTabs[index];
                return _buildTabItem(theme, tab, index);
              },
            ),
          ),
          if (overflowCount > 0) _buildOverflowIndicator(theme, overflowCount),
        ],
      ),
    );
  }

  Widget _buildNewTabButton(ThemeData theme) {
    return IconButton(
      key: const ValueKey('__new_tab_btn__'),
      icon: Icon(Icons.add, size: 16, color: theme.hintColor),
      onPressed: () {
        if (widget.browserState.tabs.length >= 30) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(widget.l.maxTabsReached),
            ),
          );
          return;
        }
        ref
            .read(browserProvider.notifier)
            .createTab(url: 'https://www.bing.com');
      },
      padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.sm),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
      tooltip: widget.l.newTabLabel,
    );
  }

  Widget _buildOverflowIndicator(ThemeData theme, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.sm),
      child: Tooltip(
        message: widget.l.tabOverflow(count),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.sm,
            vertical: DesignSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(DesignRadius.sm),
          ),
          child: Text(
            '+$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(ThemeData theme, BrowserTab tab, int index) {
    final isActive = tab.id == widget.browserState.activeTabId;
    // 稳定语义策略（与 _NavButton / _SceneButton 一致）：
    // 外层 Semantics(button, selected, label) 提供稳定的 button 角色 +
    // tab 标题 + active 状态。内层 ExcludeSemantics 屏蔽 InkWell 及其所有
    // 子节点的动态 semantics（InkWell button 角色、CircularProgressIndicator
    // 每帧 value 更新、IconButton 关闭按钮等）。
    //
    // 之前的 ExcludeSemantics(整个 tab item) 把 tab 从语义树完全移除，
    // 屏幕阅读器用户无法切换/关闭标签 —— a11y 倒退。
    //
    // selected: isActive 在 activeTabId 变化时翻转，但这是 SemanticsNode 的
    // 属性值更新（AXTree 可处理），非结构翻转。button: true 始终存在，结构稳定。
    return ReorderableDragStartListener(
      key: ValueKey(tab.id),
      index: index,
      child: Semantics(
        button: true,
        selected: isActive,
        label: widget.l.tabLabel(tab.title.isNotEmpty ? tab.title : tab.url),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => ref.read(browserProvider.notifier).setActiveTab(tab.id),
            onSecondaryTapDown: (_) => widget.onShowContextMenu(tab),
            onLongPress: () => widget.onShowContextMenu(tab),
            hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.06),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.sm),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                border: Border(
                  right: BorderSide(color: theme.dividerColor, width: 0.5),
                  bottom: isActive
                      ? BorderSide(color: theme.colorScheme.primary, width: 2)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 条件 Icon 替代 AnimatedSwitcher（与 ai_float / agent_float /
                  // speed_dial_fab 一致）：AnimatedSwitcher + ValueKey 在
                  // loading↔idle 切换时会 unmount + remount 子节点，导致
                  // SemanticsNode 重新创建/销毁 → AXTree diff 失败。
                  // 改用条件渲染，不产生节点替换。CircularProgressIndicator
                  // 的每帧 value 更新已由上层 ExcludeSemantics 屏蔽，无需
                  // 单独包裹。
                  if (tab.isLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      tab.isPinned
                          ? Icons.push_pin_outlined
                          : Icons.language_outlined,
                      size: 12,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.hintColor,
                    ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tab.title.isNotEmpty ? tab.title : tab.url,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isActive ? theme.colorScheme.primary : null,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: DesignTouchTarget.minSize,
                    height: DesignTouchTarget.minSize,
                    child: IconButton(
                      onPressed: () => widget.onCloseTab(tab),
                      icon: Icon(Icons.close, size: 12, color: theme.hintColor),
                      padding: EdgeInsets.zero,
                      tooltip: widget.l.closeTabLabel(tab.title),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

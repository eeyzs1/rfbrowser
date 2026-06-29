import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/browser_tab.dart';
import '../../../services/settings_service.dart';
import '../../theme/design_tokens.dart';
import '../../../l10n/app_localizations.dart';

class BrowserNavigationBar extends ConsumerWidget {
  final BrowserTab activeTab;
  final AppLocalizations l;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onToggleReadingMode;

  const BrowserNavigationBar({
    super.key,
    required this.activeTab,
    required this.l,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onToggleReadingMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final iconSize = ref.watch(settingsProvider).iconSize.toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.sm,
        vertical: DesignSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.arrow_back_outlined,
            tooltip: l.navBack,
            iconSize: iconSize,
            onPressed: canGoBack ? onBack : null,
          ),
          _NavButton(
            icon: Icons.arrow_forward_outlined,
            tooltip: l.navForward,
            iconSize: iconSize,
            onPressed: canGoForward ? onForward : null,
          ),
          _NavButton(
            icon: Icons.refresh_outlined,
            tooltip: l.refresh,
            iconSize: iconSize,
            onPressed: onRefresh,
          ),
          const SizedBox(width: DesignSpacing.sm),
          const Expanded(child: SizedBox.shrink()),
          const SizedBox(width: DesignSpacing.sm),
          _NavButton(
            icon: Icons.menu_book_outlined,
            tooltip: l.readingMode,
            iconSize: iconSize,
            onPressed: onToggleReadingMode,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double iconSize;
  final VoidCallback? onPressed;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.iconSize,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    // 稳定语义策略：外层 Semantics 提供稳定的 button 角色 + label + enabled
    // 状态，内层 ExcludeSemantics 屏蔽 InkWell 的动态 semantics。
    //
    // 之前的 ExcludeSemantics(整个 _NavButton) 把按钮从语义树完全移除，
    // 屏幕阅读器用户无法访问后退/前进/刷新/阅读模式按钮 —— 这是 a11y 倒退。
    //
    // 新策略：InkWell.onTap 仍可为 null（disabled），但被 ExcludeSemantics
    // 屏蔽，其 button 角色出现/消失的结构变化不会到达 AXTree。外层
    // Semantics(button: true, enabled:, label:) 始终贡献稳定的 button 节点，
    // enabled 从 true→false 是属性值更新（AXTree 可处理），非结构翻转。
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Tooltip(
              message: tooltip,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: enabled ? theme.iconTheme.color : theme.disabledColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

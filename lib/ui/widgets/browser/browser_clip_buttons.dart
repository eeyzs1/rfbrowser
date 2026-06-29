import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/settings_service.dart';
import '../../../data/models/browser_tab.dart';
import '../../../l10n/app_localizations.dart';

class BrowserClipButtons extends ConsumerWidget {
  final BrowserTab activeTab;
  final AppLocalizations l;
  final bool isClipping;
  final VoidCallback onClipPage;
  final VoidCallback onClipSelection;

  const BrowserClipButtons({
    super.key,
    required this.activeTab,
    required this.l,
    required this.isClipping,
    required this.onClipPage,
    required this.onClipSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasPage = activeTab.url.isNotEmpty && activeTab.url != 'about:blank';
    final iconSize = ref.watch(settingsProvider).iconSize.toDouble();

    if (isClipping) {
      // ExcludeSemantics：CircularProgressIndicator 内部用
      // AnimationController.repeat() 每帧更新语义 value 属性，持续向
      // AXTree 提交更新。在 AXTree 已脆弱时（启动期间 provider 接连触发
      // 重建）会触发 accessibility_bridge AXTree diff 失败导致进程崩溃。
      // 与 app.dart 启动加载屏、status_bar.dart 同步状态中的
      // CircularProgressIndicator 保持一致的修复模式。
      return SizedBox(
        width: iconSize + 16,
        height: iconSize + 16,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: ExcludeSemantics(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // 移除两个 Semantics(button: true, enabled: hasPage) —— 与 _NavButton
    // 修复同理：IconButton(onPressed != null) 通过合并隐式提供 button 角色，
    // 外层显式 button:true 会形成双重 button 节点。且 hasPage 在 URL 从
    // about:blank → 实际 URL 加载时翻转 false→true，IconButton.onPressed
    // 也从 null → callback，导致 IconButton 的 button semantics 出现/消失，
    // 叠加外层 button:true 的结构不一致，触发 AXTree diff 失败。
    // 用 ExcludeSemantics 包裹整个 Row，彻底消除结构变化。
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l.clipFullPage,
            child: IconButton(
              icon: Icon(
                Icons.content_copy_outlined,
                size: iconSize,
                color: hasPage ? theme.hintColor : theme.disabledColor,
              ),
              onPressed: hasPage ? onClipPage : null,
              padding: const EdgeInsets.all(4),
              constraints: BoxConstraints(
                minWidth: iconSize + 16,
                minHeight: iconSize + 16,
              ),
            ),
          ),
          Tooltip(
            message: l.clipSelection,
            child: IconButton(
              icon: Icon(
                Icons.text_fields_outlined,
                size: iconSize,
                color: hasPage ? theme.hintColor : theme.disabledColor,
              ),
              onPressed: hasPage ? onClipSelection : null,
              padding: const EdgeInsets.all(4),
              constraints: BoxConstraints(
                minWidth: iconSize + 16,
                minHeight: iconSize + 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

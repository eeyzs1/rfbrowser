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

    // 稳定语义策略（与 _NavButton 一致）：每个剪取按钮用
    // Semantics(button, enabled, label) + ExcludeSemantics(IconButton) 提供
    // 稳定的 button 节点。之前的 ExcludeSemantics(整个 Row) 把两个剪取按钮
    // 完全从语义树移除，屏幕阅读器用户无法访问 —— a11y 倒退。
    //
    // hasPage 在 URL 加载时翻转 false→true，IconButton.onPressed 也从
    // null → callback，但被 ExcludeSemantics 屏蔽。外层 Semantics 的
    // enabled 从 false→true 是属性值更新（AXTree 可处理），非结构翻转。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: hasPage,
          label: l.clipFullPage,
          child: ExcludeSemantics(
            child: Tooltip(
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
          ),
        ),
        Semantics(
          button: true,
          enabled: hasPage,
          label: l.clipSelection,
          child: ExcludeSemantics(
            child: Tooltip(
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
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../services/browser_service.dart';
import '../../../data/models/browser_tab.dart';
import '../../../data/models/quick_move.dart';
import '../../../services/quick_move_service.dart';

class BrowserWebViewStack extends ConsumerStatefulWidget {
  final BrowserState browserState;
  final BrowserTab activeTab;
  final Map<String, InAppWebViewController> controllers;
  final Set<String> initializedTabs;
  final void Function(String tabId, String url) onUrlChanged;
  final void Function(InAppWebViewController controller) onNavStateChanged;

  const BrowserWebViewStack({
    super.key,
    required this.browserState,
    required this.activeTab,
    required this.controllers,
    required this.initializedTabs,
    required this.onUrlChanged,
    required this.onNavStateChanged,
  });

  @override
  ConsumerState<BrowserWebViewStack> createState() =>
      _BrowserWebViewStackState();
}

class _BrowserWebViewStackState extends ConsumerState<BrowserWebViewStack> {
  @override
  Widget build(BuildContext context) {
    final closedTabIds = widget.initializedTabs.difference(
      widget.browserState.tabs.map((t) => t.id).toSet(),
    );
    for (final id in closedTabIds) {
      widget.controllers.remove(id);
      widget.initializedTabs.remove(id);
    }

    final webViews = <Widget>[];
    for (final tab in widget.browserState.tabs) {
      final isActive = tab.id == widget.activeTab.id;

      if (!widget.initializedTabs.contains(tab.id)) {
        widget.initializedTabs.add(tab.id);
      }

      webViews.add(
        // ExcludeSemantics 必须包含 AnimatedOpacity 和 Visibility：
        // 它们各自会创建 SemanticsNode（表示 visible/hidden + opacity 状态），
        // 切换 tab 时这些节点状态翻转，触发 Chromium ui::AXTree diff 失败
        // （"Failed to update ui::AXTree, error: N will not be in the tree"）。
        // 这是 root cause：之前的修复只包裹了 InAppWebView 自身，没包裹
        // 动画和可见性 widget，所以每帧/每次切换都向 AXTree 推送更新。
        ExcludeSemantics(
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: Visibility(
              visible: isActive,
              maintainState: isActive,
              maintainSize: false,
              maintainAnimation: false,
              child: InAppWebView(
                key: ValueKey(tab.id),
                initialUrlRequest: URLRequest(url: WebUri(tab.url)),
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                ),
                onWebViewCreated: (controller) {
                  widget.controllers[tab.id] = controller;
                },
                onLoadStart: (controller, url) {
                  ref
                      .read(browserProvider.notifier)
                      .setTabLoading(tab.id, true);
                  if (url != null) {
                    ref
                        .read(browserProvider.notifier)
                        .updateTabUrl(tab.id, url.toString());
                    widget.onUrlChanged(tab.id, url.toString());
                  }
                },
                onLoadStop: (controller, url) async {
                  ref
                      .read(browserProvider.notifier)
                      .setTabLoading(tab.id, false);
                  if (url != null) {
                    ref
                        .read(browserProvider.notifier)
                        .updateTabUrl(tab.id, url.toString());
                  }
                  final title = await controller.getTitle();
                  if (title != null) {
                    ref
                        .read(browserProvider.notifier)
                        .updateTabTitle(tab.id, title);
                  }
                  if (tab.id == ref.read(browserProvider).activeTabId) {
                    _updateQuickMoveContext(controller, url, title);
                    widget.onNavStateChanged(controller);
                  }
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url?.toString() ?? '';
                  final uri = Uri.tryParse(url);
                  if (uri == null) return NavigationActionPolicy.CANCEL;
                  const allowed = {'http', 'https', 'about'};
                  if (!allowed.contains(uri.scheme)) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),
          ),
        ),
      );
    }

    return Stack(children: webViews);
  }

  void _updateQuickMoveContext(
    InAppWebViewController controller,
    Uri? url,
    String? title,
  ) async {
    try {
      final pageText = await controller.evaluateJavascript(
        source: 'document.body.innerText',
      );
      final textContent = pageText is String ? pageText : pageText.toString();
      final ctx = QuickMoveContext(
        currentUrl: url?.toString(),
        pageTitle: title,
        pageContent: textContent,
      );
      ref.read(quickMoveContextProvider.notifier).update(ctx);
    } catch (_) {
      final ctx = QuickMoveContext(
        currentUrl: url?.toString(),
        pageTitle: title,
      );
      ref.read(quickMoveContextProvider.notifier).update(ctx);
    }
  }
}

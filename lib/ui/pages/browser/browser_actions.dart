// ignore_for_file: unused_element, unused_element_parameter

part of '../browser_page.dart';

/// Mixin providing content fetchers, navigation, keyboard shortcuts,
/// and tab management for the browser view.
mixin _BrowserActionsMixin on _BrowserViewStateBase {
  @override
  Future<({String html, String text})> _fetchPageContent(String tabId) async {
    final controller = _controllers[tabId];
    if (controller == null) return (html: '', text: '');
    try {
      final html = await controller.getHtml() ?? '';
      final textResult =
          await controller.evaluateJavascript(
            source: 'document.body.innerText',
          ) ??
          '';
      final text = textResult is String ? textResult : textResult.toString();
      return (html: html, text: text);
    } catch (_) {
      return (html: '', text: '');
    }
  }

  @override
  Future<String> _fetchSelectedText(String tabId) async {
    final controller = _controllers[tabId];
    if (controller == null) return '';
    try {
      final result = await controller.evaluateJavascript(
        source: 'window.getSelection().toString()',
      );
      if (result is String && result.isNotEmpty) return result;
      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<Uint8List?> _takeScreenshot(String tabId) async {
    final controller = _controllers[tabId];
    if (controller == null) return null;
    try {
      return await controller.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          quality: 80,
          compressFormat: CompressFormat.JPEG,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String _buildSearchUrl(String query) {
    final engine = ref.read(settingsProvider).searchEngine;
    return switch (engine) {
      'google' =>
        'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
      'duckduckgo' => 'https://duckduckgo.com/?q=${Uri.encodeComponent(query)}',
      _ => 'https://www.bing.com/search?q=${Uri.encodeComponent(query)}',
    };
  }

  @override
  void _handleKeyboardShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final browserState = ref.read(browserProvider);
    final l = AppLocalizations.of(context);
    if (l == null) return;

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyT) {
      ref.read(browserProvider.notifier).createTab(url: 'https://www.bing.com');
    } else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyW) {
      final activeTab = browserState.activeTab;
      if (activeTab != null) _closeTabWithUndo(activeTab, l);
    } else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyL) {
      _urlFocusNode.requestFocus();
      _urlController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _urlController.text.length,
      );
    } else if (isCtrl &&
        !isShift &&
        event.logicalKey == LogicalKeyboardKey.tab) {
      _cycleTab(browserState, forward: true);
    } else if (isCtrl &&
        isShift &&
        event.logicalKey == LogicalKeyboardKey.tab) {
      _cycleTab(browserState, forward: false);
    } else if (event.logicalKey == LogicalKeyboardKey.f5 ||
        (isCtrl && event.logicalKey == LogicalKeyboardKey.keyR)) {
      final activeTab = browserState.activeTab;
      if (activeTab != null) _controllers[activeTab.id]?.reload();
    } else if (isCtrl && event.logicalKey == LogicalKeyboardKey.digit9) {
      _switchToTabIndex(browserState, browserState.tabs.length - 1);
    } else if (isCtrl) {
      final digit = _digitFromKey(event.logicalKey);
      if (digit != null) _switchToTabIndex(browserState, digit - 1);
    }
  }

  int? _digitFromKey(LogicalKeyboardKey key) {
    final digits = {
      LogicalKeyboardKey.digit1: 1,
      LogicalKeyboardKey.digit2: 2,
      LogicalKeyboardKey.digit3: 3,
      LogicalKeyboardKey.digit4: 4,
      LogicalKeyboardKey.digit5: 5,
      LogicalKeyboardKey.digit6: 6,
      LogicalKeyboardKey.digit7: 7,
      LogicalKeyboardKey.digit8: 8,
    };
    return digits[key];
  }

  void _cycleTab(BrowserState browserState, {required bool forward}) {
    final tabs = browserState.tabs;
    if (tabs.length < 2) return;
    final activeIdx = tabs.indexWhere((t) => t.id == browserState.activeTabId);
    if (activeIdx < 0) return;
    final newIdx = forward
        ? (activeIdx + 1) % tabs.length
        : (activeIdx - 1 + tabs.length) % tabs.length;
    ref.read(browserProvider.notifier).setActiveTab(tabs[newIdx].id);
  }

  void _switchToTabIndex(BrowserState browserState, int index) {
    if (index >= 0 && index < browserState.tabs.length) {
      ref
          .read(browserProvider.notifier)
          .setActiveTab(browserState.tabs[index].id);
    }
  }

  @override
  void _closeTabWithUndo(BrowserTab tab, AppLocalizations l) {
    _recentlyClosed.add(
      _ClosedTabInfo(
        id: tab.id,
        url: tab.url,
        title: tab.title,
        groupId: tab.groupId,
      ),
    );
    if (_recentlyClosed.length > 10) _recentlyClosed.removeAt(0);
    ref.read(browserProvider.notifier).closeTab(tab.id);
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        content: Text(l.tabClosed(tab.title)),
        action: SnackBarAction(
          label: l.undoCloseTab,
          onPressed: () {
            if (_recentlyClosed.isNotEmpty) {
              final info = _recentlyClosed.removeLast();
              ref
                  .read(browserProvider.notifier)
                  .createTab(url: info.url, groupId: info.groupId);
              scaffold.hideCurrentSnackBar();
              scaffold.showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  content: Text(l.tabReopened),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  void _navigateTo(String tabId, String input) {
    FocusScope.of(context).unfocus();
    String url;
    if (input.startsWith('http://') || input.startsWith('https://')) {
      url = input;
    } else if (input.contains('.') && !input.contains(' ')) {
      url = 'https://$input';
    } else {
      url = _buildSearchUrl(input);
    }
    ref.read(browserProvider.notifier).updateTabUrl(tabId, url);
    _controllers[tabId]?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  /// 提取当前网页内容并发送给 AI 对话。
  /// 复用 [_fetchPageContent] 获取页面正文，截断后组装为提示词，
  /// 通过 [aiProvider] 的 sendMessage 发送。
  @override
  void _sendToAi(BrowserTab tab) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    // 立即提示用户正在提取内容
    messenger.showSnackBar(
      SnackBar(
        content: Text(l?.sendingToAi ?? 'Sending page to AI…'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    try {
      final content = await _fetchPageContent(tab.id);
      final text = content.text.trim();
      if (text.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l?.sendToAiEmpty ?? 'No page content to send'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // 截断正文以避免超出 token 限制
      const maxLen = 8000;
      final truncated =
          text.length > maxLen ? '${text.substring(0, maxLen)}…' : text;
      final title = tab.title.isNotEmpty ? tab.title : tab.url;
      final prompt = 'Here is the content from "$title" (${tab.url}):\n\n'
          '$truncated\n\n'
          'Please summarize the key points of this page.';
      ref.read(aiProvider.notifier).sendMessage(prompt);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l?.sendToAiSent ?? 'Page sent to AI'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: l?.openAiChat ?? 'Open AI',
            onPressed: () {
              // 切换到 Capture 场景，AI 浮窗可通过右下角按钮打开
              ref.read(requestContextProvider.notifier).updateScene(
                    AppScene.capture,
                  );
            },
          ),
        ),
      );
    } catch (e) {
      appLog.error('BrowserPage: send to AI failed', error: e);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l?.sendToAiFailed(e.toString()) ?? 'Failed to send to AI: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void _updateNavState(InAppWebViewController controller) async {
    try {
      final canBack = await controller.canGoBack();
      final canForward = await controller.canGoForward();
      if (mounted) {
        setState(() {
          _canGoBack = canBack;
          _canGoForward = canForward;
        });
      }
    } catch (_) {
      appLog.error('BrowserPage: failed to check navigation state');
    }
  }
}

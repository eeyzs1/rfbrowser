import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/settings_service.dart';
import '../../services/ai_service.dart';
import '../../core/ai/request_context.dart';
import '../../core/logging/app_logger.dart';
import '../../data/models/browser_tab.dart';
import '../theme/design_tokens.dart';
import '../widgets/browser/browser_tab_bar.dart';
import '../widgets/browser/browser_nav_bar.dart';
import '../widgets/browser/browser_url_bar.dart';
import '../widgets/browser/browser_bookmark_button.dart';
import '../widgets/browser/browser_clip_buttons.dart';
import '../widgets/browser/browser_webview_stack.dart';
import '../widgets/browser/browser_reading_mode.dart';
import '../../l10n/app_localizations.dart';

part 'browser/browser_widgets.dart';
part 'browser/browser_actions.dart';
part 'browser/browser_dialogs.dart';

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

abstract class _BrowserViewStateBase extends ConsumerState<BrowserView> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  final Map<String, InAppWebViewController> _controllers = {};
  final Set<String> _initializedTabs = {};
  String? _lastActiveTabId;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isClipping = false;
  bool _readingMode = false;
  final List<_ClosedTabInfo> _recentlyClosed = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(browserProvider.notifier)
          .registerContentFetcher(_fetchPageContent);
      ref
          .read(browserProvider.notifier)
          .registerSelectedTextFetcher(_fetchSelectedText);
      ref
          .read(browserProvider.notifier)
          .registerScreenshotFetcher(_takeScreenshot);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _controllers.clear();
    _initializedTabs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(browserProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    if (l == null) return const SizedBox.shrink();
    final activeTab = browserState.activeTab;

    if (activeTab == null) return _buildEmptyState(theme, l, browserState);

    if (_lastActiveTabId != activeTab.id) {
      _urlController.text = activeTab.url == 'about:blank' ? '' : activeTab.url;
      _lastActiveTabId = activeTab.id;
      _readingMode = false;
    }

    return KeyboardListener(
      focusNode: FocusNode(skipTraversal: true),
      onKeyEvent: _handleKeyboardShortcut,
      child: Column(
        children: [
          BrowserTabBar(
            browserState: browserState,
            l: l,
            onCloseTab: (tab) => _closeTabWithUndo(tab, l),
            onShowContextMenu: (tab) =>
                _showTabContextMenu(context, tab, browserState, l),
          ),
          BrowserNavigationBar(
            activeTab: activeTab,
            l: l,
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            onBack: () => _controllers[activeTab.id]?.goBack(),
            onForward: () => _controllers[activeTab.id]?.goForward(),
            onRefresh: () => _controllers[activeTab.id]?.reload(),
            onToggleReadingMode: () =>
                setState(() => _readingMode = !_readingMode),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.sm,
              vertical: DesignSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.appBarTheme.backgroundColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: BrowserUrlBar(
                    activeTab: activeTab,
                    l: l,
                    urlController: _urlController,
                    urlFocusNode: _urlFocusNode,
                    onNavigate: (url) => _navigateTo(activeTab.id, url),
                  ),
                ),
                const SizedBox(width: DesignSpacing.sm),
                BrowserBookmarkButton(
                  activeTab: activeTab,
                  l: l,
                  onAddBookmark: () =>
                      _showAddBookmarkDialog(browserState, activeTab),
                ),
                const SizedBox(width: DesignSpacing.sm),
                BrowserClipButtons(
                  activeTab: activeTab,
                  l: l,
                  isClipping: _isClipping,
                  onClipPage: () => _clipPage(activeTab),
                  onClipSelection: () => _clipSelection(activeTab),
                ),
                const SizedBox(width: DesignSpacing.sm),
                // 发送到 AI 按钮：提取当前网页内容并发送给 AI 对话
                IconButton(
                  tooltip: l.sendToAi,
                  icon: const Icon(Icons.smart_toy_outlined, size: 20),
                  onPressed: () => _sendToAi(activeTab),
                ),
              ],
            ),
          ),
          if (activeTab.isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          Expanded(
            child: Stack(
              children: [
                Platform.isLinux
                    ? _LinuxBrowserPlaceholder(
                        tab: activeTab,
                        onOpenExternal: () => _openExternal(activeTab.url),
                        onNavigate: (url) => _navigateToUrl(url),
                        onClip: () => _clipPage(activeTab),
                      )
                    : BrowserWebViewStack(
                        browserState: browserState,
                        activeTab: activeTab,
                        controllers: _controllers,
                        initializedTabs: _initializedTabs,
                        onUrlChanged: (tabId, url) {
                          if (mounted &&
                              tabId == ref.read(browserProvider).activeTabId) {
                            _urlController.text = url == 'about:blank'
                                ? ''
                                : url;
                          }
                        },
                        onNavStateChanged: _updateNavState,
                      ),
                if (_readingMode && _controllers[activeTab.id] != null)
                  Positioned.fill(
                    child: Material(
                      color: theme.scaffoldBackgroundColor,
                      child: BrowserReadingMode(
                        controller: _controllers[activeTab.id]!,
                        tab: activeTab,
                        l: l,
                        onExit: () => setState(() => _readingMode = false),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    AppLocalizations l,
    BrowserState browserState,
  ) {
    final recentBookmarks = browserState.bookmarks.take(5).toList();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.language_outlined,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(l.startBrowsing, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              l.emptyStateSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref
                  .read(browserProvider.notifier)
                  .createTab(url: 'https://www.bing.com'),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l.newTab),
            ),
            if (recentBookmarks.isNotEmpty) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.recentlyVisited,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: DesignSpacing.sm,
                runSpacing: DesignSpacing.sm,
                children: recentBookmarks
                    .map(
                      (bm) => ActionChip(
                        label: Text(
                          bm.title.isNotEmpty ? bm.title : bm.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        avatar: const Icon(
                          Icons.bookmark_outline_outlined,
                          size: 14,
                        ),
                        onPressed: () => ref
                            .read(browserProvider.notifier)
                            .createTab(url: bm.url),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Abstract declarations for cross-mixin method calls
  Future<({String html, String text})> _fetchPageContent(String tabId);
  Future<String> _fetchSelectedText(String tabId);
  Future<Uint8List?> _takeScreenshot(String tabId);
  void _handleKeyboardShortcut(KeyEvent event);
  void _closeTabWithUndo(BrowserTab tab, AppLocalizations l);
  void _navigateTo(String tabId, String input);
  void _updateNavState(InAppWebViewController controller);
  void _showTabContextMenu(
    BuildContext context,
    BrowserTab tab,
    BrowserState browserState,
    AppLocalizations l,
  );
  void _showAddBookmarkDialog(BrowserState browserState, BrowserTab activeTab);
  void _clipSelection(BrowserTab tab);
  void _clipPage(BrowserTab tab);
  void _sendToAi(BrowserTab tab);
  Future<void> _openExternal(String url);
  void _navigateToUrl(String url);
}

class _BrowserViewState extends _BrowserViewStateBase
    with _BrowserActionsMixin, _BrowserDialogsMixin {}

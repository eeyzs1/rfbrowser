import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/settings_service.dart';
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

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends ConsumerState<BrowserView> {
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

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _controllers.clear();
    _initializedTabs.clear();
    super.dispose();
  }

  String _buildSearchUrl(String query) {
    final engine = ref.read(settingsProvider).searchEngine;
    return switch (engine) {
      'google' => 'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
      'duckduckgo' => 'https://duckduckgo.com/?q=${Uri.encodeComponent(query)}',
      _ => 'https://www.bing.com/search?q=${Uri.encodeComponent(query)}',
    };
  }

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
    } else if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.tab) {
      _cycleTab(browserState, forward: true);
    } else if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.tab) {
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
    final activeIdx =
        tabs.indexWhere((t) => t.id == browserState.activeTabId);
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

  void _closeTabWithUndo(BrowserTab tab, AppLocalizations l) {
    _recentlyClosed.add(_ClosedTabInfo(
      id: tab.id,
      url: tab.url,
      title: tab.title,
      groupId: tab.groupId,
    ));
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
              ref.read(browserProvider.notifier).createTab(
                url: info.url,
                groupId: info.groupId,
              );
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
    } catch (_) {}
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
      _urlController.text =
          activeTab.url == 'about:blank' ? '' : activeTab.url;
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
              ],
            ),
          ),
          if (activeTab.isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          Expanded(
            child: Stack(
              children: [
                Platform.isLinux
                    ? _LinuxBrowserPlaceholder(
                        tab: activeTab,
                        onOpenExternal: () =>
                            _openExternal(activeTab.url),
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
                              tabId ==
                                  ref.read(browserProvider).activeTabId) {
                            _urlController.text =
                                url == 'about:blank' ? '' : url;
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
              child: Icon(Icons.language_outlined,
                  size: 32, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(l.startBrowsing, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(l.emptyStateSubtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor),
                textAlign: TextAlign.center),
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
                child: Text(l.recentlyVisited,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.hintColor)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: DesignSpacing.sm,
                runSpacing: DesignSpacing.sm,
                children: recentBookmarks
                    .map((bm) => ActionChip(
                          label: Text(
                            bm.title.isNotEmpty ? bm.title : bm.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          avatar:
                              const Icon(Icons.bookmark_outline_outlined, size: 14),
                          onPressed: () => ref
                              .read(browserProvider.notifier)
                              .createTab(url: bm.url),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTabContextMenu(
    BuildContext context,
    BrowserTab tab,
    BrowserState browserState,
    AppLocalizations l,
  ) {
    final otherTabs =
        browserState.tabs.where((t) => t.id != tab.id).toList();
    final tabIndex = browserState.tabs.indexOf(tab);
    final rightTabs = browserState.tabs.skip(tabIndex + 1).toList();

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(0, 46, 0, 0),
      items: [
        PopupMenuItem(value: 'close', child: Text(l.closeTab)),
        PopupMenuItem(
          value: 'close_others',
          enabled: otherTabs.isNotEmpty,
          child: Text(l.closeOtherTabs),
        ),
        PopupMenuItem(
          value: 'close_right',
          enabled: rightTabs.isNotEmpty,
          child: Text(l.closeRightTabs),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'copy_url', child: Text(l.copyUrl)),
        PopupMenuItem(
          value: 'pin',
          child: Text(tab.isPinned ? l.unpinTab : l.pinTab),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'close':
          _closeTabWithUndo(tab, l);
          break;
        case 'close_others':
          for (final other in otherTabs) {
            ref.read(browserProvider.notifier).closeTab(other.id);
          }
          break;
        case 'close_right':
          for (final right in rightTabs) {
            ref.read(browserProvider.notifier).closeTab(right.id);
          }
          break;
        case 'copy_url':
          Clipboard.setData(ClipboardData(text: tab.url));
          if (!context.mounted) break;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(l.urlCopied),
            ),
          );
          break;
        case 'pin':
          ref.read(browserProvider.notifier).togglePinTab(tab.id);
          break;
      }
    });
  }

  void _showAddBookmarkDialog(
    BrowserState browserState,
    BrowserTab activeTab,
  ) async {
    final l = AppLocalizations.of(context);
    if (l == null) return;
    final folders = browserState.bookmarkFolders;
    final result = await showDialog<_BookmarkDialogResult>(
      context: context,
      builder: (ctx) => _AddBookmarkDialog(
        folders: folders,
        pageTitle: activeTab.title,
        pageUrl: activeTab.url,
        l: l,
      ),
    );
    if (result != null && mounted) {
      if (result.newFolderName != null) {
        final folderId = ref
            .read(browserProvider.notifier)
            .createBookmarkFolder(result.newFolderName!);
        ref
            .read(browserProvider.notifier)
            .addBookmark(activeTab.url, result.editedTitle, folderId);
      } else {
        ref
            .read(browserProvider.notifier)
            .addBookmark(
                activeTab.url, result.editedTitle, result.selectedFolderId);
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(l.bookmarked(result.editedTitle)),
        ),
      );
    }
  }

  void _clipSelection(BrowserTab tab) async {
    final controller = _controllers[tab.id];
    if (controller == null) return;
    setState(() => _isClipping = true);
    try {
      final selectedText = await controller.evaluateJavascript(
        source: 'window.getSelection().toString()',
      );
      if (selectedText is String && selectedText.isNotEmpty) {
        final note = await ref.read(knowledgeProvider.notifier).clipSelection(
              url: tab.url,
              title: tab.title,
              selectedText: selectedText,
            );
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        if (l == null) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            backgroundColor: DesignColors.semanticSuccess,
            content: Text(l.savedToKnowledgeBase),
            action: SnackBarAction(
              label: l.view,
              onPressed: () =>
                  ref.read(knowledgeProvider.notifier).openNote(note.id),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        if (l != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(l.selectTextFirst),
              backgroundColor: DesignColors.semanticWarning,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      if (l != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(l.clipFailed(e.toString())),
            backgroundColor: DesignColors.semanticError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClipping = false);
    }
  }

  void _clipPage(BrowserTab tab) async {
    final controller = _controllers[tab.id];
    final l = AppLocalizations.of(context);
    if (l == null) return;
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(l.pageNotLoadedYet),
        ),
      );
      return;
    }

    final result = await showDialog<_ClipDialogResult>(
      context: context,
      builder: (ctx) => _ClipDialog(tab: tab, l: l),
    );

    if (result == null || !mounted) return;

    setState(() => _isClipping = true);
    try {
      String content;
      if (result.format == 'bookmark') {
        content =
            '# ${result.editedTitle}\n\n> Source: [${tab.title}](${tab.url})\n';
      } else {
        final html = await controller.getHtml() ?? '';
        final text = await controller.evaluateJavascript(
              source: 'document.body.innerText',
            ) ??
            '';
        final textContent = text is String ? text : text.toString();
        content = switch (result.format) {
          'html' => html,
          'text' => textContent.isNotEmpty ? textContent : html,
          _ => textContent.isNotEmpty ? textContent : html,
        };
        content =
            '# ${result.editedTitle}\n\n> Source: [${tab.title}](${tab.url})\n\n$content';
      }

      await ref.read(knowledgeProvider.notifier).clipToNote(
            url: tab.url,
            title: result.editedTitle,
            content: content,
          );
      if (mounted) {
        final l2 = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            backgroundColor: DesignColors.semanticSuccess,
            content: Text(l2?.clippedTitle(result.editedTitle) ?? ''),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l2 = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(l2?.clipFailed(e.toString()) ?? ''),
            backgroundColor: DesignColors.semanticError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClipping = false);
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _navigateToUrl(String url) {
    if (url.isEmpty) return;
    final normalizedUrl = url.startsWith('http') ? url : 'https://$url';
    final activeTabId = ref.read(browserProvider).activeTabId;
    if (activeTabId != null) {
      ref
          .read(browserProvider.notifier)
          .updateTabUrl(activeTabId, normalizedUrl);
    }
  }
}

class _ClosedTabInfo {
  final String id;
  final String url;
  final String title;
  final String? groupId;
  _ClosedTabInfo(
      {required this.id,
      required this.url,
      required this.title,
      this.groupId});
}

class _BookmarkDialogResult {
  final String selectedFolderId;
  final String editedTitle;
  final String? newFolderName;
  _BookmarkDialogResult(
      {required this.selectedFolderId,
      required this.editedTitle,
      this.newFolderName});
}

class _ClipDialogResult {
  final String format;
  final String editedTitle;
  _ClipDialogResult({required this.format, required this.editedTitle});
}

class _ClipDialog extends StatefulWidget {
  final BrowserTab tab;
  final AppLocalizations l;
  const _ClipDialog({required this.tab, required this.l});

  @override
  State<_ClipDialog> createState() => _ClipDialogState();
}

class _ClipDialogState extends State<_ClipDialog> {
  String _format = 'markdown';
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.tab.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.l;
    return AlertDialog(
      title: Text(l.clipPage),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bookmarkTitle, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _titleController,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.clipFormat, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'markdown', label: Text(l.formatMarkdown)),
              ButtonSegment(value: 'html', label: Text(l.formatHtml)),
              ButtonSegment(value: 'text', label: Text(l.formatPlainText)),
            ],
            selected: {_format},
            onSelectionChanged: (v) => setState(() => _format = v.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              _ClipDialogResult(
                format: _format,
                editedTitle: _titleController.text.isNotEmpty
                    ? _titleController.text
                    : widget.tab.title,
              )),
          child: Text(l.clipPage),
        ),
      ],
    );
  }
}

class _LinuxBrowserPlaceholder extends StatefulWidget {
  final BrowserTab tab;
  final VoidCallback onOpenExternal;
  final ValueChanged<String> onNavigate;
  final VoidCallback onClip;

  const _LinuxBrowserPlaceholder({
    required this.tab,
    required this.onOpenExternal,
    required this.onNavigate,
    required this.onClip,
  });

  @override
  State<_LinuxBrowserPlaceholder> createState() =>
      _LinuxBrowserPlaceholderState();
}

class _LinuxBrowserPlaceholderState extends State<_LinuxBrowserPlaceholder> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.tab.url);
  }

  @override
  void didUpdateWidget(covariant _LinuxBrowserPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab.url != widget.tab.url) {
      _urlController.text = widget.tab.url;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_browser_outlined, size: 48, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(
            l?.searchEngineBing ??
                'Embedded browser is not available on Linux',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 500,
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: l?.searchOrEnterUrl ?? 'Enter URL',
                prefixIcon: const Icon(Icons.language_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_outlined),
                  onPressed: () => widget.onNavigate(_urlController.text),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: widget.onNavigate,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: widget.onOpenExternal,
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(l?.openInBrowser ?? 'Open in System Browser'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onClip,
                icon: const Icon(Icons.content_cut_outlined),
                label: Text(l?.clipPage ?? 'Clip Page to Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddBookmarkDialog extends StatefulWidget {
  final List<BookmarkFolder> folders;
  final String pageTitle;
  final String pageUrl;
  final AppLocalizations l;

  const _AddBookmarkDialog({
    required this.folders,
    required this.pageTitle,
    required this.pageUrl,
    required this.l,
  });

  @override
  State<_AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<_AddBookmarkDialog> {
  String _selectedFolderId = 'bookmarks-bar';
  late TextEditingController _titleController;
  bool _showNewFolder = false;
  final _newFolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.pageTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _newFolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.l;
    return AlertDialog(
      title: Text(l.addBookmark),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bookmarkTitle, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _titleController,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.pageUrl,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Text(l.bookmarkTo, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _selectedFolderId,
            onChanged: (String? value) {
              if (value != null) setState(() => _selectedFolderId = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.folders
                  .map((f) => ListTile(
                        leading: Icon(
                          f.isExpanded
                              ? Icons.folder_open_outlined
                              : Icons.folder_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(f.name),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        trailing: Radio<String>(value: f.id),
                        onTap: () =>
                            setState(() => _selectedFolderId = f.id),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (!_showNewFolder)
            TextButton.icon(
              onPressed: () => setState(() => _showNewFolder = true),
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              label: Text(l.newFolder),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFolderController,
                    decoration: InputDecoration(
                      hintText: l.folderName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                    autofocus: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check_outlined, size: 16),
                  onPressed: () {
                    if (_newFolderController.text.isNotEmpty) {
                      Navigator.pop(
                          context,
                          _BookmarkDialogResult(
                            selectedFolderId: '',
                            editedTitle:
                                _titleController.text.isNotEmpty
                                    ? _titleController.text
                                    : widget.pageTitle,
                            newFolderName: _newFolderController.text,
                          ));
                    }
                  },
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              _BookmarkDialogResult(
                selectedFolderId: _selectedFolderId,
                editedTitle: _titleController.text.isNotEmpty
                    ? _titleController.text
                    : widget.pageTitle,
              )),
          child: Text(l.bookmark),
        ),
      ],
    );
  }
}

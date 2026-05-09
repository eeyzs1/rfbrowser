import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/quick_move_service.dart';
import '../../data/models/browser_tab.dart';
import '../../data/models/quick_move.dart';
import '../../l10n/app_localizations.dart';

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends ConsumerState<BrowserView> {
  final _urlController = TextEditingController();
  final Map<String, InAppWebViewController> _controllers = {};
  final Set<String> _initializedTabs = {};
  String? _lastActiveTabId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(browserProvider.notifier).registerContentFetcher(_fetchPageContent);
      ref.read(browserProvider.notifier).registerSelectedTextFetcher(_fetchSelectedText);
    });
  }

  Future<({String html, String text})> _fetchPageContent(String tabId) async {
    final controller = _controllers[tabId];
    if (controller == null) return (html: '', text: '');
    try {
      final html = await controller.getHtml() ?? '';
      final textResult = await controller.evaluateJavascript(
        source: 'document.body.innerText',
      ) ?? '';
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

  @override
  void dispose() {
    _urlController.dispose();
    _controllers.clear();
    _initializedTabs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(browserProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final activeTab = browserState.activeTab;

    if (activeTab == null) {
      return Center(
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
                Icons.language,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(l.startBrowsing, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              l.openNewTabExplore,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(browserProvider.notifier)
                    .createTab(url: 'https://www.bing.com');
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text(l.newTab),
            ),
          ],
        ),
      );
    }

    if (_lastActiveTabId != activeTab.id) {
      _urlController.text =
          activeTab.url == 'about:blank' ? '' : activeTab.url;
      _lastActiveTabId = activeTab.id;
    }

    return Column(
      children: [
        _buildTabBar(theme, browserState),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              _buildNavButton(
                Icons.arrow_back,
                () => _controllers[activeTab.id]?.goBack(),
              ),
              _buildNavButton(
                Icons.arrow_forward,
                () => _controllers[activeTab.id]?.goForward(),
              ),
              _buildNavButton(
                Icons.refresh,
                () => _controllers[activeTab.id]?.reload(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _urlController,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: l.searchOrEnterUrl,
                      hintStyle: theme.textTheme.bodySmall,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: theme.hintColor,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (url) => _navigateTo(activeTab.id, url),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildBookmarkButton(theme, browserState, activeTab),
            ],
          ),
        ),
        Expanded(
          child: Platform.isLinux
              ? _LinuxBrowserPlaceholder(
                  tab: activeTab,
                  onOpenExternal: () => _openExternal(activeTab.url),
                  onNavigate: (url) => _navigateToUrl(url),
                  onClip: () => _clipCurrentPage(),
                )
              : _buildWebViewStack(browserState, activeTab),
        ),
      ],
    );
  }

  Widget _buildWebViewStack(BrowserState browserState, BrowserTab activeTab) {
    final closedTabIds = _initializedTabs.difference(
      browserState.tabs.map((t) => t.id).toSet(),
    );
    for (final id in closedTabIds) {
      _controllers.remove(id);
      _initializedTabs.remove(id);
    }

    final webViews = <Widget>[];
    for (final tab in browserState.tabs) {
      final isActive = tab.id == activeTab.id;
      if (!_initializedTabs.contains(tab.id)) {
        _initializedTabs.add(tab.id);
      }
      webViews.add(
        Visibility(
          visible: isActive,
          maintainState: true,
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
              _controllers[tab.id] = controller;
            },
            onLoadStart: (controller, url) {
              ref.read(browserProvider.notifier).setTabLoading(tab.id, true);
              if (url != null) {
                ref.read(browserProvider.notifier).updateTabUrl(tab.id, url.toString());
                if (mounted && tab.id == ref.read(browserProvider).activeTabId) {
                  _urlController.text =
                      url.toString() == 'about:blank' ? '' : url.toString();
                }
              }
            },
            onLoadStop: (controller, url) async {
              ref.read(browserProvider.notifier).setTabLoading(tab.id, false);
              if (url != null) {
                ref.read(browserProvider.notifier).updateTabUrl(tab.id, url.toString());
              }
              final title = await controller.getTitle();
              if (title != null) {
                ref.read(browserProvider.notifier).updateTabTitle(tab.id, title);
              }
              if (tab.id == ref.read(browserProvider).activeTabId) {
                _updateQuickMoveContext(controller, url, title);
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              if (url.startsWith('file://') ||
                  url.startsWith('javascript:') ||
                  url.startsWith('data:')) {
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),
        ),
      );
    }

    return Stack(children: webViews);
  }

  void _navigateTo(String tabId, String input) {
    String url;
    if (input.startsWith('http://') || input.startsWith('https://')) {
      url = input;
    } else if (input.contains('.') && !input.contains(' ')) {
      url = 'https://$input';
    } else {
      url = 'https://www.bing.com/search?q=${Uri.encodeComponent(input)}';
    }
    ref.read(browserProvider.notifier).updateTabUrl(tabId, url);
    _controllers[tabId]?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Widget _buildTabBar(ThemeData theme, BrowserState browserState) {
    final l = AppLocalizations.of(context)!;
    final tabs = browserState.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length + 1,
        itemBuilder: (context, index) {
          if (index == tabs.length) {
            return IconButton(
              icon: Icon(Icons.add, size: 16, color: theme.hintColor),
              onPressed: () => ref.read(browserProvider.notifier).createTab(url: 'https://www.bing.com'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: l.newTab,
            );
          }
          final tab = tabs[index];
          final isActive = tab.id == browserState.activeTabId;
          return GestureDetector(
            onTap: () => ref.read(browserProvider.notifier).setActiveTab(tab.id),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
                border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tab.isLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.colorScheme.primary),
                    )
                  else
                    Icon(Icons.language, size: 12, color: isActive ? theme.colorScheme.primary : theme.hintColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tab.title.isNotEmpty ? tab.title : tab.url,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive ? theme.colorScheme.primary : null,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => ref.read(browserProvider.notifier).closeTab(tab.id),
                    child: Icon(Icons.close, size: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookmarkButton(ThemeData theme, BrowserState browserState, BrowserTab activeTab) {
    final l = AppLocalizations.of(context)!;
    final isBookmarked = browserState.isBookmarked(activeTab.url);
    return IconButton(
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        size: 18,
        color: isBookmarked ? theme.colorScheme.primary : theme.hintColor,
      ),
      onPressed: () {
        if (isBookmarked) {
          ref.read(browserProvider.notifier).removeBookmark(
            browserState.bookmarks.firstWhere((b) => b.url == activeTab.url).id,
          );
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(duration: const Duration(seconds: 2), content: Text(l.unbookmarked)),
          );
        } else {
          _showAddBookmarkDialog(browserState, activeTab);
        }
      },
      tooltip: isBookmarked ? l.unbookmark : l.bookmarkThisPage,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  void _showAddBookmarkDialog(BrowserState browserState, BrowserTab activeTab) async {
    final l = AppLocalizations.of(context)!;
    final folders = browserState.bookmarkFolders;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return _AddBookmarkDialog(folders: folders, pageTitle: activeTab.title, pageUrl: activeTab.url);
      },
    );
    if (result != null && mounted) {
      ref.read(browserProvider.notifier).addBookmark(activeTab.url, activeTab.title, result);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), content: Text(l.bookmarked(activeTab.title))),
      );
    }
  }

  Widget _buildNavButton(
    IconData icon,
    VoidCallback onPressed, {
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: theme.iconTheme.color),
          ),
        ),
      ),
    );
  }

  void _clipPage(BrowserTab tab) async {
    final controller = _controllers[tab.id];
    if (controller == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Page not loaded yet')));
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Clip Page'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'full'),
            child: const Row(
              children: [
                Icon(Icons.description, size: 16),
                SizedBox(width: 8),
                Text('Full Page'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'bookmark'),
            child: const Row(
              children: [
                Icon(Icons.bookmark, size: 16),
                SizedBox(width: 8),
                Text('Bookmark'),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    try {
      if (choice == 'bookmark') {
        await ref
            .read(knowledgeProvider.notifier)
            .clipToNote(
              url: tab.url,
              title: tab.title,
              content:
                  '# ${tab.title}\n\n> Source: [${tab.title}](${tab.url})\n',
            );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Bookmarked: ${tab.title}')));
        }
      } else {
        final html = await controller.getHtml() ?? '';
        final text =
            await controller.evaluateJavascript(
              source: 'document.body.innerText',
            ) ??
            '';
        final textContent = text is String ? text : text.toString();
        await ref
            .read(knowledgeProvider.notifier)
            .clipToNote(
              url: tab.url,
              title: tab.title,
              content: textContent.isNotEmpty ? textContent : html,
            );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Clipped: ${tab.title}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Clip failed: $e')));
      }
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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

  Future<void> _updateQuickMoveContext(
    InAppWebViewController controller,
    Uri? url,
    String? title,
  ) async {
    try {
      final pageText = await controller.evaluateJavascript(
        source: 'document.body.innerText',
      );
      final textContent =
          pageText is String ? pageText : pageText.toString();

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

  void _clipCurrentPage() {
    final activeTab = ref.read(browserProvider).activeTab;
    if (activeTab != null) {
      _clipPage(activeTab);
    }
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_browser, size: 48, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(
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
                hintText: 'Enter URL',
                prefixIcon: const Icon(Icons.language),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
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
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in System Browser'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onClip,
                icon: const Icon(Icons.content_cut),
                label: const Text('Clip Page to Note'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Tip: Use the system browser for full web browsing, or clip pages to your vault for offline reading.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
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

  const _AddBookmarkDialog({
    required this.folders,
    required this.pageTitle,
    required this.pageUrl,
  });

  @override
  State<_AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<_AddBookmarkDialog> {
  String _selectedFolderId = 'bookmarks-bar';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.addBookmark),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.pageTitle,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
              children: widget.folders.map((f) => ListTile(
                leading: Icon(
                  f.isExpanded ? Icons.folder_open : Icons.folder,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                title: Text(f.name),
                dense: true,
                contentPadding: EdgeInsets.zero,
                trailing: Radio<String>(value: f.id),
                onTap: () => setState(() => _selectedFolderId = f.id),
              )).toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedFolderId),
          child: Text(l.bookmark),
        ),
      ],
    );
  }
}

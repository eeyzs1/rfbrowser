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

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends ConsumerState<BrowserView> {
  final _urlController = TextEditingController();
  final Map<String, InAppWebViewController> _controllers = {};
  String? _lastActiveTabId;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(browserProvider);
    final theme = Theme.of(context);
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
            Text('Start Browsing', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Open a new tab to explore the web',
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
              label: const Text('New Tab'),
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
                      hintText: 'Search or enter URL...',
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
              _buildNavButton(
                Icons.bookmark_add_outlined,
                () => _clipPage(activeTab),
                tooltip: 'Clip Page',
              ),
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
              : InAppWebView(
                  key: ValueKey(activeTab.id),
                  initialUrlRequest: URLRequest(url: WebUri(activeTab.url)),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                  ),
                  onWebViewCreated: (controller) {
                    _controllers[activeTab.id] = controller;
                  },
                  onLoadStart: (controller, url) {
                    ref
                        .read(browserProvider.notifier)
                        .setTabLoading(activeTab.id, true);
                    if (url != null) {
                      ref
                          .read(browserProvider.notifier)
                          .updateTabUrl(activeTab.id, url.toString());
                    }
                  },
                  onLoadStop: (controller, url) async {
                    ref
                        .read(browserProvider.notifier)
                        .setTabLoading(activeTab.id, false);
                    if (url != null) {
                      ref
                          .read(browserProvider.notifier)
                          .updateTabUrl(activeTab.id, url.toString());
                    }
                    final title = await controller.getTitle();
                    if (title != null) {
                      ref
                          .read(browserProvider.notifier)
                          .updateTabTitle(activeTab.id, title);
                    }
                    _updateQuickMoveContext(controller, url, title);
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                        final url =
                            navigationAction.request.url?.toString() ?? '';
                        if (url.startsWith('file://') ||
                            url.startsWith('javascript:') ||
                            url.startsWith('data:')) {
                          return NavigationActionPolicy.CANCEL;
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                ),
        ),
      ],
    );
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

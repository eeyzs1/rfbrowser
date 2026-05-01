import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/browser_service.dart';
import '../../data/models/browser_tab.dart';

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends ConsumerState<BrowserView> {
  final _urlController = TextEditingController();
  final Map<String, InAppWebViewController> _controllers = {};

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
                    .createTab(url: 'https://www.google.com');
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Tab'),
            ),
          ],
        ),
      );
    }

    _urlController.text = activeTab.url == 'about:blank' ? '' : activeTab.url;

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
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
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
      url = 'https://www.google.com/search?q=${Uri.encodeComponent(input)}';
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

  void _clipPage(BrowserTab tab) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Clipping: ${tab.title}')));
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _LinuxBrowserPlaceholder extends StatelessWidget {
  final BrowserTab tab;
  final VoidCallback onOpenExternal;

  const _LinuxBrowserPlaceholder({
    required this.tab,
    required this.onOpenExternal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_browser, size: 48, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(
            'Embedded browser is not yet available on Linux',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tab.url,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenExternal,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in System Browser'),
          ),
        ],
      ),
    );
  }
}

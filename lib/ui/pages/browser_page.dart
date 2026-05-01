import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
            Icon(Icons.language, size: 64, color: theme.hintColor),
            const SizedBox(height: 16),
            Text('No tab open', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Open a new tab to start browsing',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(browserProvider.notifier)
                    .createTab(url: 'https://www.google.com');
              },
              icon: const Icon(Icons.add),
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
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: () => _controllers[activeTab.id]?.goBack(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: () => _controllers[activeTab.id]?.goForward(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => _controllers[activeTab.id]?.reload(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Enter URL or search...',
                    hintStyle: theme.textTheme.bodySmall,
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (url) => _navigateTo(activeTab.id, url),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                onPressed: () => _clipPage(activeTab),
                tooltip: 'Clip Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        Expanded(
          child: InAppWebView(
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
            shouldOverrideUrlLoading: (controller, navigationAction) async {
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

  void _clipPage(BrowserTab tab) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Clipping: ${tab.title}')));
  }
}

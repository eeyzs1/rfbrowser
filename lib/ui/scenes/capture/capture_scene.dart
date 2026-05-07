import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/browser_service.dart';
import '../../../services/ai_service.dart';
import '../../widgets/note_sidebar.dart';
import '../../widgets/clip_toolbar.dart';
import '../../widgets/ai_float.dart';
import '../../pages/browser_page.dart';

class CaptureScene extends ConsumerWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;

  const CaptureScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final browserState = ref.watch(browserProvider);
    final currentUrl = browserState.activeTab?.url;
    final hasUrl = currentUrl != null && currentUrl.isNotEmpty && currentUrl != 'about:blank';

    return Stack(
      children: [
        Row(
          children: [
            if (leftPanelExpanded)
              const SizedBox(width: 240, child: NoteSidebar()),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: hasUrl
                        ? const BrowserView()
                        : _buildBrowserEmptyState(theme),
                  ),
                  const ClipToolbar(),
                ],
              ),
            ),
            if (rightPanelExpanded)
              SizedBox(
                width: 280,
                child: _AiSummaryPanel(
                  url: currentUrl,
                  pageTitle: browserState.activeTab?.title,
                ),
              ),
          ],
        ),
        const Positioned(right: 0, bottom: 0, child: AIFloat()),
      ],
    );
  }

  Widget _buildBrowserEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.language,
            size: 48,
            color: theme.hintColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '输入网址或搜索...',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _AiSummaryPanel extends ConsumerStatefulWidget {
  final String? url;
  final String? pageTitle;

  const _AiSummaryPanel({this.url, this.pageTitle});

  @override
  ConsumerState<_AiSummaryPanel> createState() => _AiSummaryPanelState();
}

class _AiSummaryPanelState extends ConsumerState<_AiSummaryPanel> {
  String? _summary;
  bool _isLoading = false;
  String? _error;

  void _requestSummary() {
    if (_isLoading || widget.url == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final aiNotifier = ref.read(aiProvider.notifier);
    aiNotifier.clearMessages();
    final pageInfo =
        '${widget.pageTitle ?? 'Page'}\n${widget.url!}';

    aiNotifier.sendMessage(
      'Please summarize the main content and key points of this web page in Chinese:\n\n$pageInfo',
      systemPrompt:
          'You are a helpful research assistant. Provide concise, well-structured summaries in Chinese. Focus on key arguments, findings, and insights.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = widget.url != null && widget.url!.isNotEmpty;

    ref.listen(aiProvider, (prev, next) {
      final lastMsg = next.messages.isNotEmpty ? next.messages.last : null;
      if (lastMsg != null && lastMsg.role == 'assistant') {
        setState(() {
          _summary = lastMsg.content;
          _isLoading = next.isLoading;
          _error = next.error;
        });
      } else if (!next.isLoading && next.error != null) {
        setState(() {
          _isLoading = false;
          _error = next.error;
        });
      } else {
        setState(() {
          _isLoading = next.isLoading;
        });
      }
    });

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI 页面摘要',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasUrl && !_isLoading)
                  IconButton(
                    icon: Icon(Icons.refresh, size: 16, color: theme.colorScheme.primary),
                    onPressed: _requestSummary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: '生成摘要',
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildContent(theme, hasUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool hasUrl) {
    if (!hasUrl) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_browser, size: 32,
                  color: theme.hintColor.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text('打开网页后可使用 AI 摘要',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 32, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ), textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _requestSummary,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_summary == null && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.summarize, size: 32,
                  color: theme.hintColor.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text('点击按钮生成 AI 页面摘要',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _requestSummary,
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('生成摘要'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading && (_summary == null || _summary!.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.url != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.url!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SelectableText(
            _summary ?? '',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
        ],
      ),
    );
  }
}

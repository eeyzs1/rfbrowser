import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/browser_service.dart';
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
              SizedBox(width: 280, child: _buildAISummaryPlaceholder(theme)),
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

  Widget _buildAISummaryPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology,
              size: 32,
              color: theme.hintColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'AI 摘要',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

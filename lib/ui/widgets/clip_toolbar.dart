import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../theme/design_tokens.dart';

class ClipToolbar extends ConsumerStatefulWidget {
  const ClipToolbar({super.key});

  @override
  ConsumerState<ClipToolbar> createState() => _ClipToolbarState();
}

class _ClipToolbarState extends ConsumerState<ClipToolbar> {
  bool _isClipping = false;

  Future<void> _clipFullPage() async {
    final browserState = ref.read(browserProvider);
    final tab = browserState.activeTab;
    if (tab == null) return;

    setState(() => _isClipping = true);
    try {
      final knowledgeNotifier = ref.read(knowledgeProvider.notifier);
      await knowledgeNotifier.clipFullPage(
        url: tab.url,
        title: tab.title,
        htmlContent: '',
        textContent: '',
      );
      _showToast('已保存到知识库');
    } catch (e) {
      _showToast('剪辑失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isClipping = false);
    }
  }

  Future<void> _clipSelection() async {
    final browserState = ref.read(browserProvider);
    final tab = browserState.activeTab;
    if (tab == null) return;

    setState(() => _isClipping = true);
    try {
      final knowledgeNotifier = ref.read(knowledgeProvider.notifier);
      await knowledgeNotifier.clipSelection(
        url: tab.url,
        title: '${tab.title} · 片段',
        selectedText: '',
      );
      _showToast('已保存到知识库');
    } catch (e) {
      _showToast('剪辑失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isClipping = false);
    }
  }

  Future<void> _clipBookmark() async {
    final browserState = ref.read(browserProvider);
    final tab = browserState.activeTab;
    if (tab == null) return;

    setState(() => _isClipping = true);
    try {
      final knowledgeNotifier = ref.read(knowledgeProvider.notifier);
      await knowledgeNotifier.clipBookmark(
        url: tab.url,
        title: tab.title,
      );
      _showToast('已保存到知识库');
    } catch (e) {
      _showToast('剪辑失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isClipping = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? DesignColors.semanticError
            : DesignColors.semanticSuccess,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final browserState = ref.watch(browserProvider);
    final hasPage = browserState.activeTab != null &&
        browserState.activeTab!.url.isNotEmpty &&
        browserState.activeTab!.url != 'about:blank';

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isClipping)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            _ClipButton(
              icon: Icons.content_copy,
              label: '剪辑全文',
              onPressed: hasPage ? _clipFullPage : null,
            ),
            const SizedBox(width: DesignSpacing.sm),
            _ClipButton(
              icon: Icons.text_fields,
              label: '剪辑选中',
              onPressed: hasPage ? _clipSelection : null,
            ),
            const SizedBox(width: DesignSpacing.sm),
            _ClipButton(
              icon: Icons.bookmark_outline,
              label: '书签',
              onPressed: hasPage ? _clipBookmark : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _ClipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ClipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 14,
        color: onPressed != null ? null : Theme.of(context).disabledColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: onPressed != null ? null : Theme.of(context).disabledColor,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.sm,
          vertical: DesignSpacing.xs,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

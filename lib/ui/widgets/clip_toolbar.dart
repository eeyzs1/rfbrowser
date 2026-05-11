import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/browser_service.dart';
import '../../services/knowledge_service.dart';
import '../../l10n/app_localizations.dart';
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
      final content = await ref
          .read(browserProvider.notifier)
          .fetchPageContent(tab.id);
      final htmlContent = content?.html ?? '';
      final textContent = content?.text ?? '';
      final knowledgeNotifier = ref.read(knowledgeProvider.notifier);
      final note = await knowledgeNotifier.clipFullPage(
        url: tab.url,
        title: tab.title,
        htmlContent: htmlContent,
        textContent: textContent.isNotEmpty ? textContent : htmlContent,
        tabId: tab.id,
      );
      _showClipSuccess(note.title, note.id);
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      if (l != null) _showToast(l.clipFailed(e.toString()), isError: true);
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
      final selectedText = await ref
          .read(browserProvider.notifier)
          .fetchSelectedText(tab.id);
      if (selectedText.isEmpty) {
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        if (l != null) _showToast(l.selectTextFirst, isError: true);
        return;
      }
      final knowledgeNotifier = ref.read(knowledgeProvider.notifier);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      if (l == null) return;
      final note = await knowledgeNotifier.clipSelection(
        url: tab.url,
        title: l.clipTitle(tab.title),
        selectedText: selectedText,
      );
      _showClipSuccess(note.title, note.id);
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      if (l != null) _showToast(l.clipFailed(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isClipping = false);
    }
  }

  void _toggleBookmark() {
    final browserState = ref.read(browserProvider);
    final tab = browserState.activeTab;
    if (tab == null) return;

    final isBookmarked = browserState.isBookmarked(tab.url);
    final l = AppLocalizations.of(context);
    if (l == null) return;
    ref.read(browserProvider.notifier).toggleBookmark(tab.url, tab.title);
    _showToast(isBookmarked ? l.unbookmarked : l.bookmarked(tab.title));
  }

  void _showClipSuccess(String title, String noteId) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    if (l == null) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: DesignColors.semanticSuccess,
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.onInverseSurface,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.savedToKnowledgeBase,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: l.view,
          textColor: Theme.of(context).colorScheme.onInverseSurface,
          onPressed: () {
            ref.read(knowledgeProvider.notifier).openNote(noteId);
          },
        ),
      ),
    );
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
    final l = AppLocalizations.of(context);
    if (l == null) {
      return const SizedBox.shrink();
    }
    final browserState = ref.watch(browserProvider);
    final hasPage =
        browserState.activeTab != null &&
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
              label: l.clipFullPage,
              onPressed: hasPage ? _clipFullPage : null,
            ),
            const SizedBox(width: DesignSpacing.sm),
            _ClipButton(
              icon: Icons.text_fields,
              label: l.clipSelection,
              onPressed: hasPage ? _clipSelection : null,
            ),
            const SizedBox(width: DesignSpacing.sm),
            _ClipButton(
              icon: browserState.isBookmarked(browserState.activeTab?.url ?? '')
                  ? Icons.bookmark
                  : Icons.bookmark_outline,
              label:
                  browserState.isBookmarked(browserState.activeTab?.url ?? '')
                  ? l.bookmark
                  : l.bookmark,
              onPressed: hasPage ? _toggleBookmark : null,
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

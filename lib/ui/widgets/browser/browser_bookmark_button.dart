import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/browser_service.dart';
import '../../../services/settings_service.dart';
import '../../../data/models/browser_tab.dart';
import '../../../l10n/app_localizations.dart';

class BrowserBookmarkButton extends ConsumerWidget {
  final BrowserTab activeTab;
  final AppLocalizations l;
  final VoidCallback onAddBookmark;

  const BrowserBookmarkButton({
    super.key,
    required this.activeTab,
    required this.l,
    required this.onAddBookmark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final browserState = ref.watch(browserProvider);
    final isBookmarked = browserState.isBookmarked(activeTab.url);
    final iconSize = ref.watch(settingsProvider).iconSize.toDouble();

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
          child: child,
        ),
        child: Icon(
          isBookmarked ? Icons.bookmark : Icons.bookmark_border_outlined,
          key: ValueKey(isBookmarked),
          size: iconSize,
          color: isBookmarked ? theme.colorScheme.primary : theme.hintColor,
        ),
      ),
      onPressed: () {
        if (isBookmarked) {
          ref
              .read(browserProvider.notifier)
              .removeBookmark(
                browserState.bookmarks
                    .firstWhere((b) => b.url == activeTab.url)
                    .id,
              );
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(l.unbookmarked),
            ),
          );
        } else {
          onAddBookmark();
        }
      },
      tooltip: isBookmarked ? l.unbookmark : l.bookmarkThisPage,
      padding: const EdgeInsets.all(4),
      constraints: BoxConstraints(minWidth: iconSize + 16, minHeight: iconSize + 16),
    );
  }
}

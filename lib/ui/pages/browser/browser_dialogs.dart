// ignore_for_file: unused_element, unused_element_parameter

part of '../browser_page.dart';

/// Mixin providing dialog and clipping actions for the browser view.
mixin _BrowserDialogsMixin on _BrowserViewStateBase {
  @override
  void _showTabContextMenu(
    BuildContext context,
    BrowserTab tab,
    BrowserState browserState,
    AppLocalizations l,
  ) {
    final otherTabs = browserState.tabs.where((t) => t.id != tab.id).toList();
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

  @override
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
              activeTab.url,
              result.editedTitle,
              result.selectedFolderId,
            );
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

  @override
  void _clipSelection(BrowserTab tab) async {
    final controller = _controllers[tab.id];
    if (controller == null) return;
    setState(() => _isClipping = true);
    try {
      final selectedText = await controller.evaluateJavascript(
        source: 'window.getSelection().toString()',
      );
      if (selectedText is String && selectedText.isNotEmpty) {
        final note = await ref
            .read(knowledgeProvider.notifier)
            .clipSelection(
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

  @override
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
        final text =
            await controller.evaluateJavascript(
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

      await ref
          .read(knowledgeProvider.notifier)
          .clipToNote(
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

  @override
  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
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

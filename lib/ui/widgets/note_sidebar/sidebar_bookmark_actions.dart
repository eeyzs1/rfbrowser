part of '../note_sidebar.dart';

mixin _SidebarBookmarkActionsMixin on _NoteSidebarStateBase {
  @override
  void _createBookmarkFolder(String parentFolderId) async {
    final l = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l.newBookmarkFolder),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l.bookmarkFolderName,
              isDense: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l.create),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      ref
          .read(browserProvider.notifier)
          .createBookmarkFolder(name, parentId: parentFolderId);
    }
  }

  @override
  void _renameBookmarkFolder(BookmarkFolder folder) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.renameBookmarkFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != folder.name) {
      ref
          .read(browserProvider.notifier)
          .renameBookmarkFolder(folder.id, newName);
    }
  }

  @override
  void _confirmDeleteBookmarkFolder(String name, String folderId) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteBookmarkFolder),
        content: Text(l.deleteBookmarkFolderConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(browserProvider.notifier).deleteBookmarkFolder(folderId);
    }
  }

  @override
  void _showMoveBookmarkDialog(Bookmark bookmark) async {
    final l = AppLocalizations.of(context)!;
    final folders = ref.read(browserProvider).bookmarkFolders;
    if (folders.isEmpty) return;
    final folderId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.moveTo),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(l.uncategorized),
          ),
          ...folders.map(
            (f) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f.id),
              child: Text(f.name),
            ),
          ),
        ],
      ),
    );
    if (folderId != null) {
      ref
          .read(browserProvider.notifier)
          .moveBookmarkToFolder(bookmark.id, folderId);
    }
  }
}

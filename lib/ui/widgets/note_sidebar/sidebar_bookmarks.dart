part of '../note_sidebar.dart';

mixin _SidebarBookmarksMixin on _NoteSidebarStateBase {
  Widget _buildBookmarksToolbar(ThemeData theme, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.sm,
        vertical: DesignSpacing.xs + 2,
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark, size: 14, color: theme.hintColor),
          const SizedBox(width: 6),
          Text(
            l.bookmarkCount(ref.watch(browserProvider).bookmarks.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
              fontSize: _baseFontSize,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder, size: 14),
            onPressed: () => _createBookmarkFolder('bookmarks-bar'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: l.newBookmarkFolder,
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksTree(ThemeData theme, AppLocalizations l) {
    final browserState = ref.watch(browserProvider);
    final bookmarks = browserState.bookmarks;
    final folders = browserState.bookmarkFolders;

    if (bookmarks.isEmpty && folders.length <= 1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 32,
              color: theme.hintColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              l.noBookmarks,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.bookmarkHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontSize: _baseFontSize,
              ),
            ),
          ],
        ),
      );
    }

    final items = <Widget>[];
    final barBookmarks = bookmarks
        .where((b) => b.folderId == 'bookmarks-bar')
        .toList();
    for (final bm in barBookmarks) {
      items.add(_bookmarkRow(bm, 0, l));
    }
    _buildBookmarkFolderWidgets(
      folders,
      bookmarks,
      'bookmarks-bar',
      0,
      items,
      l,
    );
    final unfiled = bookmarks.where((b) => b.folderId.isEmpty).toList();
    if (unfiled.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 6, bottom: 2),
          child: Text(
            l.uncategorized,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: _baseFontSize - 1,
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
            ),
          ),
        ),
      );
      for (final bm in unfiled) {
        items.add(_bookmarkRow(bm, 1, l));
      }
    }
    return ListView(children: items);
  }

  void _buildBookmarkFolderWidgets(
    List<BookmarkFolder> allFolders,
    List<Bookmark> allBookmarks,
    String parentId,
    int depth,
    List<Widget> items,
    AppLocalizations l,
  ) {
    final childFolders = allFolders
        .where((f) => f.parentId == parentId)
        .toList();
    for (final folder in childFolders) {
      final folderBookmarks = allBookmarks
          .where((b) => b.folderId == folder.id)
          .toList();
      final isExpanded = _expandedBookmarkFolders.contains(folder.id);
      final isHovered = _hoveredBookmarkFolder == folder.id;
      final totalBookmarks = _countBookmarksInFolder(
        allFolders,
        allBookmarks,
        folder.id,
      );

      items.add(
        DragTarget<String>(
          onWillAcceptWithDetails: (details) => _draggingBookmarkId != null,
          onAcceptWithDetails: (details) {
            if (_draggingBookmarkId != null) {
              ref
                  .read(browserProvider.notifier)
                  .moveBookmarkToFolder(_draggingBookmarkId!, folder.id);
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isDragOver = candidateData.isNotEmpty;
            final theme = Theme.of(context);
            return MouseRegion(
              onEnter: (_) =>
                  setState(() => _hoveredBookmarkFolder = folder.id),
              onExit: (_) => setState(() => _hoveredBookmarkFolder = null),
              child: Container(
                padding: EdgeInsets.only(left: depth * 14.0 + 4.0),
                color: isDragOver
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : isHovered
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      )
                    : null,
                child: InkWell(
                  onTap: () {
                    ref
                        .read(browserProvider.notifier)
                        .toggleBookmarkFolder(folder.id);
                    setState(() {
                      if (isExpanded) {
                        _expandedBookmarkFolders.remove(folder.id);
                      } else {
                        _expandedBookmarkFolders.add(folder.id);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                          size: 14,
                          color: Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isExpanded ? Icons.folder_open : Icons.folder,
                          size: 15,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            folder.name,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: _baseFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isHovered && folder.id != 'bookmarks-bar') ...[
                          _ib(
                            Icons.create_new_folder,
                            () => _createBookmarkFolder(folder.id),
                            l.newSubBookmarkFolder,
                          ),
                          _ib(
                            Icons.edit,
                            () => _renameBookmarkFolder(folder),
                            l.rename,
                          ),
                          _ib(
                            Icons.delete_outline,
                            () => _confirmDeleteBookmarkFolder(
                              folder.name,
                              folder.id,
                            ),
                            l.delete,
                          ),
                        ],
                        if (isHovered && folder.id == 'bookmarks-bar')
                          _ib(
                            Icons.create_new_folder,
                            () => _createBookmarkFolder(folder.id),
                            l.newSubBookmarkFolder,
                          ),
                        if (!isHovered && totalBookmarks > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '$totalBookmarks',
                              style: TextStyle(
                                fontSize: _baseFontSize - 2,
                                color: Theme.of(
                                  context,
                                ).hintColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      if (isExpanded) {
        _buildBookmarkFolderWidgets(
          allFolders,
          allBookmarks,
          folder.id,
          depth + 1,
          items,
          l,
        );
        for (final bm in folderBookmarks) {
          items.add(_bookmarkRow(bm, depth + 1, l));
        }
      }
    }
  }

  int _countBookmarksInFolder(
    List<BookmarkFolder> allFolders,
    List<Bookmark> allBookmarks,
    String folderId, {
    Set<String>? visited,
  }) {
    visited ??= {};
    if (visited.contains(folderId)) return 0;
    visited.add(folderId);
    var count = allBookmarks.where((b) => b.folderId == folderId).length;
    for (final f in allFolders.where(
      (f) => f.parentId == folderId && f.id != folderId,
    )) {
      count += _countBookmarksInFolder(
        allFolders,
        allBookmarks,
        f.id,
        visited: visited,
      );
    }
    return count;
  }
}

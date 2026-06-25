part of '../note_sidebar.dart';

/// Bookmark row rendering for the sidebar bookmarks tab.
///
/// Extracted from [_SidebarBookmarksMixin] to keep the folder-tree building
/// and the individual bookmark-row rendering in separate files. Provides
/// [_bookmarkRow] (consumed by the folder builder via an abstract declaration
/// on the host) plus the small [_favicon] and [_domain] helpers.
mixin _SidebarBookmarkRowMixin on _NoteSidebarStateBase {
  @override
  Widget _bookmarkRow(Bookmark bookmark, int depth, AppLocalizations l) {
    final isHovered = _hoveredBookmarkId == bookmark.id;
    return Draggable<String>(
      data: bookmark.id,
      onDragStarted: () => setState(() => _draggingBookmarkId = bookmark.id),
      onDragEnd: (_) => setState(() => _draggingBookmarkId = null),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.sm,
            vertical: DesignSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                bookmark.title,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: _baseFontSize),
              ),
            ],
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredBookmarkId = bookmark.id),
        onExit: (_) => setState(() => _hoveredBookmarkId = null),
        child: InkWell(
          onTap: () => widget.onBookmarkOpened?.call(bookmark.url),
          child: Container(
            padding: EdgeInsets.only(
              left: depth * 14.0 + 18.0,
              right: DesignSpacing.xs,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DesignSpacing.xs,
                horizontal: DesignSpacing.xs,
              ),
              child: Row(
                children: [
                  _favicon(bookmark),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookmark.title,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: _baseFontSize),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_domain(bookmark).isNotEmpty)
                          Text(
                            _domain(bookmark),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: _baseFontSize - 2,
                                  color: Theme.of(context).hintColor,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (isHovered) ...[
                    _ib(
                      Icons.drive_file_move_outline,
                      () => _showMoveBookmarkDialog(bookmark),
                      l.move,
                    ),
                    _ib(
                      Icons.close,
                      () => ref
                          .read(browserProvider.notifier)
                          .removeBookmark(bookmark.id),
                      l.remove,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _favicon(Bookmark bookmark) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(
          bookmark.title.isNotEmpty ? bookmark.title[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: _baseFontSize - 3,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  String _domain(Bookmark bookmark) {
    final uri = Uri.tryParse(bookmark.url);
    return uri?.host.replaceAll('www.', '') ?? '';
  }
}

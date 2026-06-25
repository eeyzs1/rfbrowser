part of '../note_sidebar.dart';

mixin _SidebarNotesToolbarMixin on _NoteSidebarStateBase {
  Widget _buildNotesToolbar(ThemeData theme, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.all(DesignSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodySmall,
              decoration: InputDecoration(
                hintText: l.searchNotes,
                hintStyle: theme.textTheme.bodySmall,
                prefixIcon: const Icon(Icons.search, size: 14),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: DesignSpacing.xs + 2,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 12),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        constraints: const BoxConstraints(
                          minWidth: DesignTouchTarget.minSize * 0.5,
                          minHeight: DesignTouchTarget.minSize * 0.5,
                        ),
                      )
                    : null,
              ),
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),
          const SizedBox(width: DesignSpacing.xs),
          IconButton(
            icon: const Icon(Icons.create_new_folder, size: 14),
            onPressed: () => _createNoteFolder(''),
            constraints: const BoxConstraints(
              minWidth: DesignTouchTarget.iconButtonSize,
              minHeight: DesignTouchTarget.iconButtonSize,
            ),
            tooltip: l.newFolder,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: () => _createNewNote(''),
            constraints: const BoxConstraints(
              minWidth: DesignTouchTarget.iconButtonSize,
              minHeight: DesignTouchTarget.iconButtonSize,
            ),
            tooltip: l.newNote,
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(ThemeData theme, dynamic note, AppLocalizations l) {
    final normalizedPath = (note.filePath as String).replaceAll('\\', '/');
    final parts = normalizedPath.split('/');
    if (parts.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.sm,
        vertical: DesignSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _expandedNoteFolders.add('');
                });
              },
              borderRadius: BorderRadius.circular(DesignRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignSpacing.xs,
                  vertical: 2,
                ),
                child: Icon(
                  Icons.folder_open,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            for (var i = 0; i < parts.length - 1; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignSpacing.xs,
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 10,
                  color: theme.hintColor,
                ),
              ),
              InkWell(
                onTap: () {
                  final folderPath = parts.sublist(0, i + 1).join('/');
                  setState(() {
                    _expandedNoteFolders.add(folderPath);
                  });
                },
                borderRadius: BorderRadius.circular(DesignRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignSpacing.xs,
                    vertical: 2,
                  ),
                  child: Text(
                    parts[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.xs),
              child: Icon(
                Icons.chevron_right,
                size: 10,
                color: theme.hintColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.xs),
              child: Text(
                note.title ?? parts.last,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

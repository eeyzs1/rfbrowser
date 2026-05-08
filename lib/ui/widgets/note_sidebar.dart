import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/settings_service.dart';
import '../../data/models/note.dart';
import '../../data/models/browser_tab.dart';
import '../../data/stores/vault_store.dart';
import 'create_note_dialog.dart';

enum _SidebarTab { notes, bookmarks }

class NoteSidebar extends ConsumerStatefulWidget {
  final VoidCallback? onNoteOpened;
  final ValueChanged<String>? onNotePreview;
  final ValueChanged<String>? onBookmarkOpened;
  const NoteSidebar({super.key, this.onNoteOpened, this.onNotePreview, this.onBookmarkOpened});

  @override
  ConsumerState<NoteSidebar> createState() => _NoteSidebarState();
}

class _NoteSidebarState extends ConsumerState<NoteSidebar> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _SidebarTab _activeTab = _SidebarTab.notes;
  final _expandedNoteFolders = <String>{};
  final _expandedBookmarkFolders = <String>{};
  String? _hoveredNoteId;
  String? _hoveredBookmarkId;
  String? _hoveredNoteFolder;
  String? _hoveredBookmarkFolder;
  String? _draggingNoteId;
  String? _draggingBookmarkId;
  List<String> _diskFolders = [];
  double _baseFontSize = 11.0;

  @override
  void initState() {
    super.initState();
    _expandedNoteFolders.add('');
    _expandedBookmarkFolders.add('bookmarks-bar');
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanDiskFolders());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanDiskFolders() async {
    final vaultState = ref.read(vaultProvider);
    if (vaultState.currentVault == null) return;
    final vaultPath = vaultState.currentVault!.path;
    final folders = <String>[];
    try {
      await _collectFolders(vaultPath, '', folders);
    } catch (_) {}
    if (mounted) {
      setState(() => _diskFolders = folders);
    }
  }

  Future<void> _collectFolders(String basePath, String relativePath, List<String> result) async {
    final dir = Directory(relativePath.isEmpty ? basePath : '$basePath/$relativePath');
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.') || name == 'attachments') continue;
        final path = relativePath.isEmpty ? name : '$relativePath/$name';
        result.add(path);
        await _collectFolders(basePath, path, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    _baseFontSize = settings.editorFontSize * 0.75;

    if (vaultState.currentVault == null) {
      return _buildNoVaultPrompt(theme);
    }

    final notes = _filterNotes(knowledgeState.notes, knowledgeState);

    return Column(
      children: [
        _buildTabBar(theme),
        if (_activeTab == _SidebarTab.notes)
          _buildNotesToolbar(theme)
        else
          _buildBookmarksToolbar(theme),
        Expanded(
          child: _activeTab == _SidebarTab.notes
              ? _buildNotesTree(theme, notes, knowledgeState)
              : _buildBookmarksTree(theme),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(child: _tabBtn(theme, _SidebarTab.notes, Icons.description_outlined, Icons.description, '笔记', ref.watch(knowledgeProvider).notes.length)),
          Expanded(child: _tabBtn(theme, _SidebarTab.bookmarks, Icons.bookmark_border, Icons.bookmark, '收藏', ref.watch(browserProvider).bookmarks.length)),
        ],
      ),
    );
  }

  Widget _tabBtn(ThemeData theme, _SidebarTab tab, IconData icon, IconData activeIcon, String label, int count) {
    final isActive = _activeTab == tab;
    final primary = theme.colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? primary : Colors.transparent, width: 2))),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isActive ? activeIcon : icon, size: 14, color: isActive ? primary : theme.hintColor),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: _baseFontSize, color: isActive ? primary : theme.hintColor, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: isActive ? primary.withValues(alpha: 0.1) : theme.dividerColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                child: Text('$count', style: TextStyle(fontSize: _baseFontSize - 2, color: isActive ? primary : theme.hintColor)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildNotesToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              hintText: '搜索笔记...', hintStyle: theme.textTheme.bodySmall,
              prefixIcon: const Icon(Icons.search, size: 14), isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                icon: const Icon(Icons.close, size: 12),
                onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ) : null,
            ),
            onChanged: (q) => setState(() => _searchQuery = q),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(icon: const Icon(Icons.create_new_folder_outlined, size: 14), onPressed: () => _createNoteFolder(''), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28), tooltip: '新建文件夹'),
        IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => _createNewNote(''), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28), tooltip: '新建笔记'),
      ]),
    );
  }

  Widget _buildBookmarksToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        Icon(Icons.bookmark, size: 14, color: theme.hintColor),
        const SizedBox(width: 6),
        Text('${ref.watch(browserProvider).bookmarks.length} 个收藏', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: _baseFontSize)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.create_new_folder_outlined, size: 14), onPressed: () => _createBookmarkFolder('bookmarks-bar'), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24), tooltip: '新建收藏夹'),
      ]),
    );
  }

  _TrieNode _buildNoteTrie(List<Note> notes) {
    final root = _TrieNode('', 0);
    for (final note in notes) {
      final normalizedPath = note.filePath.replaceAll('\\', '/');
      final parts = normalizedPath.split('/');
      _TrieNode current = root;
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final isFile = (i == parts.length - 1) && part.endsWith('.md');
        if (isFile) {
          current.notes.add(note);
        } else {
          final pathSoFar = parts.sublist(0, i + 1).join('/');
          var child = current.children.where((c) => c.path == pathSoFar).firstOrNull;
          if (child == null) {
            child = _TrieNode(pathSoFar, current.depth + 1);
            current.children.add(child);
          }
          current = child;
        }
      }
    }
    for (final folderPath in _diskFolders) {
      final parts = folderPath.split('/');
      _TrieNode current = root;
      for (var i = 0; i < parts.length; i++) {
        final pathSoFar = parts.sublist(0, i + 1).join('/');
        var child = current.children.where((c) => c.path == pathSoFar).firstOrNull;
        if (child == null) {
          child = _TrieNode(pathSoFar, current.depth + 1);
          current.children.add(child);
        }
        current = child;
      }
    }
    _sortTrie(root);
    return root;
  }

  void _sortTrie(_TrieNode node) {
    node.children.sort((a, b) => a.name.compareTo(b.name));
    for (final child in node.children) {
      _sortTrie(child);
    }
  }

  Widget _buildNotesTree(ThemeData theme, List<Note> notes, KnowledgeState knowledgeState) {
    if (notes.isEmpty && _diskFolders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.note_add, size: 32, color: theme.hintColor.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text('暂无笔记', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: () => _createNewNote(''), child: const Text('创建笔记')),
        ]),
      );
    }

    final trie = _buildNoteTrie(notes);
    return ListView(padding: EdgeInsets.zero, children: _buildTrieWidgets(trie, knowledgeState));
  }

  List<Widget> _buildTrieWidgets(_TrieNode node, KnowledgeState knowledgeState) {
    final items = <Widget>[];
    for (final child in node.children) {
      final isExpanded = _expandedNoteFolders.contains(child.path);
      final noteCount = child.totalNoteCount;
      items.add(_noteFolderRow(
        name: child.name, depth: child.depth, isExpanded: isExpanded,
        isRoot: child.depth == 0 && child.path.isEmpty, noteCount: noteCount,
        folderPath: child.path,
        onToggle: () => setState(() {
          if (isExpanded) { _expandedNoteFolders.remove(child.path); } else { _expandedNoteFolders.add(child.path); }
        }),
        onNewNote: () => _createNewNote(child.path),
        onNewFolder: () => _createNoteFolder(child.path),
        onRename: child.depth > 0 ? () => _renameNoteFolder(child.path) : null,
        onDelete: child.depth > 0 ? () => _confirmDeleteNoteFolder(child.path) : null,
      ));
      if (isExpanded) {
        items.addAll(_buildTrieWidgets(child, knowledgeState));
      }
    }
    for (final note in node.notes) {
      final isActive = knowledgeState.activeNote?.id == note.id;
      final isHovered = _hoveredNoteId == note.id;
      items.add(_noteRow(note, node.depth + (node.path.isEmpty ? 0 : 1), isActive, isHovered));
    }
    return items;
  }

  Widget _noteFolderRow({
    required String name, required int depth, required bool isExpanded,
    required bool isRoot, required int noteCount, required String folderPath,
    required VoidCallback onToggle, required VoidCallback onNewNote,
    required VoidCallback onNewFolder, VoidCallback? onRename, VoidCallback? onDelete,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => _draggingNoteId != null,
      onAcceptWithDetails: (details) {
        if (_draggingNoteId != null) {
          ref.read(knowledgeProvider.notifier).moveNote(_draggingNoteId!, folderPath).then((_) {
            _scanDiskFolders();
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;
        final theme = Theme.of(context);
        final isHovered = _hoveredNoteFolder == folderPath;
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredNoteFolder = folderPath),
          onExit: (_) => setState(() => _hoveredNoteFolder = null),
          child: GestureDetector(
            onSecondaryTapUp: (d) => _showFolderContextMenu(d.globalPosition, onNewNote, onNewFolder, onRename, onDelete),
            child: Container(
              padding: EdgeInsets.only(left: depth * 14.0 + 4.0),
              color: isDragOver ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : isHovered ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : null,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  child: Row(children: [
                    Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 14, color: theme.hintColor),
                    const SizedBox(width: 2),
                    Icon(isExpanded ? Icons.folder_open : Icons.folder, size: 15,
                      color: isRoot ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(
                      isRoot && name.isEmpty ? 'Vault' : name,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: _baseFontSize, fontWeight: FontWeight.w600, color: isRoot ? theme.colorScheme.primary : null),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    )),
                    if (isHovered && !isRoot) ...[
                      _ib(Icons.edit_outlined, onRename, '重命名'),
                      _ib(Icons.delete_outline, onDelete, '删除'),
                    ],
                    if (isHovered) ...[
                      _ib(Icons.add, onNewNote, '新建笔记'),
                      _ib(Icons.create_new_folder_outlined, onNewFolder, '新建子文件夹'),
                    ],
                    if (!isHovered && noteCount > 0)
                      Padding(padding: const EdgeInsets.only(left: 4), child: Text('$noteCount', style: TextStyle(fontSize: _baseFontSize - 2, color: theme.hintColor.withValues(alpha: 0.6)))),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _noteRow(Note note, int depth, bool isActive, bool isHovered) {
    return Draggable<String>(
      data: note.id,
      onDragStarted: () => setState(() => _draggingNoteId = note.id),
      onDragEnd: (_) => setState(() => _draggingNoteId = null),
      feedback: Material(
        elevation: 4, borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.description, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(note.title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: _baseFontSize)),
          ]),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredNoteId = note.id),
        onExit: (_) => setState(() => _hoveredNoteId = null),
        child: Container(
          padding: EdgeInsets.only(left: depth * 14.0 + 4.0),
          color: isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
          child: InkWell(
            onTap: () {
              ref.read(knowledgeProvider.notifier).openNote(note.id);
              if (widget.onNotePreview != null) { widget.onNotePreview!(note.id); } else { widget.onNoteOpened?.call(); }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(children: [
                Icon(Icons.description_outlined, size: 14, color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).hintColor),
                const SizedBox(width: 5),
                Expanded(child: Text(note.title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: _baseFontSize, color: isActive ? Theme.of(context).colorScheme.primary : null, fontWeight: isActive ? FontWeight.w600 : null),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (isHovered) ...[
                  _ib(Icons.drive_file_move_outline, () => _showMoveNoteDialog(note), '移动'),
                  _ib(Icons.close, () => _confirmDeleteNote(note.title, note.id), '删除'),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ib(IconData icon, VoidCallback? onPressed, String tooltip) {
    return IconButton(
      icon: Icon(icon, size: 12, color: Theme.of(context).hintColor.withValues(alpha: 0.7)),
      onPressed: onPressed, padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20), tooltip: tooltip,
    );
  }

  void _showFolderContextMenu(Offset pos, VoidCallback onNewNote, VoidCallback onNewFolder, VoidCallback? onRename, VoidCallback? onDelete) {
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(value: 'new_note', child: Row(children: [Icon(Icons.add, size: 14, color: Theme.of(context).hintColor), const SizedBox(width: 8), const Text('新建笔记')])),
      PopupMenuItem(value: 'new_folder', child: Row(children: [Icon(Icons.create_new_folder_outlined, size: 14, color: Theme.of(context).hintColor), const SizedBox(width: 8), const Text('新建子文件夹')])),
    ];
    if (onRename != null) items.add(PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, size: 14, color: Theme.of(context).hintColor), const SizedBox(width: 8), const Text('重命名')])));
    if (onDelete != null) {
      items.add(const PopupMenuDivider());
      items.add(PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 14, color: Theme.of(context).colorScheme.error), const SizedBox(width: 8), Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error))])));
    }
    showMenu(context: context, position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1), items: items).then((v) {
      switch (v) {
        case 'new_note': onNewNote();
        case 'new_folder': onNewFolder();
        case 'rename': onRename?.call();
        case 'delete': onDelete?.call();
      }
    });
  }

  Widget _buildBookmarksTree(ThemeData theme) {
    final browserState = ref.watch(browserProvider);
    final bookmarks = browserState.bookmarks;
    final folders = browserState.bookmarkFolders;

    if (bookmarks.isEmpty && folders.length <= 1) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bookmark_border, size: 32, color: theme.hintColor.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text('暂无收藏', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 4),
          Text('浏览网页时点击 ⭐ 收藏', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: _baseFontSize)),
        ]),
      );
    }

    final items = <Widget>[];
    _buildBookmarkFolderWidgets(folders, bookmarks, 'bookmarks-bar', 0, items);
    final unfiled = bookmarks.where((b) => b.folderId.isEmpty).toList();
    if (unfiled.isNotEmpty) {
      items.add(Padding(padding: const EdgeInsets.only(left: 8, top: 6, bottom: 2), child: Text('未分类', style: theme.textTheme.bodySmall?.copyWith(fontSize: _baseFontSize - 1, fontWeight: FontWeight.w600, color: theme.hintColor))));
      for (final bm in unfiled) {
        items.add(_bookmarkRow(bm, 1));
      }
    }
    return ListView(children: items);
  }

  void _buildBookmarkFolderWidgets(List<BookmarkFolder> allFolders, List<Bookmark> allBookmarks, String parentId, int depth, List<Widget> items) {
    final childFolders = allFolders.where((f) => f.parentId == parentId).toList();
    for (final folder in childFolders) {
      final folderBookmarks = allBookmarks.where((b) => b.folderId == folder.id).toList();
      final isExpanded = _expandedBookmarkFolders.contains(folder.id);
      final isHovered = _hoveredBookmarkFolder == folder.id;
      final totalBookmarks = _countBookmarksInFolder(allFolders, allBookmarks, folder.id);

      items.add(DragTarget<String>(
        onWillAcceptWithDetails: (details) => _draggingBookmarkId != null,
        onAcceptWithDetails: (details) {
          if (_draggingBookmarkId != null) {
            ref.read(browserProvider.notifier).moveBookmarkToFolder(_draggingBookmarkId!, folder.id);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isDragOver = candidateData.isNotEmpty;
          final theme = Theme.of(context);
          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredBookmarkFolder = folder.id),
            onExit: (_) => setState(() => _hoveredBookmarkFolder = null),
            child: Container(
              padding: EdgeInsets.only(left: depth * 14.0 + 4.0),
              color: isDragOver ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : isHovered ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : null,
              child: InkWell(
                onTap: () {
                  ref.read(browserProvider.notifier).toggleBookmarkFolder(folder.id);
                  setState(() {
                    if (isExpanded) { _expandedBookmarkFolders.remove(folder.id); } else { _expandedBookmarkFolders.add(folder.id); }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(children: [
                    Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 14, color: Theme.of(context).hintColor),
                    const SizedBox(width: 2),
                    Icon(isExpanded ? Icons.folder_open : Icons.folder, size: 15, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 5),
                    Expanded(child: Text(folder.name, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: _baseFontSize, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (isHovered && folder.id != 'bookmarks-bar') ...[
                      _ib(Icons.create_new_folder_outlined, () => _createBookmarkFolder(folder.id), '新建子收藏夹'),
                      _ib(Icons.edit_outlined, () => _renameBookmarkFolder(folder), '重命名'),
                      _ib(Icons.delete_outline, () => _confirmDeleteBookmarkFolder(folder.name, folder.id), '删除'),
                    ],
                    if (isHovered && folder.id == 'bookmarks-bar')
                      _ib(Icons.create_new_folder_outlined, () => _createBookmarkFolder(folder.id), '新建子收藏夹'),
                    if (!isHovered && totalBookmarks > 0)
                      Padding(padding: const EdgeInsets.only(left: 4), child: Text('$totalBookmarks', style: TextStyle(fontSize: _baseFontSize - 2, color: Theme.of(context).hintColor.withValues(alpha: 0.6)))),
                  ]),
                ),
              ),
            ),
          );
        },
      ));

      if (isExpanded) {
        _buildBookmarkFolderWidgets(allFolders, allBookmarks, folder.id, depth + 1, items);
        for (final bm in folderBookmarks) {
          items.add(_bookmarkRow(bm, depth + 1));
        }
      }
    }
  }

  int _countBookmarksInFolder(List<BookmarkFolder> allFolders, List<Bookmark> allBookmarks, String folderId, {Set<String>? visited}) {
    visited ??= {};
    if (visited.contains(folderId)) return 0;
    visited.add(folderId);
    var count = allBookmarks.where((b) => b.folderId == folderId).length;
    for (final f in allFolders.where((f) => f.parentId == folderId && f.id != folderId)) {
      count += _countBookmarksInFolder(allFolders, allBookmarks, f.id, visited: visited);
    }
    return count;
  }

  Widget _bookmarkRow(Bookmark bookmark, int depth) {
    final isHovered = _hoveredBookmarkId == bookmark.id;
    return Draggable<String>(
      data: bookmark.id,
      onDragStarted: () => setState(() => _draggingBookmarkId = bookmark.id),
      onDragEnd: (_) => setState(() => _draggingBookmarkId = null),
      feedback: Material(
        elevation: 4, borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bookmark, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(bookmark.title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: _baseFontSize)),
          ]),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredBookmarkId = bookmark.id),
        onExit: (_) => setState(() => _hoveredBookmarkId = null),
        child: InkWell(
          onTap: () => widget.onBookmarkOpened?.call(bookmark.url),
          child: Container(
            padding: EdgeInsets.only(left: depth * 14.0 + 18.0, right: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(children: [
                _favicon(bookmark), const SizedBox(width: 5),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bookmark.title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: _baseFontSize), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (_domain(bookmark).isNotEmpty) Text(_domain(bookmark), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: _baseFontSize - 2, color: Theme.of(context).hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                if (isHovered) ...[
                  _ib(Icons.drive_file_move_outline, () => _showMoveBookmarkDialog(bookmark), '移动'),
                  _ib(Icons.close, () => ref.read(browserProvider.notifier).removeBookmark(bookmark.id), '移除'),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _favicon(Bookmark bookmark) {
    return Container(
      width: 16, height: 16,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
      child: Center(child: Text(bookmark.title.isNotEmpty ? bookmark.title[0].toUpperCase() : '?', style: TextStyle(fontSize: _baseFontSize - 3, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary))),
    );
  }

  String _domain(Bookmark bookmark) {
    final uri = Uri.tryParse(bookmark.url);
    return uri?.host.replaceAll('www.', '') ?? '';
  }

  void _createNoteFolder(String parentPath) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(parentPath.isEmpty ? '新建文件夹' : '在 $parentPath 中新建文件夹'),
          content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '文件夹名称', isDense: true)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('创建')),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      final vaultState = ref.read(vaultProvider);
      if (vaultState.currentVault != null) {
        final fullPath = parentPath.isEmpty ? name : '$parentPath/$name';
        final dir = Directory('${vaultState.currentVault!.path}/$fullPath');
        if (!await dir.exists()) await dir.create(recursive: true);
        setState(() {
          _expandedNoteFolders.add(parentPath);
          _expandedNoteFolders.add(fullPath);
        });
        await _scanDiskFolders();
      }
    }
  }

  void _createNewNote(String folderPath) async {
    final title = await showCreateNoteDialog(context);
    if (title != null && title.isNotEmpty) {
      if (folderPath.isNotEmpty) {
        final vaultState = ref.read(vaultProvider);
        if (vaultState.currentVault != null) {
          final fileName = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(RegExp(r'\s+'), '-');
          final relativePath = '$folderPath/$fileName.md';
          final note = Note(title: title, filePath: relativePath, content: '# $title\n\n');
          final file = File('${vaultState.currentVault!.path}/$relativePath');
          final dir = Directory('${vaultState.currentVault!.path}/$folderPath');
          if (!await dir.exists()) await dir.create(recursive: true);
          await file.writeAsString(note.toMarkdown());
          await ref.read(knowledgeProvider.notifier).loadAllNotes();
          ref.read(knowledgeProvider.notifier).openNote(note.id);
          if (widget.onNotePreview != null) { widget.onNotePreview!(note.id); } else { widget.onNoteOpened?.call(); }
        }
      } else {
        await ref.read(knowledgeProvider.notifier).createNote(title: title);
      }
    }
  }

  void _renameNoteFolder(String folderPath) async {
    final parts = folderPath.split('/');
    final oldName = parts.last;
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名文件夹'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(isDense: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('确定')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final vaultState = ref.read(vaultProvider);
      if (vaultState.currentVault != null) {
        final parentPath = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : '';
        final newFolderPath = parentPath.isEmpty ? newName : '$parentPath/$newName';
        final oldDir = Directory('${vaultState.currentVault!.path}/$folderPath');
        final newDir = Directory('${vaultState.currentVault!.path}/$newFolderPath');
        if (await oldDir.exists() && !await newDir.exists()) await oldDir.rename(newDir.path);
        if (_expandedNoteFolders.contains(folderPath)) { _expandedNoteFolders.remove(folderPath); _expandedNoteFolders.add(newFolderPath); }
        await ref.read(knowledgeProvider.notifier).loadAllNotes();
        await _scanDiskFolders();
      }
    }
  }

  void _confirmDeleteNoteFolder(String folderPath) async {
    final knowledgeState = ref.read(knowledgeProvider);
    final count = knowledgeState.notes.where((n) => n.filePath.startsWith('$folderPath/')).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text('删除"$folderPath"及其中的 $count 篇笔记？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      final vaultState = ref.read(vaultProvider);
      if (vaultState.currentVault != null) {
        final dir = Directory('${vaultState.currentVault!.path}/$folderPath');
        if (await dir.exists()) await dir.delete(recursive: true);
        _expandedNoteFolders.remove(folderPath);
        await ref.read(knowledgeProvider.notifier).loadAllNotes();
        await _scanDiskFolders();
      }
    }
  }

  void _createBookmarkFolder(String parentFolderId) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('新建收藏夹'),
          content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '收藏夹名称', isDense: true)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('创建')),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      ref.read(browserProvider.notifier).createBookmarkFolder(name, parentId: parentFolderId);
    }
  }

  void _renameBookmarkFolder(BookmarkFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名收藏夹'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(isDense: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('确定')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != folder.name) {
      ref.read(browserProvider.notifier).renameBookmarkFolder(folder.id, newName);
    }
  }

  void _confirmDeleteBookmarkFolder(String name, String folderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: Text('删除"$name"？其中的收藏将移至"未分类"。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) ref.read(browserProvider.notifier).deleteBookmarkFolder(folderId);
  }

  void _showMoveBookmarkDialog(Bookmark bookmark) async {
    final folders = ref.read(browserProvider).bookmarkFolders;
    if (folders.isEmpty) return;
    final folderId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移动到'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ''), child: const Text('未分类')),
          ...folders.map((f) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, f.id), child: Text(f.name))),
        ],
      ),
    );
    if (folderId != null) ref.read(browserProvider.notifier).moveBookmarkToFolder(bookmark.id, folderId);
  }

  void _showMoveNoteDialog(Note note) async {
    final knowledgeState = ref.read(knowledgeProvider);
    final allFolders = _getAllFolderPaths(knowledgeState.notes);
    final currentFolder = note.filePath.split('/').length > 1
        ? note.filePath.split('/').sublist(0, note.filePath.split('/').length - 1).join('/') : '';

    final targetFolder = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移动到文件夹'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ''), child: const Text('根目录')),
          ...allFolders.where((f) => f != currentFolder).map((f) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, f), child: Text(f))),
        ],
      ),
    );
    if (targetFolder != null && targetFolder != currentFolder) {
      await ref.read(knowledgeProvider.notifier).moveNote(note.id, targetFolder);
      await _scanDiskFolders();
    }
  }

  List<String> _getAllFolderPaths(List<Note> notes) {
    final folders = <String>{};
    for (final note in notes) {
      final parts = note.filePath.split('/');
      for (var i = 1; i < parts.length; i++) {
        folders.add(parts.sublist(0, i).join('/'));
      }
    }
    for (final f in _diskFolders) {
      folders.add(f);
    }
    return folders.toList()..sort();
  }

  List<Note> _filterNotes(List<Note> notes, KnowledgeState knowledgeState) {
    var filtered = notes;
    final filter = knowledgeState.noteFilter;
    if (filter == NoteFilter.hasLinks) {
      final links = knowledgeState.links;
      filtered = notes.where((n) => links.any((l) => l.sourceId == n.id || l.targetId == n.id)).toList();
    } else if (filter == NoteFilter.hasTags) {
      filtered = notes.where((n) => n.tags.isNotEmpty).toList();
    } else if (filter == NoteFilter.hasAttachments) {
      filtered = notes.where((n) => n.frontMatter.containsKey('attachments')).toList();
    }
    if (_searchQuery.isEmpty) return filtered;
    final q = _searchQuery.toLowerCase();
    return filtered.where((n) => n.title.toLowerCase().contains(q) || n.tags.any((t) => t.toLowerCase().contains(q)) || n.content.toLowerCase().contains(q)).toList();
  }

  Widget _buildNoVaultPrompt(ThemeData theme) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
        child: Row(children: [Icon(Icons.folder_open, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text('笔记', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)))])),
      Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder_off, size: 40, color: theme.hintColor), const SizedBox(height: 12),
        Text('未连接知识库', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 4),
        Text('打开知识库管理笔记', style: theme.textTheme.bodySmall, textAlign: TextAlign.center), const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => _openVault(), icon: const Icon(Icons.folder_open, size: 16), label: const Text('打开知识库')), const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _createVault(), icon: const Icon(Icons.create_new_folder, size: 16), label: const Text('创建知识库')),
      ])))),
    ]);
  }

  Future<void> _openVault() async {
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择知识库位置');
    if (result != null) {
      await ref.read(vaultProvider.notifier).openVault(result);
      ref.read(knowledgeProvider.notifier).loadAllNotes();
      ref.read(browserProvider.notifier).loadBookmarks();
      await _scanDiskFolders();
    }
  }

  Future<void> _createVault() async {
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择知识库位置');
    if (result != null) {
      await ref.read(vaultProvider.notifier).createVault(result);
      ref.read(knowledgeProvider.notifier).loadAllNotes();
      ref.read(browserProvider.notifier).loadBookmarks();
      await _scanDiskFolders();
    }
  }

  void _confirmDeleteNote(String title, String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'), content: Text('确定要删除"$title"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) ref.read(knowledgeProvider.notifier).deleteNote(noteId);
  }
}

class _TrieNode {
  final String path;
  final int depth;
  final List<_TrieNode> children = [];
  final List<Note> notes = [];

  _TrieNode(this.path, this.depth);

  String get name => path.isEmpty ? '' : path.split('/').last;

  int get totalNoteCount {
    var count = notes.length;
    for (final child in children) {
      count += child.totalNoteCount;
    }
    return count;
  }
}

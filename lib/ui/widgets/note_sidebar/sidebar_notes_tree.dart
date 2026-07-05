part of '../note_sidebar.dart';

mixin _SidebarNotesTreeMixin on _NoteSidebarStateBase {
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
          var child = current.children[pathSoFar];
          if (child == null) {
            child = _TrieNode(pathSoFar, current.depth + 1);
            current.children[pathSoFar] = child;
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
        var child = current.children[pathSoFar];
        if (child == null) {
          child = _TrieNode(pathSoFar, current.depth + 1);
          current.children[pathSoFar] = child;
        }
        current = child;
      }
    }
    _sortTrie(root);
    _computeNoteCounts(root);
    return root;
  }

  void _sortTrie(_TrieNode node) {
    final sortedEntries = node.children.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
    final sorted = <String, _TrieNode>{
      for (final e in sortedEntries) e.key: e.value,
    };
    node.children
      ..clear()
      ..addAll(sorted);
    for (final child in node.children.values) {
      _sortTrie(child);
    }
  }

  int _computeNoteCounts(_TrieNode node) {
    var count = node.notes.length;
    for (final child in node.children.values) {
      count += _computeNoteCounts(child);
    }
    node.totalNoteCount = count;
    return count;
  }

  Widget _buildNotesTree(
    ThemeData theme,
    List<Note> notes,
    KnowledgeState knowledgeState,
    AppLocalizations l,
  ) {
    if (notes.isEmpty && _diskFolders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_add,
              size: 32,
              color: theme.hintColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              l.noNotes,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _createNewNote(''),
              child: Text(l.createNote),
            ),
          ],
        ),
      );
    }

    final trie = _resolvedTrie(notes, knowledgeState);
    final flatList = _buildFlatList(trie);
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: flatList.length,
      itemBuilder: (context, index) {
        final node = flatList[index];
        if (node.isFolder) {
          return _NoteFolderRow(
            name: node.name,
            depth: node.depth,
            isExpanded: node.isExpanded,
            isRoot: node.isRoot,
            noteCount: node.noteCount,
            folderPath: node.folderPath,
            hasChildren: node.hasChildren,
            l: l,
            baseFontSize: _baseFontSize,
            isDraggingNote: _draggingNoteId != null,
            onToggle: () => setState(() {
              if (node.isExpanded) {
                _expandedNoteFolders.remove(node.folderPath);
              } else {
                _expandedNoteFolders.add(node.folderPath);
              }
            }),
            onNewNote: () => _createNewNote(node.folderPath),
            onNewFolder: () => _createNoteFolder(node.folderPath),
            onRename: node.depth > 0
                ? () => _renameNoteFolder(node.folderPath)
                : null,
            onDelete: node.depth > 0
                ? () => _confirmDeleteNoteFolder(node.folderPath)
                : null,
            onAcceptNote: (noteId) {
              ref
                  .read(knowledgeProvider.notifier)
                  .moveNote(noteId, node.folderPath)
                  .then((_) => _scanDiskFolders());
            },
          );
        } else {
          final note = node.note!;
          return _NoteRow(
            note: note,
            depth: node.depth,
            isActive: knowledgeState.activeNote?.id == note.id,
            l: l,
            baseFontSize: _baseFontSize,
            onTap: () {
              ref.read(knowledgeProvider.notifier).openNote(note.id);
              if (widget.onNotePreview != null) {
                widget.onNotePreview!(note.id);
              } else {
                widget.onNoteOpened?.call();
              }
            },
            onMove: () => _showMoveNoteDialog(note),
            onDelete: () => _confirmDeleteNote(note.title, note.id),
            onDragStarted: () => setState(() => _draggingNoteId = note.id),
            onDragEnd: () => setState(() => _draggingNoteId = null),
          );
        }
      },
    );
  }

  /// Returns the cached trie when its inputs (filtered notes + disk
  /// folders) are unchanged, otherwise rebuilds and caches. The trie
  /// structure is independent of activeNoteId, so opening a note reuses
  /// the cached trie instead of rebuilding the whole folder/file tree.
  _TrieNode _resolvedTrie(List<Note> filteredNotes, KnowledgeState ks) {
    if (_cacheTrie != null && _cacheValid(ks)) {
      return _cacheTrie!;
    }
    final trie = _buildNoteTrie(filteredNotes);
    _cacheTrie = trie;
    return trie;
  }

  /// Flattens the trie into a visible-only list of [_FlatNode]s for
  /// [ListView.builder]. Only expanded folders' children are included,
  /// so collapsed subtrees contribute zero rows — keeping the item count
  /// proportional to what the user actually sees.
  List<_FlatNode> _buildFlatList(_TrieNode root) {
    final result = <_FlatNode>[];
    _flattenTrie(root, result);
    return result;
  }

  void _flattenTrie(_TrieNode node, List<_FlatNode> result) {
    for (final child in node.children.values) {
      final isExpanded = _expandedNoteFolders.contains(child.path);
      result.add(
        _FlatNode(
          key: 'folder:${child.path}',
          depth: child.depth,
          isFolder: true,
          name: child.name,
          isExpanded: isExpanded,
          isRoot: child.depth == 0 && child.path.isEmpty,
          noteCount: child.totalNoteCount,
          folderPath: child.path,
          hasChildren: child.children.isNotEmpty || child.notes.isNotEmpty,
        ),
      );
      if (isExpanded) {
        _flattenTrie(child, result);
      }
    }
    for (final note in node.notes) {
      result.add(
        _FlatNode(
          key: 'note:${note.id}',
          depth: node.depth + (node.path.isEmpty ? 0 : 1),
          isFolder: false,
          name: note.title,
          note: note,
        ),
      );
    }
  }
}

class _TrieNode {
  final String path;
  final int depth;

  /// Keyed by full child path for O(1) lookup (replaces the previous
  /// `List<_TrieNode>` + linear `.where().firstOrNull` scan that was
  /// O(n) per path segment — O(n²) for flat vaults).
  final Map<String, _TrieNode> children = {};
  final List<Note> notes = [];

  /// Precomputed during trie construction by [_SidebarNotesTreeMixin._computeNoteCounts]
  /// to avoid recursing the whole subtree on every folder-row build.
  int totalNoteCount = 0;

  _TrieNode(this.path, this.depth);

  String get name => path.isEmpty ? '' : path.split('/').last;
}

/// Flattened representation of a single visible tree row, used as the
/// item type for the [ListView.builder] in [_buildNotesTree].
class _FlatNode {
  final String key;
  final int depth;
  final bool isFolder;
  final String name;
  final bool isExpanded;
  final bool isRoot;
  final int noteCount;
  final String folderPath;
  final bool hasChildren;
  final Note? note;

  const _FlatNode({
    required this.key,
    required this.depth,
    required this.isFolder,
    required this.name,
    this.isExpanded = false,
    this.isRoot = false,
    this.noteCount = 0,
    this.folderPath = '',
    this.hasChildren = false,
    this.note,
  });
}

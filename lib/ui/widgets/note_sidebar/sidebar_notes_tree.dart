part of '../note_sidebar.dart';

mixin _SidebarNotesTreeMixin on _NoteSidebarStateBase,
    _SidebarNotesTreeWidgetsMixin {
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
          var child = current.children
              .where((c) => c.path == pathSoFar)
              .firstOrNull;
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
        var child = current.children
            .where((c) => c.path == pathSoFar)
            .firstOrNull;
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
    return ListView(
      padding: EdgeInsets.zero,
      children: _buildTrieWidgets(trie, knowledgeState, l),
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

  List<Widget> _buildTrieWidgets(
    _TrieNode node,
    KnowledgeState knowledgeState,
    AppLocalizations l,
  ) {
    final items = <Widget>[];
    for (final child in node.children) {
      final isExpanded = _expandedNoteFolders.contains(child.path);
      final noteCount = child.totalNoteCount;
      items.add(
        _noteFolderRow(
          name: child.name,
          depth: child.depth,
          isExpanded: isExpanded,
          isRoot: child.depth == 0 && child.path.isEmpty,
          noteCount: noteCount,
          folderPath: child.path,
          l: l,
          onToggle: () => setState(() {
            if (isExpanded) {
              _expandedNoteFolders.remove(child.path);
            } else {
              _expandedNoteFolders.add(child.path);
            }
          }),
          onNewNote: () => _createNewNote(child.path),
          onNewFolder: () => _createNoteFolder(child.path),
          onRename: child.depth > 0
              ? () => _renameNoteFolder(child.path)
              : null,
          onDelete: child.depth > 0
              ? () => _confirmDeleteNoteFolder(child.path)
              : null,
        ),
      );
      if (isExpanded) {
        items.addAll(_buildTrieWidgets(child, knowledgeState, l));
      }
    }
    for (final note in node.notes) {
      final isActive = knowledgeState.activeNote?.id == note.id;
      final isHovered = _hoveredNoteId == note.id;
      items.add(
        _noteRow(
          note,
          node.depth + (node.path.isEmpty ? 0 : 1),
          isActive,
          isHovered,
          l,
        ),
      );
    }
    return items;
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

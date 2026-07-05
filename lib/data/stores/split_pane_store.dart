import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/split_pane_node.dart';

/// State for the multi-pane split layout.
class SplitPaneState {
  /// Root of the split tree. Null when no pane is open (empty state).
  final SplitNode? root;

  /// The leaf currently receiving focus. New notes open in this leaf.
  /// May be null when the tree is empty or no leaf has been focused yet.
  final String? activeLeafId;

  const SplitPaneState({this.root, this.activeLeafId});

  SplitPaneState copyWith({SplitNode? root, String? activeLeafId}) {
    return SplitPaneState(
      root: root ?? this.root,
      activeLeafId: activeLeafId ?? this.activeLeafId,
    );
  }
}

class SplitPaneNotifier extends Notifier<SplitPaneState> {
  @override
  SplitPaneState build() => const SplitPaneState();

  /// Opens [noteId] in the active leaf as a NEW tab. If the note is
  /// already open in a tab within the active leaf, that tab is activated
  /// instead of creating a duplicate. If no tree exists, a new leaf is
  /// created as the root. Returns the leaf id that was updated so callers
  /// can synchronise other state (e.g. activeNoteId).
  String openNoteInActiveLeaf(
    String noteId, {
    NoteViewMode viewMode = NoteViewMode.edit,
  }) {
    final root = state.root;
    if (root == null) {
      final leafId = _newLeafId();
      final leaf = SplitNode.leaf(
        id: leafId,
        noteId: noteId,
        viewMode: viewMode,
      );
      state = SplitPaneState(root: leaf, activeLeafId: leafId);
      return leafId;
    }

    final targetLeafId = state.activeLeafId ?? _firstLeaf(root)?.id;
    if (targetLeafId == null) {
      final leafId = _newLeafId();
      final leaf = SplitNode.leaf(
        id: leafId,
        noteId: noteId,
        viewMode: viewMode,
      );
      state = SplitPaneState(root: leaf, activeLeafId: leafId);
      return leafId;
    }

    // Add a new tab to the target leaf (or activate an existing tab that
    // already shows this note — avoids duplicate tabs for the same note).
    final newRoot = _updateLeafInTree(root, targetLeafId, (leaf) {
      final existingIndex = leaf.tabs.indexWhere((t) => t.noteId == noteId);
      if (existingIndex != -1) {
        return leaf.copyLeafWith(activeTabIndex: existingIndex);
      }
      final newTab = SplitTab(
        id: '${leaf.id}_tab${leaf.tabs.length}',
        noteId: noteId,
        viewMode: viewMode,
      );
      final newTabs = List<SplitTab>.from(leaf.tabs)..add(newTab);
      return leaf.copyLeafWith(
        tabs: newTabs,
        activeTabIndex: newTabs.length - 1,
      );
    });
    state = state.copyWith(root: newRoot);
    return targetLeafId;
  }

  /// Marks [leafId] as the active (focused) leaf.
  void setActiveLeaf(String leafId) {
    final root = state.root;
    if (root == null) return;
    if (!_leafExists(root, leafId)) return;
    state = state.copyWith(activeLeafId: leafId);
  }

  /// Replaces the whole tree (used by the top-level SplitPane's onChanged
  /// callback). Resets [activeLeafId] when it no longer exists in the new
  /// tree, falling back to the first available leaf.
  void replaceRoot(SplitNode? newRoot) {
    if (newRoot == null) {
      state = const SplitPaneState();
      return;
    }
    var activeId = state.activeLeafId;
    if (activeId != null && !_leafExists(newRoot, activeId)) {
      activeId = _firstLeaf(newRoot)?.id;
    }
    state = SplitPaneState(root: newRoot, activeLeafId: activeId);
  }

  /// Closes the entire pane tree (top-level close).
  void closeRoot() {
    state = const SplitPaneState();
  }

  // --- Tree helpers -------------------------------------------------------

  int _leafCounter = 0;

  String _newLeafId() =>
      'leaf_${DateTime.now().millisecondsSinceEpoch}_${_leafCounter++}';

  SplitNode? _firstLeaf(SplitNode node) {
    if (node.isLeaf) return node;
    for (final child in node.children) {
      final found = _firstLeaf(child);
      if (found != null) return found;
    }
    return null;
  }

  bool _leafExists(SplitNode node, String leafId) {
    if (node.isLeaf) return node.id == leafId;
    return node.children.any((c) => _leafExists(c, leafId));
  }

  /// Returns a new tree where the leaf with [leafId] is replaced by the
  /// result of [transform]. Non-leaf nodes are rebuilt recursively.
  SplitNode _updateLeafInTree(
    SplitNode node,
    String leafId,
    SplitNode Function(SplitNode leaf) transform,
  ) {
    if (node.isLeaf) {
      return node.id == leafId ? transform(node) : node;
    }
    return SplitNode.split(
      id: node.id,
      direction: node.direction,
      flex: node.flex,
      children: node.children
          .map((c) => _updateLeafInTree(c, leafId, transform))
          .toList(),
    );
  }
}

final splitPaneProvider = NotifierProvider<SplitPaneNotifier, SplitPaneState>(
  SplitPaneNotifier.new,
);

/// Pure data models for the split-pane layout tree. Kept free of Flutter
/// widget imports so that state stores may depend on them without pulling
/// in the material layer.
library;

/// Display mode for a single note pane.
/// - [edit]: editable TextField (monospace) with autosave.
/// - [source]: read-only raw markdown source (monospace).
/// - [rendered]: read-only rendered markdown (friendly reading view).
enum NoteViewMode { edit, source, rendered }

enum SplitDirection { horizontal, vertical }

/// A single tab inside a leaf pane. Each tab shows one note in one view
/// mode. A leaf pane may hold multiple tabs (like a browser tab bar),
/// with one tab active at a time.
class SplitTab {
  final String id;
  final String noteId;
  final NoteViewMode viewMode;

  const SplitTab({
    required this.id,
    required this.noteId,
    this.viewMode = NoteViewMode.edit,
  });

  SplitTab copyWith({String? noteId, NoteViewMode? viewMode}) => SplitTab(
    id: id,
    noteId: noteId ?? this.noteId,
    viewMode: viewMode ?? this.viewMode,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'noteId': noteId,
    'viewMode': viewMode.index,
  };

  factory SplitTab.fromJson(Map<String, dynamic> json) => SplitTab(
    id: json['id'] as String,
    noteId: json['noteId'] as String,
    viewMode: json['viewMode'] != null
        ? NoteViewMode.values[json['viewMode'] as int]
        : NoteViewMode.edit,
  );
}

class SplitNode {
  final String id;
  final SplitDirection? direction;
  final List<SplitNode> children;
  final double? flex;

  /// For leaf nodes: the tabs held in this pane. Non-empty for leaves,
  /// empty for split nodes.
  final List<SplitTab> tabs;

  /// Index of the currently active tab in [tabs].
  final int activeTabIndex;

  const SplitNode._leaf({
    required this.id,
    required this.tabs,
    this.activeTabIndex = 0,
    this.flex,
  }) : direction = null,
       children = const [];

  /// Leaf constructor. Accepts either [tabs] (preferred) or a legacy
  /// [noteId]/[viewMode] pair. When [noteId] is supplied without [tabs],
  /// a single tab is synthesized so callers that predate multi-tab keep
  /// working.
  factory SplitNode.leaf({
    required String id,
    String? noteId,
    NoteViewMode? viewMode,
    List<SplitTab>? tabs,
    int activeTabIndex = 0,
    double? flex,
  }) {
    final resolvedTabs =
        tabs ??
        [
          if (noteId != null)
            SplitTab(
              id: '${id}_tab0',
              noteId: noteId,
              viewMode: viewMode ?? NoteViewMode.edit,
            ),
        ];
    return SplitNode._leaf(
      id: id,
      tabs: resolvedTabs,
      activeTabIndex: activeTabIndex,
      flex: flex,
    );
  }

  const SplitNode.split({
    required this.id,
    required this.direction,
    required this.children,
    this.flex,
  }) : tabs = const [],
       activeTabIndex = 0;

  bool get isLeaf => direction == null;

  /// The active tab of this leaf, or null for split nodes / empty leaves.
  SplitTab? get activeTab {
    if (!isLeaf || tabs.isEmpty) return null;
    return tabs[activeTabIndex.clamp(0, tabs.length - 1)];
  }

  /// Convenience: the noteId of the active tab. Null for split nodes.
  String? get noteId => activeTab?.noteId;

  /// Convenience: the viewMode of the active tab. Null for split nodes.
  NoteViewMode? get viewMode => activeTab?.viewMode;

  Map<String, dynamic> toJson() {
    if (isLeaf) {
      return {
        'id': id,
        'tabs': tabs.map((t) => t.toJson()).toList(),
        'activeTabIndex': activeTabIndex,
        if (flex != null) 'flex': flex,
      };
    }
    return {
      'id': id,
      'direction': direction!.index,
      if (flex != null) 'flex': flex,
      if (children.isNotEmpty)
        'children': children.map((c) => c.toJson()).toList(),
    };
  }

  factory SplitNode.fromJson(Map<String, dynamic> json) {
    final directionIndex = json['direction'];
    if (directionIndex != null) {
      return SplitNode.split(
        id: json['id'] as String,
        direction: SplitDirection.values[directionIndex as int],
        flex: (json['flex'] as num?)?.toDouble(),
        children: (json['children'] as List)
            .map((c) => SplitNode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
    }
    // Leaf: support both new (tabs) and legacy (noteId) formats.
    if (json['tabs'] != null) {
      final tabsList = (json['tabs'] as List)
          .map((t) => SplitTab.fromJson(t as Map<String, dynamic>))
          .toList();
      return SplitNode._leaf(
        id: json['id'] as String,
        tabs: tabsList,
        activeTabIndex: (json['activeTabIndex'] as int?) ?? 0,
        flex: (json['flex'] as num?)?.toDouble(),
      );
    }
    // Legacy single-note leaf.
    return SplitNode._leaf(
      id: json['id'] as String,
      tabs: [
        SplitTab(
          id: '${json['id']}_tab0',
          noteId: json['noteId'] as String,
          viewMode: json['viewMode'] != null
              ? NoteViewMode.values[json['viewMode'] as int]
              : NoteViewMode.edit,
        ),
      ],
      activeTabIndex: 0,
      flex: (json['flex'] as num?)?.toDouble(),
    );
  }

  /// Returns a copy of this leaf. [tabs]/[activeTabIndex] replace the
  /// tab list outright; [noteId]/[viewMode] update the active tab in
  /// place (kept for compatibility with existing call sites).
  SplitNode copyLeafWith({
    List<SplitTab>? tabs,
    int? activeTabIndex,
    String? noteId,
    NoteViewMode? viewMode,
    double? flex,
  }) {
    if (!isLeaf) return this;
    var newTabs = tabs ?? this.tabs;
    var newActive = activeTabIndex ?? this.activeTabIndex;
    if (noteId != null || viewMode != null) {
      final idx = newActive.clamp(0, newTabs.length - 1);
      newTabs = List<SplitTab>.from(newTabs);
      newTabs[idx] = newTabs[idx].copyWith(noteId: noteId, viewMode: viewMode);
    }
    return SplitNode._leaf(
      id: id,
      tabs: newTabs,
      activeTabIndex: newActive,
      flex: flex ?? this.flex,
    );
  }
}

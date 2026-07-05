part of 'split_pane.dart';

/// Tab bar, context menu, and view-mode controls for the split pane.
/// Each leaf pane hosts a row of tabs (one per open note) plus a compact
/// view-mode switcher on the right that retargets the active tab. Split
/// actions live in the tab bar's secondary-tap context menu.
mixin _SplitPaneTabMixin on State<SplitPane> {
  final ScrollController _tabScrollController = ScrollController();

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  /// Converts mouse-wheel input into horizontal tab-strip scrolling,
  /// mirroring VSCode's tab bar. Vertical wheel (dy) and horizontal
  /// trackpad (dx) are both handled.
  void _onTabPointerSignal(PointerSignalEvent signal) {
    if (signal is PointerScrollEvent && _tabScrollController.hasClients) {
      final dy = signal.scrollDelta.dy;
      final dx = signal.scrollDelta.dx;
      final delta = dy.abs() >= dx.abs() ? dy : -dx;
      if (delta == 0) return;
      final maxExtent = _tabScrollController.position.maxScrollExtent;
      final newOffset = (_tabScrollController.offset + delta).clamp(
        0.0,
        maxExtent,
      );
      _tabScrollController.jumpTo(newOffset);
    }
  }

  /// Left-drag horizontal scrolling — content follows the cursor, like
  /// dragging a tab strip in a browser. The gesture arena ensures a
  /// small click still activates the tab (tap wins) while a drag beyond
  /// kTouchSlop scrolls the strip (drag wins).
  void _onTabDragUpdate(DragUpdateDetails details) {
    if (!_tabScrollController.hasClients) return;
    final maxExtent = _tabScrollController.position.maxScrollExtent;
    final newOffset = (_tabScrollController.offset - details.delta.dx).clamp(
      0.0,
      maxExtent,
    );
    _tabScrollController.jumpTo(newOffset);
  }

  Widget buildTabBar() {
    final theme = Theme.of(context);
    final node = widget.node;
    if (!node.isLeaf) return const SizedBox.shrink();
    final tabs = node.tabs;
    final activeIndex = tabs.isEmpty
        ? 0
        : node.activeTabIndex.clamp(0, tabs.length - 1);
    final activeViewMode = node.activeTab?.viewMode ?? NoteViewMode.edit;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onSecondaryTapUp: (details) =>
                  showTabContextMenu(details.globalPosition),
              onHorizontalDragUpdate: _onTabDragUpdate,
              child: tabs.isEmpty
                  ? const SizedBox.shrink()
                  : Listener(
                      onPointerSignal: _onTabPointerSignal,
                      child: ListView.builder(
                        controller: _tabScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 3,
                        ),
                        itemCount: tabs.length,
                        itemBuilder: (context, index) {
                          final tab = tabs[index];
                          final isActive = index == activeIndex;
                          final title =
                              widget.noteTitleOf?.call(tab.noteId) ?? 'Note';
                          return _buildTabChip(
                            index,
                            tab,
                            title,
                            isActive,
                            theme,
                          );
                        },
                      ),
                    ),
            ),
          ),
          _buildViewModeSwitcher(activeViewMode, theme),
          if (widget.onClose != null) ...[
            _IconAction(
              icon: Icons.close,
              size: 14,
              color: theme.hintColor,
              tooltip: 'Close Pane',
              onPressed: widget.onClose!,
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildTabChip(
    int index,
    SplitTab tab,
    String title,
    bool isActive,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => activateTab(index),
      onSecondaryTapUp: (details) => showTabContextMenu(details.globalPosition),
      onTertiaryTapDown: (_) => closeTab(index),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isActive
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  )
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                viewModeIcon(tab.viewMode),
                size: 12,
                color: isActive ? theme.colorScheme.primary : theme.hintColor,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.hintColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              _IconAction(
                icon: Icons.close,
                size: 11,
                color: theme.hintColor,
                tooltip: 'Close Tab',
                onPressed: () => closeTab(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact 3-button switcher (edit / source / rendered) on the right
  /// edge of the tab bar. The active tab's current view mode is
  /// highlighted; tapping a button retargets the active tab.
  Widget _buildViewModeSwitcher(NoteViewMode active, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: NoteViewMode.values.map((vm) {
          final isActive = vm == active;
          return Tooltip(
            message: viewModeLabel(vm),
            waitDuration: const Duration(milliseconds: 500),
            child: InkWell(
              onTap: () => setViewMode(vm),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(
                  viewModeIcon(vm),
                  size: 13,
                  color: isActive ? theme.colorScheme.primary : theme.hintColor,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Tab operations -----------------------------------------------------

  void activateTab(int index) {
    final node = widget.node;
    if (!node.isLeaf) return;
    if (index < 0 || index >= node.tabs.length) return;
    if (index == node.activeTabIndex) return;
    widget.onChanged(node.copyLeafWith(activeTabIndex: index));
  }

  void closeTab(int index) {
    final node = widget.node;
    if (!node.isLeaf) return;
    final tabs = node.tabs;
    if (index < 0 || index >= tabs.length) return;

    // Closing the last tab removes the whole leaf; the parent SplitPane
    // handles collapsing the surrounding split (or clears the tree when
    // this was the root).
    if (tabs.length == 1) {
      widget.onClose?.call();
      return;
    }

    final newTabs = List<SplitTab>.from(tabs)..removeAt(index);
    var newActive = node.activeTabIndex;
    if (index == newActive) {
      newActive = (index - 1).clamp(0, newTabs.length - 1);
    } else if (index < newActive) {
      newActive -= 1;
    }
    widget.onChanged(
      node.copyLeafWith(tabs: newTabs, activeTabIndex: newActive),
    );
  }

  void setViewMode(NoteViewMode vm) {
    final node = widget.node;
    if (!node.isLeaf) return;
    if (node.activeTab?.viewMode == vm) return;
    widget.onChanged(node.copyLeafWith(viewMode: vm));
  }

  // --- Context menu (split actions + close pane) --------------------------

  void showTabContextMenu(Offset position) {
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlayBox.size,
      ),
      items: [
        const PopupMenuItem(value: 'split_right', child: Text('Split Right')),
        const PopupMenuItem(value: 'split_left', child: Text('Split Left')),
        const PopupMenuItem(value: 'split_up', child: Text('Split Up')),
        const PopupMenuItem(value: 'split_down', child: Text('Split Down')),
        const PopupMenuDivider(),
        if (widget.onClose != null)
          const PopupMenuItem(value: 'close', child: Text('Close Pane')),
      ],
    ).then((action) {
      if (action == null) return;
      if (action == 'close') {
        widget.onClose?.call();
        return;
      }
      handleSplit(action);
    });
  }

  /// Splits the current leaf into two panes (VSCode-style). The original
  /// pane retains all its open tabs; the new pane starts with just the
  /// active tab so the user can switch one side's view mode to compare.
  void handleSplit(String action) {
    final node = widget.node;
    if (!node.isLeaf) return;
    final activeTab = node.activeTab;
    if (activeTab == null) return;

    SplitDirection newDirection;
    bool insertBefore;
    switch (action) {
      case 'split_right':
        newDirection = SplitDirection.horizontal;
        insertBefore = false;
      case 'split_left':
        newDirection = SplitDirection.horizontal;
        insertBefore = true;
      case 'split_up':
        newDirection = SplitDirection.vertical;
        insertBefore = true;
      case 'split_down':
        newDirection = SplitDirection.vertical;
        insertBefore = false;
      default:
        return;
    }

    final currentLeaf = SplitNode.leaf(
      id: '${node.id}_a',
      tabs: node.tabs,
      activeTabIndex: node.activeTabIndex,
      flex: 1,
    );
    final newLeaf = SplitNode.leaf(
      id: '${node.id}_b',
      noteId: activeTab.noteId,
      viewMode: activeTab.viewMode,
      flex: 1,
    );

    final children = insertBefore
        ? [newLeaf, currentLeaf]
        : [currentLeaf, newLeaf];

    widget.onChanged(
      SplitNode.split(
        id: node.id,
        direction: newDirection,
        children: children,
        flex: node.flex,
      ),
    );
  }

  String viewModeLabel(NoteViewMode vm) => switch (vm) {
    NoteViewMode.edit => 'Edit',
    NoteViewMode.source => 'Source',
    NoteViewMode.rendered => 'Rendered',
  };

  IconData viewModeIcon(NoteViewMode vm) => switch (vm) {
    NoteViewMode.edit => Icons.edit_note,
    NoteViewMode.source => Icons.code,
    NoteViewMode.rendered => Icons.menu_book,
  };
}

/// Tiny reusable icon button used by tab close + pane close actions. Kept
/// compact so it fits inside the 32px tab bar without overflowing.
class _IconAction extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconAction({
    required this.icon,
    required this.size,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

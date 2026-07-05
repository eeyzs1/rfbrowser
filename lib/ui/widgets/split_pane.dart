import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../data/models/split_pane_node.dart';

part 'split_pane_node.dart';
part 'split_pane_divider.dart';
part 'split_pane_tab.dart';

/// Builds a widget for a leaf pane showing [noteId] in [viewMode].
/// [leafId] identifies the pane within the split tree, so the built
/// widget can report focus back to the split-pane store.
typedef NotePaneViewBuilder =
    Widget Function(
      BuildContext context,
      String leafId,
      String noteId,
      NoteViewMode viewMode,
    );

class SplitPane extends StatefulWidget {
  final SplitNode node;
  final NotePaneViewBuilder viewBuilder;

  /// Returns the display title for the note shown in a leaf pane's tab.
  /// If null, the tab falls back to a generic label.
  final String Function(String noteId)? noteTitleOf;
  final ValueChanged<SplitNode> onChanged;
  final VoidCallback? onClose;

  const SplitPane({
    super.key,
    required this.node,
    required this.viewBuilder,
    required this.onChanged,
    this.noteTitleOf,
    this.onClose,
  });

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> with _SplitPaneTabMixin {
  double _cachedAvailableSize = 0;
  List<double> _dragStartFlexValues = [];
  double _dragStartGlobal = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.node.isLeaf) {
      return _buildLeaf();
    }
    return _buildSplit();
  }

  Widget _buildLeaf() {
    final activeTab = widget.node.activeTab;
    return Column(
      children: [
        buildTabBar(),
        Expanded(
          child: activeTab == null
              ? const SizedBox.shrink()
              : widget.viewBuilder(
                  context,
                  widget.node.id,
                  activeTab.noteId,
                  activeTab.viewMode,
                ),
        ),
      ],
    );
  }

  Widget _buildSplit() {
    final children = widget.node.children;
    if (children.isEmpty) return const SizedBox.shrink();

    final isHorizontal = widget.node.direction == SplitDirection.horizontal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;

        final totalFlex = children.fold(0.0, (sum, c) => sum + (c.flex ?? 1));
        final dividerCount = children.length - 1;
        final dividerTotal = dividerCount * 12.0;
        _cachedAvailableSize = totalSize - dividerTotal;

        final List<Widget> paneChildren = [];
        for (var i = 0; i < children.length; i++) {
          if (i > 0) {
            paneChildren.add(
              _Divider(
                key: ValueKey('divider_$i'),
                isHorizontal: isHorizontal,
                onDragStart: (globalPos) => _handleDragStart(i, globalPos),
                onDragUpdate: (globalPos) => _handleDragUpdate(i, globalPos),
                onDoubleTap: () => _handleDividerDoubleTap(i),
              ),
            );
          }

          final childSize =
              ((children[i].flex ?? 1) / totalFlex) * _cachedAvailableSize;

          paneChildren.add(
            SizedBox(
              width: isHorizontal ? childSize : null,
              height: !isHorizontal ? childSize : null,
              child: SplitPane(
                key: ValueKey('pane_${children[i].id}'),
                node: children[i],
                viewBuilder: widget.viewBuilder,
                noteTitleOf: widget.noteTitleOf,
                onChanged: (updated) => _handleChildChanged(i, updated),
                onClose: () => _handleChildClose(i),
              ),
            ),
          );
        }

        return isHorizontal
            ? Row(children: paneChildren)
            : Column(children: paneChildren);
      },
    );
  }

  void _handleDragStart(int childIndex, double globalPos) {
    _dragStartGlobal = globalPos;
    _dragStartFlexValues = widget.node.children
        .map((c) => c.flex ?? 1)
        .toList();
  }

  void _handleDragUpdate(int childIndex, double globalPos) {
    if (_dragStartFlexValues.isEmpty) return;
    if (_cachedAvailableSize <= 0) return;

    final children = widget.node.children;
    if (childIndex < 1 || childIndex >= children.length) return;

    final pixelDelta = globalPos - _dragStartGlobal;

    final leftFlex = _dragStartFlexValues[childIndex - 1];
    final rightFlex = _dragStartFlexValues[childIndex];
    final totalFlex = leftFlex + rightFlex;

    final flexDelta = pixelDelta * totalFlex / _cachedAvailableSize;

    final newLeftFlex = (leftFlex + flexDelta).clamp(
      totalFlex * 0.1,
      totalFlex * 0.9,
    );
    final newRightFlex = totalFlex - newLeftFlex;

    final newChildren = List<SplitNode>.from(children);
    newChildren[childIndex - 1] = _copyWithFlex(
      children[childIndex - 1],
      newLeftFlex,
    );
    newChildren[childIndex] = _copyWithFlex(children[childIndex], newRightFlex);

    widget.onChanged(
      SplitNode.split(
        id: widget.node.id,
        direction: widget.node.direction,
        children: newChildren,
        flex: widget.node.flex,
      ),
    );
  }

  void _handleDividerDoubleTap(int childIndex) {
    final children = widget.node.children;
    if (childIndex < 1 || childIndex >= children.length) return;

    final newChildren = List<SplitNode>.from(children);
    newChildren[childIndex - 1] = _copyWithFlex(children[childIndex - 1], 1);
    newChildren[childIndex] = _copyWithFlex(children[childIndex], 1);

    widget.onChanged(
      SplitNode.split(
        id: widget.node.id,
        direction: widget.node.direction,
        children: newChildren,
        flex: widget.node.flex,
      ),
    );
  }

  void _handleChildChanged(int index, SplitNode updated) {
    final newChildren = List<SplitNode>.from(widget.node.children);
    newChildren[index] = updated;
    widget.onChanged(
      SplitNode.split(
        id: widget.node.id,
        direction: widget.node.direction,
        children: newChildren,
        flex: widget.node.flex,
      ),
    );
  }

  void _handleChildClose(int index) {
    final newChildren = List<SplitNode>.from(widget.node.children);
    newChildren.removeAt(index);

    if (newChildren.isEmpty) {
      widget.onClose?.call();
    } else if (newChildren.length == 1) {
      final remaining = newChildren.first;
      if (remaining.isLeaf) {
        widget.onChanged(
          SplitNode.leaf(
            id: remaining.id,
            tabs: remaining.tabs,
            activeTabIndex: remaining.activeTabIndex,
            flex: widget.node.flex,
          ),
        );
      } else {
        widget.onChanged(
          SplitNode.split(
            id: remaining.id,
            direction: remaining.direction,
            children: remaining.children,
            flex: widget.node.flex,
          ),
        );
      }
    } else {
      widget.onChanged(
        SplitNode.split(
          id: widget.node.id,
          direction: widget.node.direction,
          children: newChildren,
          flex: widget.node.flex,
        ),
      );
    }
  }

  SplitNode _copyWithFlex(SplitNode node, double flex) {
    if (node.isLeaf) {
      return SplitNode.leaf(
        id: node.id,
        tabs: node.tabs,
        activeTabIndex: node.activeTabIndex,
        flex: flex,
      );
    }
    return SplitNode.split(
      id: node.id,
      direction: node.direction,
      children: node.children,
      flex: flex,
    );
  }
}

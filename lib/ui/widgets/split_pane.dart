import 'package:flutter/material.dart';

enum ViewType { browser, editor, graph, ai, backlinks, notes, tabs, canvas }

enum SplitDirection { horizontal, vertical }

class SplitNode {
  final String id;
  final SplitDirection? direction;
  final List<SplitNode> children;
  final double? flex;
  final ViewType? viewType;

  const SplitNode.leaf({
    required this.id,
    required this.viewType,
    this.flex,
  })  : direction = null,
        children = const [];

  const SplitNode.split({
    required this.id,
    required this.direction,
    required this.children,
    this.flex,
  }) : viewType = null;

  bool get isLeaf => viewType != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (direction != null) 'direction': direction!.index,
        if (viewType != null) 'viewType': viewType!.index,
        if (flex != null) 'flex': flex,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };

  factory SplitNode.fromJson(Map<String, dynamic> json) {
    if (json['viewType'] != null) {
      return SplitNode.leaf(
        id: json['id'] as String,
        viewType: ViewType.values[json['viewType'] as int],
        flex: (json['flex'] as num?)?.toDouble(),
      );
    }
    return SplitNode.split(
      id: json['id'] as String,
      direction: SplitDirection.values[json['direction'] as int],
      flex: (json['flex'] as num?)?.toDouble(),
      children: (json['children'] as List)
          .map((c) => SplitNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

typedef ViewBuilder = Widget Function(BuildContext context, ViewType viewType);

class SplitPane extends StatefulWidget {
  final SplitNode node;
  final ViewBuilder viewBuilder;
  final ValueChanged<SplitNode> onChanged;
  final VoidCallback? onClose;

  const SplitPane({
    super.key,
    required this.node,
    required this.viewBuilder,
    required this.onChanged,
    this.onClose,
  });

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> {
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
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: widget.viewBuilder(context, widget.node.viewType!),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    final vt = widget.node.viewType!;

    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showTabContextMenu(details.globalPosition),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(_viewTypeIcon(vt),
                  size: 13, color: theme.colorScheme.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _viewTypeLabel(vt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (widget.onClose != null)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: IconButton(
                    icon: Icon(Icons.close, size: 12, color: theme.hintColor),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    tooltip: 'Close',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTabContextMenu(Offset position) {
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
        const PopupMenuItem(value: 'change_view', child: Text('Change View')),
        if (widget.onClose != null)
          const PopupMenuItem(value: 'close', child: Text('Close')),
      ],
    ).then((action) {
      if (action == null) return;
      _handleTabAction(action);
    });
  }

  void _handleTabAction(String action) {
    if (action == 'close') {
      widget.onClose?.call();
      return;
    }
    if (action == 'change_view') {
      _showViewTypePicker().then((vt) {
        if (vt != null) {
          widget.onChanged(SplitNode.leaf(
            id: widget.node.id,
            viewType: vt,
            flex: widget.node.flex,
          ));
        }
      });
      return;
    }
    _handleSplit(action);
  }

  void _handleSplit(String action) {
    final node = widget.node;
    if (!node.isLeaf) return;

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
      viewType: node.viewType,
      flex: 1,
    );
    final newLeaf = SplitNode.leaf(
      id: '${node.id}_b',
      viewType: node.viewType,
      flex: 1,
    );

    final children =
        insertBefore ? [newLeaf, currentLeaf] : [currentLeaf, newLeaf];

    widget.onChanged(SplitNode.split(
      id: node.id,
      direction: newDirection,
      children: children,
      flex: node.flex,
    ));
  }

  Future<ViewType?> _showViewTypePicker() {
    return showDialog<ViewType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change View'),
        children: ViewType.values.map((vt) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, vt),
            child: Row(
              children: [
                Icon(_viewTypeIcon(vt), size: 16),
                const SizedBox(width: 8),
                Text(_viewTypeLabel(vt)),
              ],
            ),
          );
        }).toList(),
      ),
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

        final totalFlex =
            children.fold(0.0, (sum, c) => sum + (c.flex ?? 1));
        final dividerCount = children.length - 1;
        final dividerTotal = dividerCount * 12.0;
        _cachedAvailableSize = totalSize - dividerTotal;

        final List<Widget> paneChildren = [];
        for (var i = 0; i < children.length; i++) {
          if (i > 0) {
            paneChildren.add(_Divider(
              key: ValueKey('divider_$i'),
              isHorizontal: isHorizontal,
              onDragStart: (globalPos) => _handleDragStart(i, globalPos),
              onDragUpdate: (globalPos) => _handleDragUpdate(i, globalPos),
              onDoubleTap: () => _handleDividerDoubleTap(i),
            ));
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
    _dragStartFlexValues =
        widget.node.children.map((c) => c.flex ?? 1).toList();
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

    final newLeftFlex =
        (leftFlex + flexDelta).clamp(totalFlex * 0.1, totalFlex * 0.9);
    final newRightFlex = totalFlex - newLeftFlex;

    final newChildren = List<SplitNode>.from(children);
    newChildren[childIndex - 1] =
        _copyWithFlex(children[childIndex - 1], newLeftFlex);
    newChildren[childIndex] =
        _copyWithFlex(children[childIndex], newRightFlex);

    widget.onChanged(SplitNode.split(
      id: widget.node.id,
      direction: widget.node.direction,
      children: newChildren,
      flex: widget.node.flex,
    ));
  }

  void _handleDividerDoubleTap(int childIndex) {
    final children = widget.node.children;
    if (childIndex < 1 || childIndex >= children.length) return;

    final newChildren = List<SplitNode>.from(children);
    newChildren[childIndex - 1] = _copyWithFlex(children[childIndex - 1], 1);
    newChildren[childIndex] = _copyWithFlex(children[childIndex], 1);

    widget.onChanged(SplitNode.split(
      id: widget.node.id,
      direction: widget.node.direction,
      children: newChildren,
      flex: widget.node.flex,
    ));
  }

  void _handleChildChanged(int index, SplitNode updated) {
    final newChildren = List<SplitNode>.from(widget.node.children);
    newChildren[index] = updated;
    widget.onChanged(SplitNode.split(
      id: widget.node.id,
      direction: widget.node.direction,
      children: newChildren,
      flex: widget.node.flex,
    ));
  }

  void _handleChildClose(int index) {
    final newChildren = List<SplitNode>.from(widget.node.children);
    newChildren.removeAt(index);

    if (newChildren.isEmpty) {
      widget.onClose?.call();
    } else if (newChildren.length == 1) {
      final remaining = newChildren.first;
      if (remaining.isLeaf) {
        widget.onChanged(SplitNode.leaf(
          id: remaining.id,
          viewType: remaining.viewType,
          flex: widget.node.flex,
        ));
      } else {
        widget.onChanged(SplitNode.split(
          id: remaining.id,
          direction: remaining.direction,
          children: remaining.children,
          flex: widget.node.flex,
        ));
      }
    } else {
      widget.onChanged(SplitNode.split(
        id: widget.node.id,
        direction: widget.node.direction,
        children: newChildren,
        flex: widget.node.flex,
      ));
    }
  }

  SplitNode _copyWithFlex(SplitNode node, double flex) {
    if (node.isLeaf) {
      return SplitNode.leaf(id: node.id, viewType: node.viewType, flex: flex);
    }
    return SplitNode.split(
      id: node.id,
      direction: node.direction,
      children: node.children,
      flex: flex,
    );
  }

  String _viewTypeLabel(ViewType vt) => switch (vt) {
        ViewType.browser => 'Browser',
        ViewType.editor => 'Editor',
        ViewType.graph => 'Graph',
        ViewType.ai => 'AI Chat',
        ViewType.backlinks => 'Backlinks',
        ViewType.notes => 'Notes',
        ViewType.tabs => 'Tabs',
        ViewType.canvas => 'Canvas',
      };

  IconData _viewTypeIcon(ViewType vt) => switch (vt) {
        ViewType.browser => Icons.language,
        ViewType.editor => Icons.edit_note,
        ViewType.graph => Icons.hub,
        ViewType.ai => Icons.smart_toy,
        ViewType.backlinks => Icons.link,
        ViewType.notes => Icons.description,
        ViewType.tabs => Icons.tab,
        ViewType.canvas => Icons.dashboard,
      };
}

class _Divider extends StatefulWidget {
  final bool isHorizontal;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDoubleTap;

  const _Divider({
    super.key,
    required this.isHorizontal,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDoubleTap,
  });

  @override
  State<_Divider> createState() => _DividerState();
}

class _DividerState extends State<_Divider> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.isHorizontal
          ? (details) => widget.onDragStart(details.globalPosition.dx)
          : null,
      onHorizontalDragUpdate: widget.isHorizontal
          ? (details) => widget.onDragUpdate(details.globalPosition.dx)
          : null,
      onVerticalDragStart: !widget.isHorizontal
          ? (details) => widget.onDragStart(details.globalPosition.dy)
          : null,
      onVerticalDragUpdate: !widget.isHorizontal
          ? (details) => widget.onDragUpdate(details.globalPosition.dy)
          : null,
      onDoubleTap: widget.onDoubleTap,
      child: MouseRegion(
        cursor: widget.isHorizontal
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        child: SizedBox(
          width: widget.isHorizontal ? 12 : double.infinity,
          height: widget.isHorizontal ? double.infinity : 12,
          child: Center(
            child: Container(
              width: widget.isHorizontal ? 1 : double.infinity,
              height: widget.isHorizontal ? double.infinity : 1,
              color: theme.dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}

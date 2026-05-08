import 'package:flutter/material.dart';

class ResizablePanel extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final bool isLeft;

  const ResizablePanel({
    super.key,
    required this.child,
    this.initialWidth = 240,
    this.minWidth = 160,
    this.maxWidth = 480,
    this.isLeft = true,
  });

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel> {
  late double _width;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _width,
      child: Row(
        children: [
          if (!widget.isLeft) _buildDragHandle(theme),
          Expanded(child: widget.child),
          if (widget.isLeft) _buildDragHandle(theme),
        ],
      ),
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          setState(() {
            if (widget.isLeft) {
              _width += details.delta.dx;
            } else {
              _width -= details.delta.dx;
            }
            _width = _width.clamp(widget.minWidth, widget.maxWidth);
          });
        },
        child: Container(
          width: 4,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              height: double.infinity,
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

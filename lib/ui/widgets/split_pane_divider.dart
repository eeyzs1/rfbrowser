part of 'split_pane.dart';

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

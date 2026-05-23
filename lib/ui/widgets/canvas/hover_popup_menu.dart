import 'dart:async';
import 'package:flutter/material.dart';

class HoverPopupMenuButton<T> extends StatefulWidget {
  final String tooltip;
  final Widget icon;
  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;
  final void Function(T) onSelected;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;

  const HoverPopupMenuButton({
    required this.tooltip,
    required this.icon,
    required this.onSelected,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.constraints = const BoxConstraints(minWidth: 28, minHeight: 28),
    super.key,
  });

  @override
  State<HoverPopupMenuButton<T>> createState() =>
      _HoverPopupMenuButtonState<T>();
}

class _HoverPopupMenuButtonState<T> extends State<HoverPopupMenuButton<T>> {
  OverlayEntry? _overlayEntry;
  bool _isHoveringButton = false;
  bool _isHoveringMenu = false;
  Timer? _closeTimer;

  static const _closeDelay = Duration(milliseconds: 250);

  void _showMenu() {
    if (_overlayEntry != null) return;
    _closeTimer?.cancel();

    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final overlaySize = overlay.size;

    final items = widget.itemBuilder(context);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return HoverMenuOverlay<T>(
          offset: offset,
          buttonWidth: box.size.width,
          overlaySize: overlaySize,
          items: items,
          onSelected: (value) {
            _removeMenu();
            widget.onSelected(value);
          },
          onDismiss: _removeMenu,
          onMenuHoverChanged: (hovering) {
            _isHoveringMenu = hovering;
            if (hovering) {
              _closeTimer?.cancel();
            } else {
              _scheduleClose();
            }
          },
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _scheduleClose() {
    if (!_isHoveringButton && !_isHoveringMenu) {
      _closeTimer?.cancel();
      _closeTimer = Timer(_closeDelay, () {
        if (!_isHoveringButton && !_isHoveringMenu && mounted) {
          _removeMenu();
        }
      });
    }
  }

  void _removeMenu() {
    _closeTimer?.cancel();
    final entry = _overlayEntry;
    _overlayEntry = null;
    _isHoveringMenu = false;
    if (entry != null && mounted) {
      entry.remove();
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _isHoveringButton = true;
        _closeTimer?.cancel();
        _showMenu();
      },
      onExit: (_) {
        _isHoveringButton = false;
        _scheduleClose();
      },
      child: Tooltip(
        message: widget.tooltip,
        preferBelow: false,
        child: IconButton(
          icon: widget.icon,
          onPressed: _showMenu,
          tooltip: '',
          padding: widget.padding,
          constraints: widget.constraints,
        ),
      ),
    );
  }
}

class HoverMenuOverlay<T> extends StatelessWidget {
  final Offset offset;
  final double buttonWidth;
  final Size overlaySize;
  final List<PopupMenuEntry<T>> items;
  final void Function(T) onSelected;
  final VoidCallback onDismiss;
  final void Function(bool) onMenuHoverChanged;

  const HoverMenuOverlay({
    required this.offset,
    required this.buttonWidth,
    required this.overlaySize,
    required this.items,
    required this.onSelected,
    required this.onDismiss,
    required this.onMenuHoverChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) => onDismiss(),
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Positioned(
          left: offset.dx,
          top: offset.dy + 28,
          child: MouseRegion(
            onEnter: (_) => onMenuHoverChanged(true),
            onExit: (_) => onMenuHoverChanged(false),
            child: Listener(
              onPointerDown: (_) {},
              behavior: HitTestBehavior.opaque,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(4),
                color: theme.popupMenuTheme.color ?? theme.cardColor,
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: buttonWidth,
                      maxWidth: overlaySize.width - offset.dx - 8,
                      maxHeight: overlaySize.height - offset.dy - 40,
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: ListBody(
                        children: items.map((entry) {
                          if (entry is PopupMenuDivider) {
                            return const Divider(height: 1);
                          }
                          if (entry is PopupMenuItem<T>) {
                            return _HoverMenuItem<T>(
                              value: entry.value,
                              enabled: entry.enabled,
                              onSelected: onSelected,
                              textStyle: theme.popupMenuTheme.textStyle,
                              child: entry.child!,
                            );
                          }
                          return const SizedBox.shrink();
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HoverMenuItem<T> extends StatefulWidget {
  final T? value;
  final bool enabled;
  final void Function(T) onSelected;
  final TextStyle? textStyle;
  final Widget child;

  const _HoverMenuItem({
    required this.value,
    required this.enabled,
    required this.onSelected,
    this.textStyle,
    required this.child,
  });

  @override
  State<_HoverMenuItem<T>> createState() => _HoverMenuItemState<T>();
}

class _HoverMenuItemState<T> extends State<_HoverMenuItem<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.enabled && widget.value != null
            ? () => widget.onSelected(widget.value as T)
            : null,
        child: Container(
          color: _isHovered ? theme.hoverColor : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DefaultTextStyle(
            style: (widget.textStyle ?? theme.textTheme.bodyMedium!).copyWith(
              color: widget.enabled ? null : theme.disabledColor,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

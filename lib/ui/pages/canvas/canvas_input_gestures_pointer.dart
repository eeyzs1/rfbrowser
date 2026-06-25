part of '../canvas_page.dart';

/// Pointer signal, hover, cursor, and zoom handlers.
mixin _CanvasPointerGesturesMixin on _CanvasViewStateBase {
  @override
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta.dy;
      final zoomFactor = scrollDelta < 0 ? 1.05 : 0.95;
      final newScale = (_scale * zoomFactor).clamp(
        _CanvasViewStateBase._minScale,
        _CanvasViewStateBase._maxScale,
      );

      final screenPos = Offset(event.localPosition.dx, event.localPosition.dy);
      final worldBefore = _screenToWorld(screenPos);

      _scale = newScale;
      final worldAfter = _screenToWorld(screenPos);
      _cameraX += worldBefore.dx - worldAfter.dx;
      _cameraY += worldBefore.dy - worldAfter.dy;
      _cameraNotifier.notify();
    } else if (event is PointerDownEvent) {
      if (event.buttons & kSecondaryButton != 0) {
        _altKeyPressed = true;
      }
    }
  }

  @override
  void _onHover(PointerHoverEvent event) {
    final worldPos = _screenToWorld(event.localPosition);
    final hitCard = _hitTestCardWithResize(worldPos);
    _ResizeEdge edge = _ResizeEdge.none;
    String? hoverId;
    ConnectionSide? hoverSide;
    bool hoveringLine = false;
    if (hitCard != null) {
      edge = _hitTestResizeHandle(worldPos, hitCard);
      hoverId = hitCard.id;
    }
    final connLineHit = _hitTestConnectionLine(worldPos);
    if (connLineHit != null) {
      hoveringLine = true;
    }
    final portHit = _hitTestConnectionPoint(worldPos);
    if (portHit != null) {
      hoverId = portHit.$1;
      hoverSide = portHit.$2;
      hoveringLine = false;
    }
    if (edge != _hoverResizeEdge ||
        hoverId != _hoverCardId ||
        hoverSide != _hoveredConnectionSide ||
        hoveringLine != _hoveringConnectionLine) {
      setState(() {
        _hoverResizeEdge = edge;
        _hoverCardId = hoverId;
        _hoveredConnectionSide = hoverSide;
        _hoveringConnectionLine = hoveringLine;
      });
    }
  }

  @override
  MouseCursor _getCursor() {
    if (_isDraggingFromPort) return SystemMouseCursors.precise;
    if (_hoveredConnectionSide != null) return SystemMouseCursors.precise;
    switch (_hoverResizeEdge) {
      case _ResizeEdge.corner:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case _ResizeEdge.right:
        return SystemMouseCursors.resizeLeftRight;
      case _ResizeEdge.bottom:
        return SystemMouseCursors.resizeUpDown;
      case _ResizeEdge.none:
        if (_hoveringConnectionLine) return SystemMouseCursors.click;
        if (_hoverCardId != null) return SystemMouseCursors.click;
        return SystemMouseCursors.basic;
    }
  }

  @override
  void _zoomIn() {
    final newScale = (_scale * 1.2).clamp(
      _CanvasViewStateBase._minScale,
      _CanvasViewStateBase._maxScale,
    );
    _scale = newScale;
    _cameraNotifier.notify();
  }

  @override
  void _zoomOut() {
    final newScale = (_scale / 1.2).clamp(
      _CanvasViewStateBase._minScale,
      _CanvasViewStateBase._maxScale,
    );
    _scale = newScale;
    _cameraNotifier.notify();
  }

  @override
  void _zoomReset() {
    _scale = 1.0;
    _cameraNotifier.notify();
  }
}

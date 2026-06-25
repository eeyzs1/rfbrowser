part of '../canvas_page.dart';

/// Tap gesture handlers: _onTapUp, _onDoubleTapDown, _onSecondaryTapUp.
mixin _CanvasTapGesturesMixin on _CanvasViewStateBase {
  @override
  void _onTapUp(TapUpDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final hit = _hitTestCard(worldPos);
    final wpHit = _hitTestWaypoint(worldPos);

    if (_isClickingConnection && _clickedConnectionId != null) {
      ref.read(canvasProvider.notifier).selectConnection(_clickedConnectionId);
      _isClickingConnection = false;
      _clickedConnectionId = null;
      return;
    }
    _isClickingConnection = false;
    _clickedConnectionId = null;

    final connHit = _hitTestConnectionLine(worldPos);

    final selectedIds = _selectedCardIds;
    if (selectedIds.length == 1) {
      final selectedCard = ref
          .read(canvasProvider.notifier)
          .cardById(selectedIds.first);
      if (selectedCard != null) {
        final edge = _hitTestResizeHandle(worldPos, selectedCard);
        if (edge != _ResizeEdge.none) return;
      }
    }

    if (_styleBrushMode && hit != null && _copiedStyle != null) {
      ref
          .read(canvasProvider.notifier)
          .updateCard(hit.copyWith(style: _copiedStyle));
      setState(() {
        _styleBrushMode = false;
        _copiedStyle = null;
      });
      return;
    }

    if (_connectingFromCardId != null &&
        hit != null &&
        hit.id != _connectingFromCardId) {
      _createConnection(_connectingFromCardId!, hit.id);
      setState(() => _connectingFromCardId = null);
    } else if (wpHit != null) {
      ref.read(canvasProvider.notifier).selectConnection(wpHit.$1);
    } else if (hit != null && connHit == null) {
      if (selectedIds.length == 1 && hit.id == selectedIds.first) {
        _startInlineEditing(hit.id);
      } else {
        _finishInlineEditing();
        ref.read(canvasProvider.notifier).selectCard(hit.id);
      }
    } else if (connHit != null) {
      if (hit != null) {
        final cardCenter = Offset(
          hit.x + hit.width / 2,
          hit.y + hit.height / 2,
        );
        final distToCardCenter = (worldPos - cardCenter).distance;
        if (distToCardCenter < math.min(hit.width, hit.height) * 0.35) {
          if (selectedIds.length == 1 && hit.id == selectedIds.first) {
            _startInlineEditing(hit.id);
          } else {
            _finishInlineEditing();
            ref.read(canvasProvider.notifier).selectCard(hit.id);
          }
          return;
        }
      }
      ref.read(canvasProvider.notifier).selectConnection(connHit.$1);
    } else if (hit != null) {
      if (selectedIds.length == 1 && hit.id == selectedIds.first) {
        _startInlineEditing(hit.id);
      } else {
        _finishInlineEditing();
        ref.read(canvasProvider.notifier).selectCard(hit.id);
      }
    } else {
      ref.read(canvasProvider.notifier).selectConnection(null);
      _finishInlineEditing();
      ref.read(canvasProvider.notifier).selectCard(null);
    }
  }

  @override
  void _onDoubleTapDown(TapDownDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final hit = _hitTestCard(worldPos);
    if (hit != null) {
      _finishInlineEditing();
      _openCardContent(hit);
    } else {
      final connHit = _hitTestConnectionLine(worldPos);
      if (connHit != null) {
        final (snappedPos, insertIdx) = _snapWaypointToConnection(
          connHit.$1,
          worldPos,
        );
        ref
            .read(canvasProvider.notifier)
            .addWaypoint(
              connHit.$1,
              Offset(_snapToGrid(snappedPos.dx), _snapToGrid(snappedPos.dy)),
              insertIndex: insertIdx,
            );
      }
    }
  }

  @override
  void _onSecondaryTapUp(TapUpDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    final canvasData = ref.read(canvasProvider);

    if (canvasData.selectedConnectionId != null) {
      _showConnectionContextMenu(
        details.globalPosition,
        canvasData.selectedConnectionId!,
        worldPos,
      );
      return;
    }
    if (canvasData.selectedCardIds.isNotEmpty) {
      final firstSelected = ref
          .read(canvasProvider.notifier)
          .cardById(canvasData.selectedCardIds.first);
      if (firstSelected != null) {
        _showCardContextMenu(details.globalPosition, firstSelected);
        return;
      }
    }

    final wpHit = _hitTestWaypoint(worldPos);
    if (wpHit != null) {
      _showWaypointContextMenu(details.globalPosition, wpHit.$1, wpHit.$2);
      return;
    }
    final hit = _hitTestCard(worldPos);
    if (hit != null) {
      ref.read(canvasProvider.notifier).selectCard(hit.id);
      _showCardContextMenu(details.globalPosition, hit);
    } else {
      final connHit = _hitTestConnectionLine(worldPos);
      if (connHit != null) {
        ref.read(canvasProvider.notifier).selectConnection(connHit.$1);
        _showConnectionContextMenu(
          details.globalPosition,
          connHit.$1,
          worldPos,
        );
      } else {
        _showContextMenu(context, details, canvasData, worldPos);
      }
    }
  }
}

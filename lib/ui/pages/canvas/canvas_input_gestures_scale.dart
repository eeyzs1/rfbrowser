part of '../canvas_page.dart';

/// Scale gesture handlers: _onScaleStart, _onScaleUpdate, _onScaleEnd.
mixin _CanvasScaleGesturesMixin on _CanvasViewStateBase {
  @override
  void _onScaleStart(ScaleStartDetails details) {
    if (_inlineEditingCardId != null) {
      _finishInlineEditing();
    }
    _lastLocalFocalPoint = details.localFocalPoint;
    _lastScale = _scale;
    final worldPos = _screenToWorld(details.localFocalPoint);

    final selectedIds = _selectedCardIds;
    if (selectedIds.length == 1) {
      final selectedCard = ref
          .read(canvasProvider.notifier)
          .cardById(selectedIds.first);
      if (selectedCard != null) {
        final edge = _hitTestResizeHandle(worldPos, selectedCard);
        if (edge != _ResizeEdge.none) {
          setState(() {
            _resizeEdge = edge;
            _draggingCardId = null;
          });
          _resizeStartCard = selectedCard;
          _resizeStartLocalPoint = details.localFocalPoint;
          return;
        }
      }
    }

    final hitCard = _hitTestCardWithResize(worldPos);
    if (hitCard != null) {
      final edge = _hitTestResizeHandle(worldPos, hitCard);
      if (edge != _ResizeEdge.none) {
        if (ref.read(canvasProvider.notifier).isLayerLocked(hitCard.id)) return;
        ref.read(canvasProvider.notifier).selectCard(hitCard.id);
        setState(() {
          _resizeEdge = edge;
          _draggingCardId = null;
        });
        _resizeStartCard = hitCard;
        _resizeStartLocalPoint = details.localFocalPoint;
        return;
      }
    }

    final hit = _hitTestCard(worldPos);
    _resizeEdge = _ResizeEdge.none;
    if (hit != null) {
      if (ref.read(canvasProvider.notifier).isLayerLocked(hit.id)) {
        return;
      }
      final isShiftHeld =
          HardwareKeyboard.instance.logicalKeysPressed.contains(
            LogicalKeyboardKey.shiftLeft,
          ) ||
          HardwareKeyboard.instance.logicalKeysPressed.contains(
            LogicalKeyboardKey.shiftRight,
          );
      if (isShiftHeld) {
        ref.read(canvasProvider.notifier).selectCard(hit.id, additive: true);
        _draggingCardId = hit.id;
        _dragStartCard = hit;
        _dragStartLocalPoint = details.localFocalPoint;
        _multiDragStarts = {};
        for (final id in _selectedCardIds) {
          final c = ref.read(canvasProvider.notifier).cardById(id);
          if (c != null) _multiDragStarts[id] = (c.x, c.y);
        }
      } else if (_selectedCardIds.contains(hit.id)) {
        _draggingCardId = hit.id;
        _dragStartCard = hit;
        _dragStartLocalPoint = details.localFocalPoint;
        _multiDragStarts = {};
        for (final id in _selectedCardIds) {
          final c = ref.read(canvasProvider.notifier).cardById(id);
          if (c != null) _multiDragStarts[id] = (c.x, c.y);
        }
      } else {
        ref.read(canvasProvider.notifier).selectCard(hit.id);
        _draggingCardId = hit.id;
        _dragStartCard = hit;
        _dragStartLocalPoint = details.localFocalPoint;
        _multiDragStarts = {hit.id: (hit.x, hit.y)};
      }
      return;
    }

    final portHit = _hitTestConnectionPoint(worldPos);
    if (portHit != null) {
      if (ref.read(canvasProvider.notifier).isLayerLocked(portHit.$1)) return;
      setState(() {
        _connectingFromCardId = portHit.$1;
        _connectingFromSide = portHit.$2;
        _connectingFromSideOffset = portHit.$3;
        _isDraggingFromPort = true;
        _connectingPreviewEnd = _w2s(worldPos.dx, worldPos.dy);
        ref.read(canvasProvider.notifier).selectConnection(null);
      });
      return;
    }
    final wpHit = _hitTestWaypoint(worldPos);
    if (wpHit != null) {
      _draggingWaypointConnId = wpHit.$1;
      _draggingWaypointIndex = wpHit.$2;
      ref.read(canvasProvider.notifier).selectConnection(wpHit.$1);
    } else {
      final connLineHit = _hitTestConnectionLine(worldPos);
      if (connLineHit != null) {
        _isClickingConnection = true;
        _clickedConnectionId = connLineHit.$1;
        return;
      }
      final isShiftHeld =
          HardwareKeyboard.instance.logicalKeysPressed.contains(
            LogicalKeyboardKey.shiftLeft,
          ) ||
          HardwareKeyboard.instance.logicalKeysPressed.contains(
            LogicalKeyboardKey.shiftRight,
          );
      if (isShiftHeld) {
        _isBoxSelecting = true;
        _boxSelectStart = worldPos;
        _selectionRect = null;
      }
      _draggingCardId = null;
    }
  }

  @override
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_resizeEdge != _ResizeEdge.none &&
        _selectedCardIds.length == 1 &&
        details.pointerCount == 1) {
      final startCard = _resizeStartCard;
      final startPoint = _resizeStartLocalPoint;
      if (startCard != null && startPoint != null) {
        final totalDx = (details.localFocalPoint.dx - startPoint.dx) / _scale;
        final totalDy = (details.localFocalPoint.dy - startPoint.dy) / _scale;
        double newWidth = startCard.width;
        double newHeight = startCard.height;

        if (_resizeEdge == _ResizeEdge.corner ||
            _resizeEdge == _ResizeEdge.right) {
          newWidth = math.max(100.0, startCard.width + totalDx);
        }
        if (_resizeEdge == _ResizeEdge.corner ||
            _resizeEdge == _ResizeEdge.bottom) {
          newHeight = math.max(80.0, startCard.height + totalDy);
        }

        ref
            .read(canvasProvider.notifier)
            .updateCardInMemory(
              startCard.copyWith(
                width: _snapToGrid(newWidth),
                height: _snapToGrid(newHeight),
              ),
            );
      }
    } else if (_draggingCardId != null && details.pointerCount == 1) {
      final startCard = _dragStartCard;
      final startPoint = _dragStartLocalPoint;
      if (startCard != null && startPoint != null) {
        final totalDx = (details.localFocalPoint.dx - startPoint.dx) / _scale;
        final totalDy = (details.localFocalPoint.dy - startPoint.dy) / _scale;
        final newX = _snapToGrid(startCard.x + totalDx);
        final newY = _snapToGrid(startCard.y + totalDy);

        final tempCard = startCard.copyWith(x: newX, y: newY);
        final guides = _computeAlignmentGuides(
          tempCard,
          ref.read(canvasProvider).cards,
        );
        var snapX = newX;
        var snapY = newY;
        final snapOffX = _getSnapOffset(
          tempCard,
          ref.read(canvasProvider).cards,
        );
        final snapOffY = _getSnapOffsetY(
          tempCard,
          ref.read(canvasProvider).cards,
        );
        if (snapOffX != null) snapX = newX + snapOffX;
        if (snapOffY != null) snapY = newY + snapOffY;

        if (_selectedCardIds.length > 1 && _multiDragStarts.isNotEmpty) {
          final baseDx = snapX - startCard.x;
          final baseDy = snapY - startCard.y;
          final moves = <String, (double, double)>{};
          for (final entry in _multiDragStarts.entries) {
            moves[entry.key] = (
              entry.value.$1 + baseDx,
              entry.value.$2 + baseDy,
            );
          }
          ref.read(canvasProvider.notifier).batchMoveCards(moves);
        } else {
          ref
              .read(canvasProvider.notifier)
              .updateCardInMemory(startCard.copyWith(x: snapX, y: snapY));
        }
        setState(() => _alignmentGuides = guides);
      }
    } else if (_isFreehandDrawing &&
        _freehandCardId != null &&
        details.pointerCount == 1) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      _freehandPoints.add(worldPos);
      ref
          .read(canvasProvider.notifier)
          .setFreehandPoints(_freehandCardId!, List.from(_freehandPoints));
    } else if (_isDraggingFromPort &&
        _connectingFromCardId != null &&
        details.pointerCount == 1) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      setState(() {
        _connectingPreviewEnd = _w2s(worldPos.dx, worldPos.dy);
        final portHit = _hitTestConnectionPoint(worldPos);
        _hoveredConnectionSide =
            (portHit != null && portHit.$1 != _connectingFromCardId)
            ? portHit.$2
            : null;
        _hoverCardId = (portHit != null && portHit.$1 != _connectingFromCardId)
            ? portHit.$1
            : null;
      });
    } else if (_draggingWaypointConnId != null &&
        _draggingWaypointIndex >= 0 &&
        details.pointerCount == 1) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      ref
          .read(canvasProvider.notifier)
          .moveWaypoint(
            _draggingWaypointConnId!,
            _draggingWaypointIndex,
            Offset(_snapToGrid(worldPos.dx), _snapToGrid(worldPos.dy)),
          );
    } else if (_isBoxSelecting &&
        _boxSelectStart != null &&
        details.pointerCount == 1) {
      final worldPos = _screenToWorld(details.localFocalPoint);
      final left = math.min(_boxSelectStart!.dx, worldPos.dx);
      final top = math.min(_boxSelectStart!.dy, worldPos.dy);
      final right = math.max(_boxSelectStart!.dx, worldPos.dx);
      final bottom = math.max(_boxSelectStart!.dy, worldPos.dy);
      setState(() {
        _selectionRect = Rect.fromLTRB(left, top, right, bottom);
      });
    } else if (details.pointerCount == 1 &&
        !_isBoxSelecting &&
        !_isClickingConnection) {
      final currentLocal = details.localFocalPoint;
      final lastLocal = _lastLocalFocalPoint ?? currentLocal;
      _cameraX -= (currentLocal.dx - lastLocal.dx) / _scale;
      _cameraY -= (currentLocal.dy - lastLocal.dy) / _scale;
      _cameraNotifier.notify();
    } else if (details.pointerCount == 2 && _lastScale != null) {
      final newScale = (_lastScale! * details.scale).clamp(
        _CanvasViewStateBase._minScale,
        _CanvasViewStateBase._maxScale,
      );
      final focalWorld = _screenToWorld(details.localFocalPoint);
      _cameraX =
          focalWorld.dx - (details.localFocalPoint.dx - _viewW / 2) / newScale;
      _cameraY =
          focalWorld.dy - (details.localFocalPoint.dy - _viewH / 2) / newScale;
      _scale = newScale;
      _cameraNotifier.notify();
      _lastScale = _scale;
    }
    _lastLocalFocalPoint = details.localFocalPoint;
  }

  @override
  void _onScaleEnd(ScaleEndDetails details) {
    if (_isBoxSelecting && _selectionRect != null) {
      final cards = ref.read(canvasProvider).cards;
      final matchedIds = <String>[];
      for (final card in cards) {
        if (_selectionRect!.overlaps(card.rect)) {
          matchedIds.add(card.id);
        }
      }
      ref.read(canvasProvider.notifier).selectCards(matchedIds);
      setState(() {
        _isBoxSelecting = false;
        _selectionRect = null;
        _boxSelectStart = null;
      });
    } else if (_draggingCardId != null) {
      ref.read(canvasProvider.notifier).persist();
      _draggingCardId = null;
      _dragStartCard = null;
      _dragStartLocalPoint = null;
      _multiDragStarts = {};
      setState(() => _alignmentGuides = []);
    }
    if (_resizeEdge != _ResizeEdge.none) {
      ref.read(canvasProvider.notifier).persist();
      _resizeEdge = _ResizeEdge.none;
      _resizeStartCard = null;
      _resizeStartLocalPoint = null;
    }
    if (_draggingWaypointConnId != null) {
      ref.read(canvasProvider.notifier).persist();
      _draggingWaypointConnId = null;
      _draggingWaypointIndex = -1;
    }
    if (_isDraggingFromPort && _connectingFromCardId != null) {
      if (_lastLocalFocalPoint != null) {
        final worldPos = _screenToWorld(_lastLocalFocalPoint!);
        final portHit = _hitTestConnectionPoint(worldPos);
        if (portHit != null && portHit.$1 != _connectingFromCardId) {
          _createConnectionWithSides(
            _connectingFromCardId!,
            portHit.$1,
            _connectingFromSide,
            portHit.$2,
            _connectingFromSideOffset,
            portHit.$3,
          );
        }
      }
      setState(() {
        _isDraggingFromPort = false;
        _connectingFromCardId = null;
        _connectingFromSide = null;
        _connectingFromSideOffset = 0.5;
        _connectingPreviewEnd = null;
        _hoveredConnectionSide = null;
        _hoverCardId = null;
      });
    }
    if (_isClickingConnection && _clickedConnectionId != null) {
      ref.read(canvasProvider.notifier).selectConnection(_clickedConnectionId);
    }
    _isClickingConnection = false;
    _clickedConnectionId = null;
    _lastLocalFocalPoint = null;
    _lastScale = null;
  }
}

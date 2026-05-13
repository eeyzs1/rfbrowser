part of '../canvas_page.dart';

mixin CanvasInputHandlersMixin on _CanvasViewStateBase {
    @override
    Offset _screenToWorld(Offset screenPos) {
      return Offset(
        (screenPos.dx - _viewW / 2) / _scale + _cameraX,
        (screenPos.dy - _viewH / 2) / _scale + _cameraY,
      );
    }

    @override
    double _snapToGrid(double value) {
      final settings = ref.read(canvasProvider).settings;
      if (!settings.snapToGrid) return value;
      return (value / _CanvasViewStateBase._gridSize).round() * _CanvasViewStateBase._gridSize;
    }

    @override
    _ResizeEdge _hitTestResizeHandle(Offset worldPos, CanvasCard card) {
      final edgeW = _CanvasViewStateBase._edgeHitWidth / _scale;
      final cornerSize = _CanvasViewStateBase._resizeHandleSize / _scale;

      final cornerRect = Rect.fromCenter(
        center: Offset(card.x + card.width, card.y + card.height),
        width: cornerSize * 2,
        height: cornerSize * 2,
      );
      if (cornerRect.contains(worldPos)) return _ResizeEdge.corner;

      final rightEdge = Rect.fromLTWH(
        card.x + card.width - edgeW,
        card.y,
        edgeW * 2,
        card.height,
      );
      if (rightEdge.contains(worldPos)) return _ResizeEdge.right;

      final bottomEdge = Rect.fromLTWH(
        card.x,
        card.y + card.height - edgeW,
        card.width,
        edgeW * 2,
      );
      if (bottomEdge.contains(worldPos)) return _ResizeEdge.bottom;

      return _ResizeEdge.none;
    }

    CanvasCard? _hitTestCardWithResize(Offset worldPos) {
      final cards = ref.read(canvasProvider).cards;
      final edgeW = _CanvasViewStateBase._edgeHitWidth / _scale;
      final cornerSize = _CanvasViewStateBase._resizeHandleSize / _scale;
      final expand = math.max(edgeW, cornerSize);
      for (final card in cards.reversed) {
        final expandedRect = Rect.fromLTWH(
          card.x - expand,
          card.y - expand,
          card.width + expand * 2,
          card.height + expand * 2,
        );
        if (expandedRect.contains(worldPos)) return card;
      }
      return null;
    }

    CanvasCard? _hitTestCard(Offset worldPos) {
      final cards = ref.read(canvasProvider).cards;
      for (final card in cards.reversed) {
        if (card.rect.contains(worldPos)) return card;
      }
      return null;
    }

    (String, int)? _hitTestWaypoint(Offset worldPos) {
      final canvasData = ref.read(canvasProvider);
      for (final conn in canvasData.connections) {
        if (conn.waypoints.isEmpty) continue;
        final connStyle = conn.style ?? CanvasConnectionStyle.defaults;
        final hitRadius = (connStyle.waypointSize + 4.0) / _scale;
        for (int i = 0; i < conn.waypoints.length; i++) {
          final wp = conn.waypoints[i];
          final dist = math.sqrt(
            math.pow(worldPos.dx - wp.dx, 2) + math.pow(worldPos.dy - wp.dy, 2),
          );
          if (dist <= hitRadius) return (conn.id, i);
        }
      }
      return null;
    }

    (String, double)? _hitTestConnectionLine(Offset worldPos) {
      final canvasData = ref.read(canvasProvider);
      final hitRadius = 12.0 / _scale;
      final hits = <(String, double)>[];
      for (final conn in canvasData.connections) {
        final from = ref.read(canvasProvider.notifier).cardById(conn.fromCardId);
        final to = ref.read(canvasProvider.notifier).cardById(conn.toCardId);
        if (from == null || to == null) continue;
        final fromPoint = conn.fromSide.point(from.rect, conn.fromSideOffset);
        final toPoint = conn.toSide.point(to.rect, conn.toSideOffset);
        final style = conn.style ?? CanvasConnectionStyle.defaults;
        final points = _connectionPathPoints(
          fromPoint,
          toPoint,
          conn.waypoints,
          style.pathType,
        );
        for (int i = 0; i < points.length - 1; i++) {
          final dist = _pointToSegmentDist(worldPos, points[i], points[i + 1]);
          if (dist <= hitRadius) {
            hits.add((conn.id, dist));
            break;
          }
        }
      }
      if (hits.isEmpty) return null;
      hits.sort((a, b) => a.$2.compareTo(b.$2));
      final currentId = canvasData.selectedConnectionId;
      if (currentId != null) {
        final idx = hits.indexWhere((h) => h.$1 == currentId);
        if (idx >= 0 && idx < hits.length - 1) return hits[idx + 1];
      }
      return hits.first;
    }

    List<Offset> _connectionPathPoints(
      Offset fromPoint,
      Offset toPoint,
      List<Offset> waypoints,
      ConnectionPath pathType,
    ) {
      if (waypoints.isEmpty || pathType != ConnectionPath.curved) {
        return [fromPoint, ...waypoints, toPoint];
      }
      final points = <Offset>[fromPoint];
      final allPts = [fromPoint, ...waypoints];
      for (int i = 0; i < allPts.length - 1; i++) {
        final prev = allPts[i];
        final curr = allPts[i + 1];
        final next = i + 2 < allPts.length ? allPts[i + 2] : toPoint;
        final cp1 = Offset(
          prev.dx + (curr.dx - prev.dx) * 0.5,
          prev.dy + (curr.dy - prev.dy) * 0.1,
        );
        final cp2 = Offset(
          curr.dx - (next.dx - curr.dx) * 0.1,
          curr.dy - (next.dy - curr.dy) * 0.5,
        );
        const samples = 8;
        for (int t = 1; t <= samples; t++) {
          points.add(_cubicBezierPoint(prev, cp1, cp2, curr, t / samples));
        }
      }
      final lastWp = waypoints.last;
      final cp1 = Offset(
        lastWp.dx + (toPoint.dx - lastWp.dx) * 0.5,
        lastWp.dy + (toPoint.dy - lastWp.dy) * 0.1,
      );
      final cp2 = Offset(
        toPoint.dx - (toPoint.dx - lastWp.dx) * 0.1,
        toPoint.dy - (toPoint.dy - lastWp.dy) * 0.5,
      );
      const samples = 8;
      for (int t = 1; t <= samples; t++) {
        points.add(_cubicBezierPoint(lastWp, cp1, cp2, toPoint, t / samples));
      }
      return points;
    }

    @override
    Offset _cubicBezierPoint(
      Offset p0,
      Offset p1,
      Offset p2,
      Offset p3,
      double t,
    ) {
      final u = 1 - t;
      return Offset(
        u * u * u * p0.dx +
            3 * u * u * t * p1.dx +
            3 * u * t * t * p2.dx +
            t * t * t * p3.dx,
        u * u * u * p0.dy +
            3 * u * u * t * p1.dy +
            3 * u * t * t * p2.dy +
            t * t * t * p3.dy,
      );
    }

    (String, ConnectionSide, double)? _hitTestConnectionPoint(Offset worldPos) {
      final hitRadius = 10.0 / _scale;
      final gap = 8.0 / _scale;
      final spacing = 16.0 / _scale;
      final cards = ref.read(canvasProvider).cards;
      for (final card in cards.reversed) {
        if (card.type == CanvasCardType.freehand) continue;
        final w = card.width;
        final h = card.height;
        final topY = card.y - gap;
        final bottomY = card.y + h + gap;
        final leftX = card.x - gap;
        final rightX = card.x + w + gap;

        final topCount = (w / spacing).floor().clamp(2, 20);
        for (int i = 0; i <= topCount; i++) {
          final x = card.x + w * i / topCount;
          final dist = math.sqrt(
            math.pow(worldPos.dx - x, 2) + math.pow(worldPos.dy - topY, 2),
          );
          if (dist <= hitRadius) {
            return (card.id, ConnectionSide.top, i / topCount);
          }
        }

        final bottomCount = (w / spacing).floor().clamp(2, 20);
        for (int i = 0; i <= bottomCount; i++) {
          final x = card.x + w * i / bottomCount;
          final dist = math.sqrt(
            math.pow(worldPos.dx - x, 2) + math.pow(worldPos.dy - bottomY, 2),
          );
          if (dist <= hitRadius) {
            return (card.id, ConnectionSide.bottom, i / bottomCount);
          }
        }

        final leftCount = (h / spacing).floor().clamp(2, 20);
        for (int i = 1; i < leftCount; i++) {
          final y = card.y + h * i / leftCount;
          final dist = math.sqrt(
            math.pow(worldPos.dx - leftX, 2) + math.pow(worldPos.dy - y, 2),
          );
          if (dist <= hitRadius) {
            return (card.id, ConnectionSide.left, i / leftCount);
          }
        }

        final rightCount = (h / spacing).floor().clamp(2, 20);
        for (int i = 1; i < rightCount; i++) {
          final y = card.y + h * i / rightCount;
          final dist = math.sqrt(
            math.pow(worldPos.dx - rightX, 2) + math.pow(worldPos.dy - y, 2),
          );
          if (dist <= hitRadius) {
            return (card.id, ConnectionSide.right, i / rightCount);
          }
        }
      }
      return null;
    }

    (Offset, int) _snapWaypointToConnection(String connId, Offset worldPos) {
      final canvasData = ref.read(canvasProvider);
      final conn = canvasData.connections
          .where((c) => c.id == connId)
          .firstOrNull;
      if (conn == null) return (worldPos, 0);
      final from = ref.read(canvasProvider.notifier).cardById(conn.fromCardId);
      final to = ref.read(canvasProvider.notifier).cardById(conn.toCardId);
      if (from == null || to == null) return (worldPos, 0);
      final fromPoint = conn.fromSide.point(from.rect, conn.fromSideOffset);
      final toPoint = conn.toSide.point(to.rect, conn.toSideOffset);
      final style = conn.style ?? CanvasConnectionStyle.defaults;
      final sampledPoints = _connectionPathPoints(
        fromPoint,
        toPoint,
        conn.waypoints,
        style.pathType,
      );
      Offset? closest;
      double closestDist = double.infinity;
      for (int i = 0; i < sampledPoints.length - 1; i++) {
        final proj = _projectPointOnSegment(
          worldPos,
          sampledPoints[i],
          sampledPoints[i + 1],
        );
        final dist = (worldPos - proj).distance;
        if (dist < closestDist) {
          closestDist = dist;
          closest = proj;
        }
      }
      final originalPoints = [fromPoint, ...conn.waypoints, toPoint];
      int insertIndex = 0;
      double bestSegDist = double.infinity;
      for (int i = 0; i < originalPoints.length - 1; i++) {
        final dist = _pointToSegmentDist(
          worldPos,
          originalPoints[i],
          originalPoints[i + 1],
        );
        if (dist < bestSegDist) {
          bestSegDist = dist;
          insertIndex = i;
        }
      }
      return (closest ?? worldPos, insertIndex);
    }

    @override
    Offset _projectPointOnSegment(Offset p, Offset a, Offset b) {
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final lenSq = dx * dx + dy * dy;
      if (lenSq == 0) return a;
      var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
      t = t.clamp(0.0, 1.0);
      return Offset(a.dx + t * dx, a.dy + t * dy);
    }

    @override
    double _pointToSegmentDist(Offset p, Offset a, Offset b) {
      final proj = _projectPointOnSegment(p, a, b);
      return (p - proj).distance;
    }

    List<AlignmentGuide> _computeAlignmentGuides(
      CanvasCard draggedCard,
      List<CanvasCard> allCards,
    ) {
      if (_altKeyPressed) return [];
      final guides = <AlignmentGuide>[];
      final threshold = _CanvasViewStateBase._alignmentThreshold;
      final vr = Rect.fromLTWH(
        _cameraX - _viewW / 2 / _scale,
        _cameraY - _viewH / 2 / _scale,
        _viewW / _scale,
        _viewH / _scale,
      );

      for (final other in allCards) {
        if (other.id == draggedCard.id) continue;
        if (!vr.overlaps(other.rect.inflate(50))) continue;

        final dCenterX = (draggedCard.center.dx - other.center.dx).abs();
        if (dCenterX < threshold) {
          final x = other.center.dx;
          guides.add(
            AlignmentGuide(
              start: Offset(x, vr.top),
              end: Offset(x, vr.bottom),
              type: AlignmentGuideType.centerVertical,
            ),
          );
        }

        final dCenterY = (draggedCard.center.dy - other.center.dy).abs();
        if (dCenterY < threshold) {
          final y = other.center.dy;
          guides.add(
            AlignmentGuide(
              start: Offset(vr.left, y),
              end: Offset(vr.right, y),
              type: AlignmentGuideType.centerHorizontal,
            ),
          );
        }

        final dLeft = (draggedCard.x - other.x).abs();
        if (dLeft < threshold) {
          final x = other.x;
          guides.add(
            AlignmentGuide(
              start: Offset(x, vr.top),
              end: Offset(x, vr.bottom),
              type: AlignmentGuideType.leftEdge,
            ),
          );
        }

        final dRight =
            ((draggedCard.x + draggedCard.width) - (other.x + other.width)).abs();
        if (dRight < threshold) {
          final x = other.x + other.width;
          guides.add(
            AlignmentGuide(
              start: Offset(x, vr.top),
              end: Offset(x, vr.bottom),
              type: AlignmentGuideType.rightEdge,
            ),
          );
        }

        final dTop = (draggedCard.y - other.y).abs();
        if (dTop < threshold) {
          final y = other.y;
          guides.add(
            AlignmentGuide(
              start: Offset(vr.left, y),
              end: Offset(vr.right, y),
              type: AlignmentGuideType.topEdge,
            ),
          );
        }

        final dBottom =
            ((draggedCard.y + draggedCard.height) - (other.y + other.height))
                .abs();
        if (dBottom < threshold) {
          final y = other.y + other.height;
          guides.add(
            AlignmentGuide(
              start: Offset(vr.left, y),
              end: Offset(vr.right, y),
              type: AlignmentGuideType.bottomEdge,
            ),
          );
        }
      }
      return guides;
    }

    double? _getSnapOffset(CanvasCard draggedCard, List<CanvasCard> allCards) {
      if (_altKeyPressed) return null;
      final threshold = _CanvasViewStateBase._alignmentThreshold;
      for (final other in allCards) {
        if (other.id == draggedCard.id) continue;
        final dCenterX = (draggedCard.center.dx - other.center.dx).abs();
        if (dCenterX < threshold) {
          return other.center.dx - draggedCard.width / 2 - draggedCard.x;
        }
        final dLeft = (draggedCard.x - other.x).abs();
        if (dLeft < threshold) return other.x - draggedCard.x;
        final dRight =
            ((draggedCard.x + draggedCard.width) - (other.x + other.width)).abs();
        if (dRight < threshold) {
          return (other.x + other.width - draggedCard.width) - draggedCard.x;
        }
      }
      return null;
    }

    double? _getSnapOffsetY(CanvasCard draggedCard, List<CanvasCard> allCards) {
      if (_altKeyPressed) return null;
      final threshold = _CanvasViewStateBase._alignmentThreshold;
      for (final other in allCards) {
        if (other.id == draggedCard.id) continue;
        final dCenterY = (draggedCard.center.dy - other.center.dy).abs();
        if (dCenterY < threshold) {
          return other.center.dy - draggedCard.height / 2 - draggedCard.y;
        }
        final dTop = (draggedCard.y - other.y).abs();
        if (dTop < threshold) return other.y - draggedCard.y;
        final dBottom =
            ((draggedCard.y + draggedCard.height) - (other.y + other.height))
                .abs();
        if (dBottom < threshold) {
          return (other.y + other.height - draggedCard.height) - draggedCard.y;
        }
      }
      return null;
    }

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

    @override
    void _onPointerSignal(PointerSignalEvent event) {
      if (event is PointerScrollEvent) {
        final scrollDelta = event.scrollDelta.dy;
        final zoomFactor = scrollDelta < 0 ? 1.05 : 0.95;
        final newScale = (_scale * zoomFactor).clamp(_CanvasViewStateBase._minScale, _CanvasViewStateBase._maxScale);

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
      final newScale = (_scale * 1.2).clamp(_CanvasViewStateBase._minScale, _CanvasViewStateBase._maxScale);
      _scale = newScale;
      _cameraNotifier.notify();
    }

    @override
    void _zoomOut() {
      final newScale = (_scale / 1.2).clamp(_CanvasViewStateBase._minScale, _CanvasViewStateBase._maxScale);
      _scale = newScale;
      _cameraNotifier.notify();
    }

    @override
    void _zoomReset() {
      _scale = 1.0;
      _cameraNotifier.notify();
    }

    @override
    void _onSearchChanged(String query) {
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        final notifier = ref.read(canvasProvider.notifier);
        final matched = notifier.searchCards(query);
        setState(() {
          _searchQuery = query;
          _searchMatchedIds = matched.map((c) => c.id).toList();
          _searchActiveIndex = 0;
        });
      });
    }

    @override
    void _onSearchSubmit(String query) {
      final notifier = ref.read(canvasProvider.notifier);
      final matched = notifier.searchCards(query);
      setState(() {
        _searchQuery = query;
        _searchMatchedIds = matched.map((c) => c.id).toList();
        _searchActiveIndex = 0;
      });
      _panToFirstMatch();
    }

    @override
    void _clearSearch() {
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _searchMatchedIds = [];
        _searchActiveIndex = 0;
      });
    }

    @override
    void _toggleSearch() {
      setState(() {
        _searchVisible = !_searchVisible;
        if (!_searchVisible) {
          _clearSearch();
        }
      });
    }

    @override
    void _searchNext() {
      if (_searchMatchedIds.isEmpty) return;
      setState(() {
        _searchActiveIndex = (_searchActiveIndex + 1) % _searchMatchedIds.length;
      });
      _panToMatch(_searchActiveIndex);
    }

    @override
    void _searchPrev() {
      if (_searchMatchedIds.isEmpty) return;
      setState(() {
        _searchActiveIndex =
            (_searchActiveIndex - 1 + _searchMatchedIds.length) %
            _searchMatchedIds.length;
      });
      _panToMatch(_searchActiveIndex);
    }

    @override
    void _panToFirstMatch() => _panToMatch(0);

    @override
    void _panToMatch(int index) {
      if (index < 0 || index >= _searchMatchedIds.length) return;
      final cardId = _searchMatchedIds[index];
      final canvasData = ref.read(canvasProvider);
      final card = canvasData.cards.where((c) => c.id == cardId).firstOrNull;
      if (card == null) return;
      final targetScale = math
          .min(_viewW / (card.width + 200), _viewH / (card.height + 200))
          .clamp(0.1, 2.0);
      _cameraX = card.x + card.width / 2;
      _cameraY = card.y + card.height / 2;
      _scale = targetScale;
      _cameraNotifier.notify();
      ref.read(canvasProvider.notifier).selectCard(card.id);
    }

    @override
    void _deleteSelectedCards() {
      final selectedIds = _selectedCardIds;
      if (selectedIds.isEmpty) return;
      if (selectedIds.length == 1) {
        ref.read(canvasProvider.notifier).removeCard(selectedIds.first);
      } else {
        ref.read(canvasProvider.notifier).batchDeleteCards(selectedIds);
      }
      ref.read(canvasProvider.notifier).selectCard(null);
    }

    @override
    void _undo() => ref.read(canvasProvider.notifier).undo();
    @override
    void _redo() => ref.read(canvasProvider.notifier).redo();

    @override
    void _selectAll() => ref.read(canvasProvider.notifier).selectAll();

    @override
    void _groupSelected() {
      final ids = _selectedCardIds;
      if (ids.length < 2) return;
      ref.read(canvasProvider.notifier).groupCards(ids);
    }

    @override
    void _ungroupSelected() {
      final ids = _selectedCardIds;
      if (ids.isEmpty) return;
      final notifier = ref.read(canvasProvider.notifier);
      for (final id in ids) {
        final group = notifier.groupForCard(id);
        if (group != null) {
          notifier.ungroupCards(group.id);
          return;
        }
      }
    }

}

part of '../canvas_page.dart';

mixin _CanvasInputHitTestMixin on _CanvasViewStateBase {
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
    return (value / _CanvasViewStateBase._gridSize).round() *
        _CanvasViewStateBase._gridSize;
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

  @override
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

  @override
  CanvasCard? _hitTestCard(Offset worldPos) {
    final cards = ref.read(canvasProvider).cards;
    for (final card in cards.reversed) {
      if (card.rect.contains(worldPos)) return card;
    }
    return null;
  }

  @override
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

  @override
  (String, double)? _hitTestConnectionLine(Offset worldPos) {
    final canvasData = ref.read(canvasProvider);
    final notifier = ref.read(canvasProvider.notifier);
    final hitRadius = 12.0 / _scale;
    final hits = <(String, double)>[];
    final vr = _visibleWorldRect.inflate(50);
    for (final conn in canvasData.connections) {
      final from = notifier.cardById(conn.fromCardId);
      final to = notifier.cardById(conn.toCardId);
      if (from == null || to == null) continue;
      // Viewport culling: skip if both endpoints are far off-screen.
      if (!vr.overlaps(from.rect) && !vr.overlaps(to.rect)) continue;
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

  @override
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
  ) => CanvasGeometry.cubicBezierPoint(p0, p1, p2, p3, t);

  @override
  (String, ConnectionSide, double)? _hitTestConnectionPoint(Offset worldPos) {
    final hitRadius = 10.0 / _scale;
    final gap = 8.0 / _scale;
    final spacing = 16.0 / _scale;
    final cards = ref.read(canvasProvider).cards;
    final vr = _visibleWorldRect.inflate(16);
    final boundsPad = gap + hitRadius;
    final hitRadiusSq = hitRadius * hitRadius;
    for (final card in cards.reversed) {
      if (card.type == CanvasCardType.freehand) continue;
      // (a) Viewport cull — skip cards entirely off-screen.
      if (!vr.overlaps(card.rect)) continue;
      // (c) Cheap pre-filter before perimeter scan.
      if (!card.rect.inflate(boundsPad).contains(worldPos)) continue;
      final w = card.width;
      final h = card.height;
      final topY = card.y - gap;
      final bottomY = card.y + h + gap;
      final leftX = card.x - gap;
      final rightX = card.x + w + gap;

      final topCount = (w / spacing).floor().clamp(2, 20);
      for (int i = 0; i <= topCount; i++) {
        final x = card.x + w * i / topCount;
        final ddx = worldPos.dx - x;
        final ddy = worldPos.dy - topY;
        if (ddx * ddx + ddy * ddy <= hitRadiusSq) {
          return (card.id, ConnectionSide.top, i / topCount);
        }
      }

      final bottomCount = (w / spacing).floor().clamp(2, 20);
      for (int i = 0; i <= bottomCount; i++) {
        final x = card.x + w * i / bottomCount;
        final ddx = worldPos.dx - x;
        final ddy = worldPos.dy - bottomY;
        if (ddx * ddx + ddy * ddy <= hitRadiusSq) {
          return (card.id, ConnectionSide.bottom, i / bottomCount);
        }
      }

      final leftCount = (h / spacing).floor().clamp(2, 20);
      for (int i = 1; i < leftCount; i++) {
        final y = card.y + h * i / leftCount;
        final ddx = worldPos.dx - leftX;
        final ddy = worldPos.dy - y;
        if (ddx * ddx + ddy * ddy <= hitRadiusSq) {
          return (card.id, ConnectionSide.left, i / leftCount);
        }
      }

      final rightCount = (h / spacing).floor().clamp(2, 20);
      for (int i = 1; i < rightCount; i++) {
        final y = card.y + h * i / rightCount;
        final ddx = worldPos.dx - rightX;
        final ddy = worldPos.dy - y;
        if (ddx * ddx + ddy * ddy <= hitRadiusSq) {
          return (card.id, ConnectionSide.right, i / rightCount);
        }
      }
    }
    return null;
  }

  @override
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
  Offset _projectPointOnSegment(Offset p, Offset a, Offset b) =>
      CanvasGeometry.projectPointOnSegment(p, a, b);

  @override
  double _pointToSegmentDist(Offset p, Offset a, Offset b) =>
      CanvasGeometry.pointToSegmentDist(p, a, b);
}

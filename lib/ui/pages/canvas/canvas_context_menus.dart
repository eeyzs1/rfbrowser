part of '../canvas_page.dart';

mixin _CanvasContextMenusMixin on _CanvasViewStateBase {
  @override
  void _showWaypointContextMenu(
    Offset position,
    String connId,
    int waypointIndex,
  ) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(l.removeWaypoint),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'removeAll',
          child: Row(
            children: [
              Icon(Icons.clear, size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(l.removeAllWaypoints),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'remove':
          ref
              .read(canvasProvider.notifier)
              .removeWaypoint(connId, waypointIndex);
        case 'removeAll':
          final conn = ref
              .read(canvasProvider)
              .connections
              .where((c) => c.id == connId)
              .firstOrNull;
          if (conn != null) {
            ref
                .read(canvasProvider.notifier)
                .updateConnection(conn.copyWith(waypoints: []));
          }
      }
    });
  }

  @override
  void _showConnectionContextMenu(
    Offset position,
    String connId,
    Offset worldPos,
  ) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final conn = ref
        .read(canvasProvider)
        .connections
        .where((c) => c.id == connId)
        .firstOrNull;
    if (conn == null) return;
    final style = conn.style ?? CanvasConnectionStyle.defaults;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'straightPath',
          child: Row(
            children: [
              Icon(
                Icons.show_chart,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l.straight),
              if (style.pathType == ConnectionPath.straight) ...[
                const Spacer(),
                Icon(Icons.check, size: 14, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: 'curvedPath',
          child: Row(
            children: [
              Icon(Icons.waves, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(l.curved),
              if (style.pathType == ConnectionPath.curved) ...[
                const Spacer(),
                Icon(Icons.check, size: 14, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: 'orthoPath',
          child: Row(
            children: [
              Icon(
                Icons.turn_right,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l.orthogonal),
              if (style.pathType == ConnectionPath.orthogonal) ...[
                const Spacer(),
                Icon(Icons.check, size: 14, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'addWaypoint',
          child: Row(
            children: [
              Icon(
                Icons.add_location_alt,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l.addWaypoint),
            ],
          ),
        ),
        if (conn.waypoints.isNotEmpty) ...[
          if (_hitTestWaypoint(worldPos) != null)
            PopupMenuItem(
              value: 'clearWaypoint',
              child: Row(
                children: [
                  Icon(Icons.clear, size: 16, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text(l.clearWaypoint),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'clearAllWaypoints',
            child: Row(
              children: [
                Icon(Icons.clear_all, size: 16, color: theme.hintColor),
                const SizedBox(width: 8),
                Text(l.clearAllWaypoints),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(l.deleteConnection),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      final latestConn = ref
          .read(canvasProvider)
          .connections
          .where((c) => c.id == connId)
          .firstOrNull;
      if (latestConn == null) return;
      final currentStyle = latestConn.style ?? CanvasConnectionStyle.defaults;
      switch (value) {
        case 'straightPath':
          ref
              .read(canvasProvider.notifier)
              .updateConnection(
                latestConn.copyWith(
                  style: currentStyle.copyWith(
                    pathType: ConnectionPath.straight,
                  ),
                  clearStyle: false,
                ),
              );
        case 'curvedPath':
          ref
              .read(canvasProvider.notifier)
              .updateConnection(
                latestConn.copyWith(
                  style: currentStyle.copyWith(pathType: ConnectionPath.curved),
                  clearStyle: false,
                ),
              );
        case 'orthoPath':
          ref
              .read(canvasProvider.notifier)
              .updateConnection(
                latestConn.copyWith(
                  style: currentStyle.copyWith(
                    pathType: ConnectionPath.orthogonal,
                  ),
                  clearStyle: false,
                ),
              );
        case 'addWaypoint':
          final (snappedPos, insertIdx) = _snapWaypointToConnection(
            connId,
            worldPos,
          );
          ref
              .read(canvasProvider.notifier)
              .addWaypoint(connId, snappedPos, insertIndex: insertIdx);
        case 'clearWaypoint':
          final wpHit = _hitTestWaypoint(worldPos);
          if (wpHit != null) {
            ref
                .read(canvasProvider.notifier)
                .removeWaypoint(wpHit.$1, wpHit.$2);
          }
        case 'clearAllWaypoints':
          ref
              .read(canvasProvider.notifier)
              .updateConnection(latestConn.copyWith(waypoints: []));
        case 'delete':
          ref.read(canvasProvider.notifier).removeConnection(connId);
          ref.read(canvasProvider.notifier).selectConnection(null);
      }
    });
  }
}

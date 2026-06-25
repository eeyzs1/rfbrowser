part of '../canvas_page.dart';

/// Connection-related dialogs: manage connections list, edit connection
/// style, and create new connections.
mixin _CanvasDialogsConnectionsMixin on _CanvasViewStateBase {
  @override
  void _showConnectionListDialog(
    CanvasCard card,
    List<({CanvasConnection conn, bool isAuto})> allConns,
  ) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.manageConnections),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allConns.length,
            itemBuilder: (ctx, i) {
              final e = allConns[i];
              final otherCardId = e.conn.fromCardId == card.id
                  ? e.conn.toCardId
                  : e.conn.fromCardId;
              final otherCard = ref
                  .read(canvasProvider.notifier)
                  .cardById(otherCardId);
              final connStyle = e.conn.style ?? CanvasConnectionStyle.defaults;
              return ListTile(
                dense: true,
                leading: Icon(
                  e.isAuto ? Icons.auto_fix_high : Icons.link,
                  size: 16,
                  color: e.isAuto ? theme.hintColor : theme.colorScheme.primary,
                ),
                title: Text(
                  otherCard?.title ?? otherCardId,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  e.conn.label.isNotEmpty
                      ? e.conn.label
                      : (e.isAuto
                            ? l.autoConnection
                            : '${connStyle.pathType.name} · ${connStyle.arrowStyle.name}'),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!e.isAuto)
                      IconButton(
                        icon: Icon(
                          Icons.tune,
                          size: 14,
                          color: theme.hintColor,
                        ),
                        tooltip: l.editStyle,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showConnectionStyleDialog(e.conn);
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () {
                        if (e.isAuto) {
                          ref
                              .read(canvasProvider.notifier)
                              .addConnection(e.conn.copyWith(isAuto: false));
                        } else {
                          ref
                              .read(canvasProvider.notifier)
                              .removeConnection(e.conn.id);
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              for (final e in allConns) {
                try {
                  ref.read(canvasProvider.notifier).removeConnection(e.conn.id);
                } catch (_) {
                  appLog.error('Canvas: failed to remove connection');
                }
              }
              Navigator.pop(ctx);
            },
            child: Text(
              l.deleteAll,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
        ],
      ),
    );
  }

  @override
  void _showConnectionStyleDialog(CanvasConnection conn) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final currentStyle = conn.style ?? CanvasConnectionStyle.defaults;
    ConnectionPath pathType = currentStyle.pathType;
    ArrowStyle arrowStyle = currentStyle.arrowStyle;
    double strokeWidth = currentStyle.strokeWidth;
    int colorValue = currentStyle.colorValue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.connectionStyle),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ConnectionPath>(
                  // ignore: deprecated_member_use
                  value: pathType,
                  key: ValueKey(pathType),
                  decoration: InputDecoration(
                    labelText: l.pathType,
                    isDense: true,
                  ),
                  items: ConnectionPath.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => pathType = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ArrowStyle>(
                  // ignore: deprecated_member_use
                  value: arrowStyle,
                  key: ValueKey(arrowStyle),
                  decoration: InputDecoration(
                    labelText: l.arrowStyle,
                    isDense: true,
                  ),
                  items: ArrowStyle.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => arrowStyle = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l.width, style: theme.textTheme.bodySmall),
                    Expanded(
                      child: Slider(
                        value: strokeWidth,
                        min: 0.5,
                        max: 6,
                        divisions: 11,
                        label: strokeWidth.toStringAsFixed(1),
                        onChanged: (v) => setDialogState(() => strokeWidth = v),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        strokeWidth.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: colorValue,
                  key: ValueKey(colorValue),
                  decoration: InputDecoration(
                    labelText: l.color,
                    isDense: true,
                  ),
                  items:
                      [
                            0xFF000000,
                            0xFF1565C0,
                            0xFF2E7D32,
                            0xFFE65100,
                            0xFFC62828,
                            0xFF6A1B9A,
                            0xFF00838F,
                            0xFF4E342E,
                          ]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(v),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '#${v.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => colorValue = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(canvasProvider.notifier)
                    .addConnection(
                      conn.copyWith(
                        style: CanvasConnectionStyle(
                          pathType: pathType,
                          arrowStyle: arrowStyle,
                          strokeWidth: strokeWidth,
                          colorValue: colorValue,
                        ),
                        clearStyle: false,
                      ),
                    );
                ref.read(canvasProvider.notifier).removeConnection(conn.id);
                Navigator.pop(ctx);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void _createConnection(String fromId, String toId) {
    final fromCard = ref.read(canvasProvider.notifier).cardById(fromId);
    final toCard = ref.read(canvasProvider.notifier).cardById(toId);
    if (fromCard == null || toCard == null) return;
    final (fromSide, toSide) = CanvasConnection.computeSides(fromCard, toCard);
    final conn = CanvasConnection(
      id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
      fromCardId: fromId,
      toCardId: toId,
      fromSide: fromSide,
      toSide: toSide,
      fromSideOffset: 0.5,
      toSideOffset: 0.5,
      isAuto: false,
    );
    ref.read(canvasProvider.notifier).addConnection(conn);
  }

  @override
  void _createConnectionWithSides(
    String fromId,
    String toId,
    ConnectionSide? fromSide,
    ConnectionSide? toSide, [
    double fromSideOffset = 0.5,
    double toSideOffset = 0.5,
  ]) {
    final fromCard = ref.read(canvasProvider.notifier).cardById(fromId);
    final toCard = ref.read(canvasProvider.notifier).cardById(toId);
    if (fromCard == null || toCard == null) return;
    final (computedFrom, computedTo) = CanvasConnection.computeSides(
      fromCard,
      toCard,
    );
    final conn = CanvasConnection(
      id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
      fromCardId: fromId,
      toCardId: toId,
      fromSide: fromSide ?? computedFrom,
      toSide: toSide ?? computedTo,
      fromSideOffset: fromSideOffset,
      toSideOffset: toSideOffset,
      isAuto: false,
    );
    ref.read(canvasProvider.notifier).addConnection(conn);
    ref.read(canvasProvider.notifier).selectConnection(conn.id);
  }
}

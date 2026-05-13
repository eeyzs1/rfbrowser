part of '../canvas_page.dart';

mixin CanvasContextMenusMixin on _CanvasViewStateBase {
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
    void _showContextMenu(
      BuildContext context,
      TapUpDetails details,
      CanvasData canvasData,
      Offset worldPos,
    ) {
      final l = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.globalPosition.dx + 1,
          details.globalPosition.dy + 1,
        ),
        items: [
          PopupMenuItem(
            value: 'note',
            child: Row(
              children: [
                Icon(
                  Icons.description,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l.noteCard),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'text',
            child: Row(
              children: [
                Icon(
                  Icons.text_fields,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l.textCard),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'image',
            child: Row(
              children: [
                Icon(Icons.image, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.imageCard),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'link',
            child: Row(
              children: [
                Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.linkCard),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'container',
            child: Row(
              children: [
                Icon(
                  Icons.crop_square,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l.container),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'fromNote',
            child: Row(
              children: [
                Icon(
                  Icons.library_books,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l.fromKnowledgeNote),
              ],
            ),
          ),
          if (canvasData.selectedCardIds.isNotEmpty) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l.editCard),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'duplicate',
              child: Row(
                children: [
                  Icon(
                    Icons.content_copy,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(l.duplicateCard),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(l.deleteCard),
                ],
              ),
            ),
          ],
        ],
      ).then((value) {
        if (value == null) return;
        switch (value) {
          case 'note':
            _addCardAt(worldPos, type: CanvasCardType.note);
          case 'text':
            _addCardAt(worldPos, type: CanvasCardType.text);
          case 'image':
            _addCardAt(worldPos, type: CanvasCardType.image);
          case 'link':
            _addCardAt(worldPos, type: CanvasCardType.link);
          case 'container':
            _addContainerAt(worldPos);
          case 'fromNote':
            _addCardFromNote(worldPos);
          case 'edit':
            if (canvasData.selectedCardIds.isNotEmpty) {
              _startInlineEditing(canvasData.selectedCardIds.first);
            }
          case 'duplicate':
            if (canvasData.selectedCardIds.isNotEmpty) {
              _duplicateCard(canvasData.selectedCardIds.first, worldPos);
            }
          case 'delete':
            _deleteSelectedCards();
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

    @override
    void _showCardContextMenu(Offset position, CanvasCard card) {
      final l = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final canvasData = ref.read(canvasProvider);
      final connections = canvasData.connections
          .where((c) => c.fromCardId == card.id || c.toCardId == card.id)
          .toList();
      final linkResolver = ref.read(linkResolverProvider);
      final knowledgeState = ref.read(knowledgeProvider);
      final autoConns = ref
          .read(canvasProvider.notifier)
          .deriveAutoConnections(knowledgeState.notes, linkResolver);
      final autoConnections = autoConns
          .where((c) => c.fromCardId == card.id || c.toCardId == card.id)
          .toList();
      final allConns = [
        ...connections.map((c) => (conn: c, isAuto: c.isAuto)),
        ...autoConnections.map((c) => (conn: c, isAuto: true)),
      ];
      final isInGroup =
          ref.read(canvasProvider.notifier).groupForCard(card.id) != null;
      final selectedCount = canvasData.selectedCardIds.length;

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
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.editCard),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(
                  Icons.content_copy,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l.duplicateCard),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'color',
            child: Row(
              children: [
                Icon(Icons.palette, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.changeColor),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'copyStyle',
            child: Row(
              children: [
                Icon(
                  Icons.format_paint,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l.copyStyle),
              ],
            ),
          ),
          if (_copiedStyle != null)
            PopupMenuItem(
              value: 'pasteStyle',
              child: Row(
                children: [
                  Icon(
                    Icons.content_paste,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(l.pasteStyle),
                ],
              ),
            ),
          if (card.type == CanvasCardType.container)
            PopupMenuItem(
              value: 'toggleCollapse',
              child: Row(
                children: [
                  Icon(
                    card.collapsed ? Icons.unfold_more : Icons.unfold_less,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(card.collapsed ? l.expand : l.collapse),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'saveToScratchpad',
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l.saveToScratchpad),
              ],
            ),
          ),
          if (card.noteId == null)
            PopupMenuItem(
              value: 'promoteToNote',
              child: Row(
                children: [
                  Icon(
                    Icons.upload,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(l.promoteToNote),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'addTag',
            child: Row(
              children: [
                Icon(Icons.label, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.addTag),
              ],
            ),
          ),
          if (card.tags.isNotEmpty)
            PopupMenuItem(
              value: 'removeTag',
              child: Row(
                children: [
                  Icon(Icons.label_off, size: 16, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text(l.removeTag),
                ],
              ),
            ),
          if (canvasData.layers.isNotEmpty)
            PopupMenuItem(
              value: 'moveToLayer',
              child: Row(
                children: [
                  Icon(Icons.layers, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l.moveToLayer),
                ],
              ),
            ),
          const PopupMenuDivider(),
          if (selectedCount >= 2)
            PopupMenuItem(
              value: 'group',
              child: Row(
                children: [
                  Icon(
                    Icons.group_work,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(l.groupSelection),
                ],
              ),
            ),
          if (isInGroup)
            PopupMenuItem(
              value: 'ungroup',
              child: Row(
                children: [
                  Icon(Icons.group_remove, size: 16, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text(l.ungroup),
                ],
              ),
            ),
          if (selectedCount >= 2) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'alignLeft',
              child: Row(
                children: [
                  Icon(
                    Icons.align_horizontal_left,
                    size: 16,
                    color: theme.hintColor,
                  ),
                  const SizedBox(width: 8),
                  Text(l.alignLeft),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'alignCenterH',
              child: Row(
                children: [
                  Icon(
                    Icons.align_horizontal_center,
                    size: 16,
                    color: theme.hintColor,
                  ),
                  const SizedBox(width: 8),
                  Text(l.alignCenterH),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'alignRight',
              child: Row(
                children: [
                  Icon(
                    Icons.align_horizontal_right,
                    size: 16,
                    color: theme.hintColor,
                  ),
                  const SizedBox(width: 8),
                  Text(l.alignRight),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'alignTop',
              child: Row(
                children: [
                  Icon(
                    Icons.align_vertical_top,
                    size: 16,
                    color: theme.hintColor,
                  ),
                  const SizedBox(width: 8),
                  Text(l.alignTop),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'alignCenterV',
              child: Row(
                children: [
                  Icon(
                    Icons.align_vertical_center,
                    size: 16,
                    color: theme.hintColor,
                  ),
                  const SizedBox(width: 8),
                  Text(l.alignCenterV),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'alignBottom',
              child: Row(
                children: [
                  Icon(
                    Icons.align_vertical_bottom,
                    size: 16,
                    color: theme.hintColor,
                  ),
                  const SizedBox(width: 8),
                  Text(l.alignBottom),
                ],
              ),
            ),
            if (selectedCount >= 3) ...[
              PopupMenuItem(
                value: 'distributeH',
                child: Row(
                  children: [
                    Icon(Icons.space_bar, size: 16, color: theme.hintColor),
                    const SizedBox(width: 8),
                    Text(l.distributeH),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'distributeV',
                child: Row(
                  children: [
                    Icon(Icons.view_headline, size: 16, color: theme.hintColor),
                    const SizedBox(width: 8),
                    Text(l.distributeV),
                  ],
                ),
              ),
            ],
          ],
          if (allConns.isNotEmpty) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'manageConns',
              child: Row(
                children: [
                  Icon(Icons.settings_ethernet, size: 16, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text(l.manageConnections),
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
                Text(l.deleteCard),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (value == null) return;
        final notifier = ref.read(canvasProvider.notifier);
        final ids = canvasData.selectedCardIds;
        switch (value) {
          case 'edit':
            _editCard(card.id);
          case 'duplicate':
            _duplicateCard(card.id, Offset(card.x + 40, card.y + 40));
          case 'color':
            _showColorPicker(card);
          case 'copyStyle':
            setState(() {
              _copiedStyle = card.style ?? CanvasCardStyle.defaults;
            });
          case 'pasteStyle':
            if (_copiedStyle != null) {
              notifier.updateCard(card.copyWith(style: _copiedStyle));
            }
          case 'toggleCollapse':
            _toggleContainerCollapse(card.id);
          case 'saveToScratchpad':
            _saveCardToScratchpad(card);
          case 'promoteToNote':
            _promoteCardToNote(card);
          case 'moveToLayer':
            _showMoveToLayerDialog(card);
          case 'addTag':
            _showAddTagDialog(card);
          case 'removeTag':
            _showRemoveTagDialog(card);
          case 'manageConns':
            _showConnectionListDialog(card, allConns);
          case 'group':
            notifier.groupCards(ids);
          case 'ungroup':
            _ungroupSelected();
          case 'alignLeft':
            notifier.alignCards(ids, AlignmentType.left);
          case 'alignCenterH':
            notifier.alignCards(ids, AlignmentType.centerH);
          case 'alignRight':
            notifier.alignCards(ids, AlignmentType.right);
          case 'alignTop':
            notifier.alignCards(ids, AlignmentType.top);
          case 'alignCenterV':
            notifier.alignCards(ids, AlignmentType.centerV);
          case 'alignBottom':
            notifier.alignCards(ids, AlignmentType.bottom);
          case 'distributeH':
            notifier.distributeCards(ids, DistributeType.horizontal);
          case 'distributeV':
            notifier.distributeCards(ids, DistributeType.vertical);
          case 'delete':
            _deleteSelectedCards();
        }
      });
    }


}

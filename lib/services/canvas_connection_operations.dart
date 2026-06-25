part of 'canvas_service.dart';

/// Connection CRUD, waypoints, auto-connections, and card search.
mixin CanvasConnectionOperations on CanvasNotifierBase {
  Future<void> addConnection(CanvasConnection conn) async {
    await _mutateAndPersist(
      () => state.copyWith(connections: [...state.connections, conn]),
    );
  }

  Future<void> removeConnection(String connId) async {
    await _mutateAndPersist(
      () => state.copyWith(
        connections: state.connections.where((c) => c.id != connId).toList(),
      ),
    );
  }

  void updateConnection(CanvasConnection conn) {
    _mutateAndDebounce(() {
      final conns = state.connections
          .map((c) => c.id == conn.id ? conn : c)
          .toList();
      return state.copyWith(connections: conns);
    });
  }

  void addWaypoint(String connId, Offset position, {int? insertIndex}) {
    final conns = state.connections.map((c) {
      if (c.id == connId) {
        if (insertIndex != null &&
            insertIndex >= 0 &&
            insertIndex <= c.waypoints.length) {
          final newWaypoints = List<Offset>.from(c.waypoints)
            ..insert(insertIndex, position);
          return c.copyWith(waypoints: newWaypoints);
        }
        return c.copyWith(waypoints: [...c.waypoints, position]);
      }
      return c;
    }).toList();
    state = state.copyWith(connections: conns);
    _debouncedSave();
  }

  void removeWaypoint(String connId, int index) {
    final conns = state.connections.map((c) {
      if (c.id == connId && index >= 0 && index < c.waypoints.length) {
        final newWaypoints = List<Offset>.from(c.waypoints)..removeAt(index);
        return c.copyWith(waypoints: newWaypoints);
      }
      return c;
    }).toList();
    state = state.copyWith(connections: conns);
    _debouncedSave();
  }

  void moveWaypoint(String connId, int index, Offset newPosition) {
    final conns = state.connections.map((c) {
      if (c.id == connId && index >= 0 && index < c.waypoints.length) {
        final newWaypoints = List<Offset>.from(c.waypoints);
        newWaypoints[index] = newPosition;
        return c.copyWith(waypoints: newWaypoints);
      }
      return c;
    }).toList();
    state = state.copyWith(connections: conns);
    _debouncedSave();
  }

  List<CanvasConnection> deriveAutoConnections(
    List<Note> notes,
    LinkResolver? linkResolver,
  ) {
    if (!autoConnectionsEnabled) return [];
    if (linkResolver == null) return [];

    final cardsWithNoteIds = state.cards
        .where((c) => c.noteId != null)
        .toList();
    if (cardsWithNoteIds.length < 2) return [];

    final noteMap = <String, Note>{};
    for (final note in notes) {
      noteMap[note.id] = note;
    }

    final autoConns = <CanvasConnection>[];

    for (int i = 0; i < cardsWithNoteIds.length; i++) {
      for (int j = 0; j < cardsWithNoteIds.length; j++) {
        if (i == j) continue;
        final cardA = cardsWithNoteIds[i];
        final cardB = cardsWithNoteIds[j];
        final noteA = noteMap[cardA.noteId];
        final noteB = noteMap[cardB.noteId];
        if (noteA == null || noteB == null) continue;

        final extractedLinks = linkResolver.extractLinksFromContent(
          noteA.content,
        );
        final hasLink = extractedLinks.any((link) {
          final resolvedPath = linkResolver.resolveTitleToPath(link.target);
          if (resolvedPath == null) return false;
          final targetId = resolvedPath
              .replaceAll(RegExp(r'[/\\]'), '_')
              .replaceAll('.md', '');
          return targetId == noteB.id;
        });

        if (hasLink) {
          final (fromSide, toSide) = CanvasConnection.computeSides(
            cardA,
            cardB,
          );

          autoConns.add(
            CanvasConnection(
              id: 'auto_${cardA.id}_${cardB.id}',
              fromCardId: cardA.id,
              toCardId: cardB.id,
              fromSide: fromSide,
              toSide: toSide,
              isAuto: true,
            ),
          );
        }
      }
    }

    final manualPairs = <String>{};
    for (final conn in state.connections) {
      if (!conn.isAuto) {
        manualPairs.add('${conn.fromCardId}->${conn.toCardId}');
      }
    }

    return autoConns.where((c) {
      final key = '${c.fromCardId}->${c.toCardId}';
      return !manualPairs.contains(key);
    }).toList();
  }

  List<CanvasCard> searchCards(String query) {
    if (query.isEmpty) return state.cards.toList();
    final lower = query.toLowerCase();
    return state.cards
        .where(
          (c) =>
              c.title.toLowerCase().contains(lower) ||
              c.content.toLowerCase().contains(lower),
        )
        .toList();
  }
}

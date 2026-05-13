part of '../canvas_service.dart';

mixin CanvasLayoutMixin on _CanvasNotifierBase {
    @override
    void autoLayout(AutoLayoutType type) {
      if (state.cards.isEmpty) return;
      _pushUndo();
      final newCards = List<CanvasCard>.from(state.cards);
      switch (type) {
        case AutoLayoutType.forceDirected:
          _forceDirectedLayout(newCards);
        case AutoLayoutType.hierarchical:
          _hierarchicalLayout(newCards);
        case AutoLayoutType.grid:
          _gridLayout(newCards);
      }
      state = state.copyWith(cards: newCards);
      _debouncedSave();
    }

    @override
    void _forceDirectedLayout(List<CanvasCard> cards) {
      final n = cards.length;
      if (n == 0) return;
      final positions = <String, (double, double)>{};
      for (int i = 0; i < n; i++) {
        final angle = 2 * 3.14159265 * i / n;
        final radius = 200.0 * (n > 1 ? 1 : 0);
        positions[cards[i].id] = (
          radius * (1 + angle / 6.28) * 2 - radius,
          radius * (1 + (angle * 0.5).abs()),
        );
      }
      for (int iter = 0; iter < 50; iter++) {
        final forces = <String, (double, double)>{};
        for (final card in cards) {
          forces[card.id] = (0.0, 0.0);
        }
        for (int i = 0; i < n; i++) {
          for (int j = i + 1; j < n; j++) {
            final a = cards[i];
            final b = cards[j];
            final posA = positions[a.id]!;
            final posB = positions[b.id]!;
            final dx = posB.$1 - posA.$1;
            final dy = posB.$2 - posA.$2;
            final dist = (dx * dx + dy * dy).toDouble().clamp(
              1.0,
              double.infinity,
            );
            final repulsion = 50000.0 / dist;
            final fx = dx / math.sqrt(dist) * repulsion;
            final fy = dy / math.sqrt(dist) * repulsion;
            forces[a.id] = (forces[a.id]!.$1 - fx, forces[a.id]!.$2 - fy);
            forces[b.id] = (forces[b.id]!.$1 + fx, forces[b.id]!.$2 + fy);
          }
        }
        for (final conn in state.connections) {
          final posA = positions[conn.fromCardId];
          final posB = positions[conn.toCardId];
          if (posA == null || posB == null) continue;
          final dx = posB.$1 - posA.$1;
          final dy = posB.$2 - posA.$2;
          final dist = (dx * dx + dy * dy).toDouble().clamp(1.0, double.infinity);
          final attraction = dist * 0.01;
          final fx = dx / math.sqrt(dist) * attraction;
          final fy = dy / math.sqrt(dist) * attraction;
          forces[conn.fromCardId] = (
            forces[conn.fromCardId]!.$1 + fx,
            forces[conn.fromCardId]!.$2 + fy,
          );
          forces[conn.toCardId] = (
            forces[conn.toCardId]!.$1 - fx,
            forces[conn.toCardId]!.$2 - fy,
          );
        }
        for (final card in cards) {
          final f = forces[card.id]!;
          final pos = positions[card.id]!;
          final maxMove = 20.0;
          final fx = f.$1.clamp(-maxMove, maxMove);
          final fy = f.$2.clamp(-maxMove, maxMove);
          positions[card.id] = (pos.$1 + fx, pos.$2 + fy);
        }
      }
      for (int i = 0; i < cards.length; i++) {
        final pos = positions[cards[i].id]!;
        cards[i] = cards[i].copyWith(
          x: _snapToGrid(pos.$1),
          y: _snapToGrid(pos.$2),
        );
      }
    }

    @override
    void _hierarchicalLayout(List<CanvasCard> cards) {
      final cardMap = <String, CanvasCard>{};
      for (final c in cards) {
        cardMap[c.id] = c;
      }
      final hasIncoming = <String, int>{};
      for (final c in cards) {
        hasIncoming[c.id] = 0;
      }
      for (final conn in state.connections) {
        if (hasIncoming.containsKey(conn.toCardId)) {
          hasIncoming[conn.toCardId] = hasIncoming[conn.toCardId]! + 1;
        }
      }
      final levels = <String, int>{};
      final visited = <String>{};
      void assignLevel(String id, int level) {
        if (visited.contains(id)) return;
        visited.add(id);
        levels[id] = level;
        for (final conn in state.connections) {
          if (conn.fromCardId == id && cardMap.containsKey(conn.toCardId)) {
            assignLevel(conn.toCardId, level + 1);
          }
        }
      }

      for (final c in cards) {
        if (hasIncoming[c.id] == 0) assignLevel(c.id, 0);
      }
      for (final c in cards) {
        if (!levels.containsKey(c.id)) levels[c.id] = 0;
      }
      final maxLevel = levels.values.fold(0, (a, b) => a > b ? a : b);
      final byLevel = <int, List<String>>{};
      for (final entry in levels.entries) {
        byLevel.putIfAbsent(entry.value, () => []).add(entry.key);
      }
      for (int level = 0; level <= maxLevel; level++) {
        final ids = byLevel[level] ?? [];
        for (int i = 0; i < ids.length; i++) {
          final card = cardMap[ids[i]]!;
          final idx = cards.indexWhere((c) => c.id == ids[i]);
          if (idx >= 0) {
            cards[idx] = card.copyWith(
              x: _snapToGrid(200.0 + i * 300.0),
              y: _snapToGrid(200.0 + level * 200.0),
            );
          }
        }
      }
    }

    @override
    void _gridLayout(List<CanvasCard> cards) {
      final n = cards.length;
      final cols = math.sqrt(n).ceil();
      for (int i = 0; i < n; i++) {
        final row = i ~/ cols;
        final col = i % cols;
        cards[i] = cards[i].copyWith(
          x: _snapToGrid(100.0 + col * 300.0),
          y: _snapToGrid(100.0 + row * 220.0),
        );
      }
    }

    @override
    double _snapToGrid(double value) {
      if (!state.settings.snapToGrid) return value;
      return (value / 20).roundToDouble() * 20.0;
    }

    // === Export ===

}

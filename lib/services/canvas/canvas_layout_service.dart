import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/canvas_model.dart';

class CanvasLayoutService {
  const CanvasLayoutService();

  Map<String, Offset> computeLayout(
    List<CanvasCard> cards,
    List<CanvasConnection> connections,
    AutoLayoutType type, {
    bool snapToGrid = true,
  }) {
    switch (type) {
      case AutoLayoutType.forceDirected:
        return _computeForceDirected(
          cards,
          connections,
          snapToGrid: snapToGrid,
        );
      case AutoLayoutType.hierarchical:
        return _computeHierarchical(cards, connections, snapToGrid: snapToGrid);
      case AutoLayoutType.grid:
        return _computeGrid(cards, snapToGrid: snapToGrid);
    }
  }

  double snapToGrid(double value) {
    return (value / 20).roundToDouble() * 20.0;
  }

  Map<String, Offset> _computeForceDirected(
    List<CanvasCard> cards,
    List<CanvasConnection> connections, {
    bool snapToGrid = true,
  }) {
    final n = cards.length;
    if (n == 0) return {};
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
      for (final conn in connections) {
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
    final result = <String, Offset>{};
    for (final card in cards) {
      final pos = positions[card.id]!;
      final x = snapToGrid ? this.snapToGrid(pos.$1) : pos.$1;
      final y = snapToGrid ? this.snapToGrid(pos.$2) : pos.$2;
      result[card.id] = Offset(x, y);
    }
    return result;
  }

  Map<String, Offset> _computeHierarchical(
    List<CanvasCard> cards,
    List<CanvasConnection> connections, {
    bool snapToGrid = true,
  }) {
    if (cards.isEmpty) return {};
    final cardMap = <String, CanvasCard>{};
    for (final c in cards) {
      cardMap[c.id] = c;
    }
    final hasIncoming = <String, int>{};
    for (final c in cards) {
      hasIncoming[c.id] = 0;
    }
    for (final conn in connections) {
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
      for (final conn in connections) {
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
    final result = <String, Offset>{};
    for (int level = 0; level <= maxLevel; level++) {
      final ids = byLevel[level] ?? [];
      for (int i = 0; i < ids.length; i++) {
        final x = snapToGrid
            ? this.snapToGrid(200.0 + i * 300.0)
            : 200.0 + i * 300.0;
        final y = snapToGrid
            ? this.snapToGrid(200.0 + level * 200.0)
            : 200.0 + level * 200.0;
        result[ids[i]] = Offset(x, y);
      }
    }
    return result;
  }

  Map<String, Offset> _computeGrid(
    List<CanvasCard> cards, {
    bool snapToGrid = true,
  }) {
    final n = cards.length;
    if (n == 0) return {};
    final cols = math.sqrt(n).ceil();
    final result = <String, Offset>{};
    for (int i = 0; i < n; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final x = snapToGrid
          ? this.snapToGrid(100.0 + col * 300.0)
          : 100.0 + col * 300.0;
      final y = snapToGrid
          ? this.snapToGrid(100.0 + row * 220.0)
          : 100.0 + row * 220.0;
      result[cards[i].id] = Offset(x, y);
    }
    return result;
  }

  // ─── Alignment ──────────────────────────────────────────────────────

  /// Returns a new card list with the specified [cardIds] aligned to [type].
  ///
  /// Pure function: does not mutate [cards]. Cards not in [cardIds] are
  /// returned unchanged.
  List<CanvasCard> alignCards(
    List<CanvasCard> cards,
    List<String> cardIds,
    AlignmentType type,
  ) {
    if (cardIds.length < 2) return cards;
    final selected = cards.where((c) => cardIds.contains(c.id)).toList();
    if (selected.isEmpty) return cards;

    final result = List<CanvasCard>.from(cards);
    switch (type) {
      case AlignmentType.left:
        final minX = selected.map((c) => c.x).reduce((a, b) => a < b ? a : b);
        for (int i = 0; i < result.length; i++) {
          if (cardIds.contains(result[i].id)) {
            result[i] = result[i].copyWith(x: minX);
          }
        }
      case AlignmentType.centerH:
        final avgCenterX =
            selected.map((c) => c.center.dx).reduce((a, b) => a + b) /
            selected.length;
        for (int i = 0; i < result.length; i++) {
          if (cardIds.contains(result[i].id)) {
            result[i] = result[i].copyWith(
              x: avgCenterX - result[i].width / 2,
            );
          }
        }
      case AlignmentType.right:
        final maxRight = selected
            .map((c) => c.x + c.width)
            .reduce((a, b) => a > b ? a : b);
        for (int i = 0; i < result.length; i++) {
          if (cardIds.contains(result[i].id)) {
            result[i] = result[i].copyWith(x: maxRight - result[i].width);
          }
        }
      case AlignmentType.top:
        final minY = selected.map((c) => c.y).reduce((a, b) => a < b ? a : b);
        for (int i = 0; i < result.length; i++) {
          if (cardIds.contains(result[i].id)) {
            result[i] = result[i].copyWith(y: minY);
          }
        }
      case AlignmentType.centerV:
        final avgCenterY =
            selected.map((c) => c.center.dy).reduce((a, b) => a + b) /
            selected.length;
        for (int i = 0; i < result.length; i++) {
          if (cardIds.contains(result[i].id)) {
            result[i] = result[i].copyWith(
              y: avgCenterY - result[i].height / 2,
            );
          }
        }
      case AlignmentType.bottom:
        final maxBottom = selected
            .map((c) => c.y + c.height)
            .reduce((a, b) => a > b ? a : b);
        for (int i = 0; i < result.length; i++) {
          if (cardIds.contains(result[i].id)) {
            result[i] = result[i].copyWith(y: maxBottom - result[i].height);
          }
        }
    }
    return result;
  }

  // ─── Distribution ───────────────────────────────────────────────────

  /// Returns a new card list with the specified [cardIds] evenly distributed
  /// along [type] axis.
  ///
  /// Pure function: does not mutate [cards]. Requires at least 3 selected
  /// cards to have an effect.
  List<CanvasCard> distributeCards(
    List<CanvasCard> cards,
    List<String> cardIds,
    DistributeType type,
  ) {
    if (cardIds.length < 3) return cards;
    final selected = cards.where((c) => cardIds.contains(c.id)).toList();
    if (selected.length < 3) return cards;

    final result = List<CanvasCard>.from(cards);
    switch (type) {
      case DistributeType.horizontal:
        final sorted = List<CanvasCard>.from(selected)
          ..sort((a, b) => a.x.compareTo(b.x));
        final minX = sorted.first.x;
        final maxX = sorted.last.x;
        final totalWidth = sorted.fold(0.0, (sum, c) => sum + c.width);
        final totalGap = maxX - minX - totalWidth;
        final gapCount = sorted.length - 1;
        final gap = gapCount > 0 ? totalGap / gapCount : 0.0;
        double currentX = minX;
        for (final card in sorted) {
          final idx = result.indexWhere((c) => c.id == card.id);
          if (idx >= 0) {
            result[idx] = result[idx].copyWith(x: currentX);
            currentX += result[idx].width + gap;
          }
        }
      case DistributeType.vertical:
        final sorted = List<CanvasCard>.from(selected)
          ..sort((a, b) => a.y.compareTo(b.y));
        final minY = sorted.first.y;
        final maxY = sorted.last.y;
        final totalHeight = sorted.fold(0.0, (sum, c) => sum + c.height);
        final totalGap = maxY - minY - totalHeight;
        final gapCount = sorted.length - 1;
        final gap = gapCount > 0 ? totalGap / gapCount : 0.0;
        double currentY = minY;
        for (final card in sorted) {
          final idx = result.indexWhere((c) => c.id == card.id);
          if (idx >= 0) {
            result[idx] = result[idx].copyWith(y: currentY);
            currentY += result[idx].height + gap;
          }
        }
    }
    return result;
  }
}

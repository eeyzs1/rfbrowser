import 'dart:math';
import 'package:flutter/material.dart' show Offset;

class LayoutNode {
  final String id;
  double x;
  double y;
  double vx;
  double vy;

  LayoutNode({
    required this.id,
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
  });
}

class LayoutEdge {
  final String sourceId;
  final String targetId;
  final double weight;

  LayoutEdge({
    required this.sourceId,
    required this.targetId,
    this.weight = 1.0,
  });
}

class LayoutResult {
  final Map<String, Offset> positions;
  final bool converged;

  LayoutResult({required this.positions, this.converged = false});
}

class ForceDirectedLayout {
  final double areaWidth;
  final double areaHeight;
  final double idealEdgeLength;
  final double coolingFactor;
  final int maxIterations;
  final int? seed;

  double _temperature;

  ForceDirectedLayout({
    this.areaWidth = 800,
    this.areaHeight = 600,
    this.idealEdgeLength = 120,
    this.coolingFactor = 0.95,
    this.maxIterations = 200,
    this.seed,
  }) : _temperature = idealEdgeLength * 2;

  static ForceDirectedLayout adaptive(int nodeCount, {int? seed}) {
    final baseArea = nodeCount * 3000;
    final side = sqrt(baseArea).clamp(200.0, 700.0);
    final edgeLen = side.clamp(40.0, 100.0);
    return ForceDirectedLayout(
      areaWidth: side,
      areaHeight: side,
      idealEdgeLength: edgeLen,
      seed: seed,
    );
  }

  LayoutResult compute(
    List<LayoutNode> nodes,
    List<LayoutEdge> edges, {
    int? iterations,
  }) {
    if (nodes.isEmpty) {
      return LayoutResult(positions: {}, converged: true);
    }

    if (nodes.length == 1) {
      return LayoutResult(
        positions: {nodes[0].id: Offset(areaWidth / 2, areaHeight / 2)},
        converged: true,
      );
    }

    final rng = seed != null ? Random(seed) : Random();
    _temperature = idealEdgeLength * 2;

    for (final node in nodes) {
      node.x = areaWidth * 0.1 + rng.nextDouble() * areaWidth * 0.8;
      node.y = areaHeight * 0.1 + rng.nextDouble() * areaHeight * 0.8;
      node.vx = 0;
      node.vy = 0;
    }

    final totalIterations = iterations ?? maxIterations;
    var converged = false;

    for (var i = 0; i < totalIterations; i++) {
      _step(nodes, edges);
      _temperature *= coolingFactor;

      if (_temperature < 0.1) {
        converged = true;
        break;
      }
    }

    final positions = <String, Offset>{};
    for (final node in nodes) {
      positions[node.id] = Offset(node.x, node.y);
    }

    return LayoutResult(positions: positions, converged: converged);
  }

  LayoutResult computeIncremental(
    List<LayoutNode> nodes,
    List<LayoutEdge> edges,
    int iterationsPerFrame,
  ) {
    var converged = false;
    for (var i = 0; i < iterationsPerFrame; i++) {
      _step(nodes, edges);
      _temperature *= coolingFactor;
      if (_temperature < 0.1) {
        converged = true;
        break;
      }
    }

    final positions = <String, Offset>{};
    for (final node in nodes) {
      positions[node.id] = Offset(node.x, node.y);
    }

    return LayoutResult(positions: positions, converged: converged);
  }

  void _step(List<LayoutNode> nodes, List<LayoutEdge> edges) {
    final k = idealEdgeLength;
    final nodeMap = {for (final n in nodes) n.id: n};

    for (final node in nodes) {
      node.vx = 0;
      node.vy = 0;
    }

    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final a = nodes[i];
        final b = nodes[j];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final dist = sqrt(dx * dx + dy * dy).clamp(0.01, double.infinity);

        final repulsion = (k * k) / dist;
        final fx = (dx / dist) * repulsion;
        final fy = (dy / dist) * repulsion;

        a.vx -= fx;
        a.vy -= fy;
        b.vx += fx;
        b.vy += fy;
      }
    }

    for (final edge in edges) {
      final source = nodeMap[edge.sourceId];
      final target = nodeMap[edge.targetId];
      if (source == null || target == null) continue;

      final dx = target.x - source.x;
      final dy = target.y - source.y;
      final dist = sqrt(dx * dx + dy * dy).clamp(0.01, double.infinity);

      final effectiveK = k / edge.weight;
      final attraction = (dist * dist) / effectiveK;
      final fx = (dx / dist) * attraction;
      final fy = (dy / dist) * attraction;

      source.vx += fx;
      source.vy += fy;
      target.vx -= fx;
      target.vy -= fy;
    }

    for (final node in nodes) {
      final disp = sqrt(node.vx * node.vx + node.vy * node.vy);
      if (disp > 0) {
        final limited = min(disp, _temperature);
        node.x += (node.vx / disp) * limited;
        node.y += (node.vy / disp) * limited;
      }

      node.x = node.x.clamp(10, areaWidth - 10);
      node.y = node.y.clamp(10, areaHeight - 10);
    }
  }

  static double minNodeDistance(LayoutResult result, double nodeRadius) {
    final positions = result.positions.values.toList();
    var minDist = double.infinity;
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        final d = (positions[i] - positions[j]).distance;
        if (d < minDist) minDist = d;
      }
    }
    return minDist;
  }
}

/// Stress-majorization layout (Gansner et al. 2005).
///
/// Better than force-directed for static graph drawings because:
///
///  * Stress is a true global objective (minimises squared length error per
///    edge against its ideal length) so convergence is monotone.
///  * No `temperature`/velocity parameters — single scalar weight per edge.
///  * Handles weighted edges directly via the `LayoutEdge.weight` field.
///
/// Trade-off: O(V²) per iteration (full pairwise stress). For the sizes we
/// render in the graph view (≤ 500 nodes) this is fine; for very large graphs
/// fall back to a Barnes-Hut approximation (out of scope here).
class StressMajorizationLayout {
  final double areaWidth;
  final double areaHeight;
  final double idealEdgeLength;
  final int maxIterations;
  final double convergenceThreshold;
  final int? seed;

  StressMajorizationLayout({
    this.areaWidth = 800,
    this.areaHeight = 600,
    this.idealEdgeLength = 120,
    this.maxIterations = 200,
    this.convergenceThreshold = 0.5,
    this.seed,
  });

  static StressMajorizationLayout adaptive(int nodeCount, {int? seed}) {
    final baseArea = nodeCount * 3000;
    final side = sqrt(baseArea).clamp(200.0, 700.0);
    final edgeLen = side.clamp(40.0, 100.0);
    return StressMajorizationLayout(
      areaWidth: side,
      areaHeight: side,
      idealEdgeLength: edgeLen,
      seed: seed,
    );
  }

  LayoutResult compute(
    List<LayoutNode> nodes,
    List<LayoutEdge> edges, {
    int? iterations,
  }) {
    if (nodes.isEmpty) {
      return LayoutResult(positions: {}, converged: true);
    }
    if (nodes.length == 1) {
      return LayoutResult(
        positions: {nodes[0].id: Offset(areaWidth / 2, areaHeight / 2)},
        converged: true,
      );
    }

    final rng = seed != null ? Random(seed) : Random();

    // Seed positions in a wide grid so that the first iteration has
    // non-degenerate edge distances.
    final side = sqrt(nodes.length.toDouble()).ceil();
    final cell = Offset(areaWidth / (side + 1), areaHeight / (side + 1));
    for (var i = 0; i < nodes.length; i++) {
      final row = (i ~/ side).toDouble();
      final col = (i % side).toDouble();
      nodes[i].x = cell.dx * (col + 1) + rng.nextDouble() * 4 - 2;
      nodes[i].y = cell.dy * (row + 1) + rng.nextDouble() * 4 - 2;
    }

    final totalIterations = iterations ?? maxIterations;
    var converged = false;
    var previousStress = double.infinity;

    for (var it = 0; it < totalIterations; it++) {
      final stress = _step(nodes, edges);
      if (previousStress.isFinite) {
        final delta = (previousStress - stress).abs();
        if (delta < convergenceThreshold) {
          converged = true;
          break;
        }
      }
      previousStress = stress;
    }

    final positions = <String, Offset>{};
    for (final node in nodes) {
      positions[node.id] = Offset(node.x, node.y);
    }
    return LayoutResult(positions: positions, converged: converged);
  }

  /// Performs one majorization step and returns the current total stress.
  ///
  /// Algorithm:
  ///   For each node i, ideal position x_i* is the weighted average of
  ///   neighbours' positions:
  ///     x_i* = Σ_j w_ij x_j / Σ_j w_ij
  ///   where
  ///     w_ij = max(0, d_ij² - L²_ij) / (d_ij · L_ij)
  ///   and L_ij = idealEdgeLength / weight.
  double _step(List<LayoutNode> nodes, List<LayoutEdge> edges) {
    final n = nodes.length;
    final nodeIndex = <String, int>{for (var i = 0; i < n; i++) nodes[i].id: i};

    // Build neighbour map for O(1) weight lookup.
    final neighbours = <int, List<MapEntry<int, double>>>{
      for (var i = 0; i < n; i++) i: <MapEntry<int, double>>[],
    };
    for (final e in edges) {
      final s = nodeIndex[e.sourceId];
      final t = nodeIndex[e.targetId];
      if (s == null || t == null) continue;
      neighbours[s]!.add(MapEntry(t, e.weight));
      neighbours[t]!.add(MapEntry(s, e.weight));
    }

    final newX = List<double>.filled(n, 0);
    final newY = List<double>.filled(n, 0);

    for (var i = 0; i < n; i++) {
      final pi = nodes[i];
      double wxSum = 0;
      double wySum = 0;
      double wSum = 0;
      for (final entry in neighbours[i]!) {
        final pj = nodes[entry.key];
        final dx = pj.x - pi.x;
        final dy = pj.y - pi.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 1e-6) continue;
        final ideal = idealEdgeLength / entry.value;
        final diff = dist * dist - ideal * ideal;
        if (diff <= 0) continue;
        final w = diff / (dist * ideal);
        wxSum += w * pj.x;
        wySum += w * pj.y;
        wSum += w;
      }
      if (wSum > 0) {
        newX[i] = wxSum / wSum;
        newY[i] = wySum / wSum;
      } else {
        newX[i] = pi.x;
        newY[i] = pi.y;
      }
    }

    var stress = 0.0;
    for (var i = 0; i < n; i++) {
      nodes[i].x = newX[i].clamp(10.0, areaWidth - 10.0);
      nodes[i].y = newY[i].clamp(10.0, areaHeight - 10.0);
    }

    for (final e in edges) {
      final s = nodeIndex[e.sourceId];
      final t = nodeIndex[e.targetId];
      if (s == null || t == null) continue;
      final ps = nodes[s];
      final pt = nodes[t];
      final dx = pt.x - ps.x;
      final dy = pt.y - ps.y;
      final dist = sqrt(dx * dx + dy * dy);
      final ideal = idealEdgeLength / e.weight;
      final d = dist - ideal;
      stress += d * d;
    }
    return stress;
  }
}

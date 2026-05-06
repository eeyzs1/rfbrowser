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

  LayoutEdge({required this.sourceId, required this.targetId});
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

      final attraction = (dist * dist) / k;
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

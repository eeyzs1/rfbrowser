part of 'memory_graph_page.dart';

/// Lightweight Fruchterman-Reingold layout that returns normalized
/// positions in canvas pixel space (origin top-left of the canvas).
Map<String, Offset> _frLayout(_GraphData data) {
  final size = const Size(900, 700);
  final area = size.width * size.height;
  final k = math.sqrt(area / math.max(1, data.fragments.length)) * 0.6;
  final rand = math.Random(42);
  final positions = <String, Offset>{
    for (final f in data.fragments)
      f.id: Offset(
        size.width / 2 + (rand.nextDouble() - 0.5) * 200,
        size.height / 2 + (rand.nextDouble() - 0.5) * 200,
      ),
  };
  // 200 iterations is enough for ≤200 nodes.
  for (var iter = 0; iter < 200; iter++) {
    final disp = <String, Offset>{
      for (final id in positions.keys) id: Offset.zero,
    };
    // Repulsive forces
    final ids = positions.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final a = ids[i];
        final b = ids[j];
        final delta = positions[a]! - positions[b]!;
        final dist = math.max(0.01, delta.distance);
        final force = (k * k) / dist;
        final dir = delta / dist;
        disp[a] = disp[a]! + dir * force;
        disp[b] = disp[b]! - dir * force;
      }
    }
    // Attractive (spring) forces along edges
    for (final e in data.edges) {
      final delta = positions[e.fragmentA]! - positions[e.fragmentB]!;
      final dist = math.max(0.01, delta.distance);
      final force = (dist * dist / k) * e.strength.clamp(0.1, 5.0);
      final dir = delta / dist;
      disp[e.fragmentA] = disp[e.fragmentA]! - dir * force;
      disp[e.fragmentB] = disp[e.fragmentB]! + dir * force;
    }
    // Cool down and apply
    final t = 10.0 * math.pow(0.95, iter).toDouble();
    for (final id in positions.keys) {
      final total = disp[id]!;
      final length = math.max(0.01, total.distance);
      positions[id] = positions[id]! + (total / length) * math.min(length, t);
      // Keep within bounds
      final p = positions[id]!;
      positions[id] = Offset(
        p.dx.clamp(20.0, size.width - 20.0),
        p.dy.clamp(20.0, size.height - 20.0),
      );
    }
  }
  return positions;
}

class _MemoryGraphPainter extends CustomPainter {
  final Map<String, Offset> layout;
  final List<HebbianEdge> edges;
  final List<MemoryFragment> fragments;
  final String? selectedFragmentId;
  final Color primaryColor;
  final Color secondaryColor;
  final Color edgeColor;

  _MemoryGraphPainter({
    required this.layout,
    required this.edges,
    required this.fragments,
    required this.selectedFragmentId,
    required this.primaryColor,
    required this.secondaryColor,
    required this.edgeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFAFAFA),
    );
    // Edges
    for (final edge in edges) {
      final a = layout[edge.fragmentA];
      final b = layout[edge.fragmentB];
      if (a == null || b == null) continue;
      final isHighlighted =
          selectedFragmentId != null &&
          (edge.fragmentA == selectedFragmentId ||
              edge.fragmentB == selectedFragmentId);
      final paint = Paint()
        ..color = isHighlighted
            ? secondaryColor.withValues(alpha: 0.8)
            : edgeColor.withValues(alpha: 0.18)
        ..strokeWidth =
            (0.6 + edge.strength.clamp(0.1, 5.0) * 0.4) *
            (isHighlighted ? 1.5 : 1.0)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(a, b, paint);
    }
    // Nodes
    for (final f in fragments) {
      final pos = layout[f.id];
      if (pos == null) continue;
      final isSelected = f.id == selectedFragmentId;
      final radius = isSelected ? 12.0 : 7.0;
      final fill = Paint()
        ..color = isSelected
            ? secondaryColor
            : primaryColor.withValues(alpha: 0.85);
      canvas.drawCircle(pos, radius, fill);
      if (isSelected) {
        canvas.drawCircle(
          pos,
          radius + 4,
          Paint()
            ..color = secondaryColor.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MemoryGraphPainter old) =>
      old.layout != layout ||
      old.edges != edges ||
      old.selectedFragmentId != selectedFragmentId;
}

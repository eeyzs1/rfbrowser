import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_memory.dart';
import '../../services/memory_service.dart';

/// Standalone viewer for the memory Hebbian network: fragments are
/// nodes, co-activation edges are lines whose thickness encodes
/// strength. Built on a simple force-style layout (Fruchterman-Reingold)
/// re-run on data refresh.
///
/// Reached from the Memory Browser's toolbar.
class MemoryGraphPage extends ConsumerStatefulWidget {
  const MemoryGraphPage({super.key});

  @override
  ConsumerState<MemoryGraphPage> createState() => _MemoryGraphPageState();
}

class _MemoryGraphPageState extends ConsumerState<MemoryGraphPage> {
  String? _selectedFragmentId;
  final _transformController = TransformationController();
  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(memoryServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Network'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<_GraphData>(
        future: _load(memory),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load: ${snap.error}'),
              ),
            );
          }
          final data = snap.data ?? _GraphData.empty();
          if (data.fragments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 48,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No memory connections yet — keep chatting!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return _GraphView(
            data: data,
            selectedFragmentId: _selectedFragmentId,
            onSelect: (id) => setState(() => _selectedFragmentId = id),
            transformController: _transformController,
          );
        },
      ),
    );
  }

  Future<_GraphData> _load(MemoryService memory) async {
    final fragments = await memory.getNetworkedFragments(limit: 120);
    final edges = await memory.getTopHebbianEdges(limit: 400);
    // Drop edges that point to fragments outside our set.
    final ids = {for (final f in fragments) f.id};
    final filtered = edges
        .where((e) => ids.contains(e.fragmentA) && ids.contains(e.fragmentB))
        .toList();
    return _GraphData(fragments: fragments, edges: filtered);
  }
}

class _GraphData {
  final List<MemoryFragment> fragments;
  final List<HebbianEdge> edges;
  const _GraphData({required this.fragments, required this.edges});

  factory _GraphData.empty() => const _GraphData(fragments: [], edges: []);
}

class _GraphView extends StatelessWidget {
  final _GraphData data;
  final String? selectedFragmentId;
  final ValueChanged<String?> onSelect;
  final TransformationController transformController;
  const _GraphView({
    required this.data,
    required this.selectedFragmentId,
    required this.onSelect,
    required this.transformController,
  });

  @override
  Widget build(BuildContext context) {
    final layout = _frLayout(data);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: InteractiveViewer(
            transformationController: transformController,
            minScale: 0.3,
            maxScale: 3.0,
            child: CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: _MemoryGraphPainter(
                layout: layout,
                edges: data.edges,
                fragments: data.fragments,
                selectedFragmentId: selectedFragmentId,
                primaryColor: theme.colorScheme.primary,
                secondaryColor: theme.colorScheme.secondary,
                edgeColor: theme.colorScheme.outline,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) {
                  final local = details.localPosition;
                  String? tapped;
                  for (final entry in layout.entries) {
                    if ((entry.value - local).distance < 18) {
                      tapped = entry.key;
                      break;
                    }
                  }
                  onSelect(tapped);
                },
              ),
            ),
          ),
        ),
        SizedBox(
          width: 240,
          child: _GraphSidebar(
            data: data,
            selectedId: selectedFragmentId,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

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

class _GraphSidebar extends StatelessWidget {
  final _GraphData data;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  const _GraphSidebar({
    required this.data,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = selectedId == null
        ? null
        : data.fragments.firstWhere(
            (f) => f.id == selectedId,
            orElse: () => data.fragments.first,
          );
    final incidentEdges =
        selectedId == null
              ? <HebbianEdge>[]
              : data.edges
                    .where(
                      (e) =>
                          e.fragmentA == selectedId ||
                          e.fragmentB == selectedId,
                    )
                    .toList()
          ..sort((a, b) => b.strength.compareTo(a.strength));
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
        color: theme.colorScheme.surface,
      ),
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (selected == null) ...[
            const ListTile(
              dense: true,
              leading: Icon(Icons.touch_app, size: 18),
              title: Text('Tap a node to inspect'),
              subtitle: Text(
                'Lines show Hebbian co-activation strength. '
                'Line thickness = strength.',
              ),
            ),
          ] else ...[
            ListTile(
              dense: true,
              title: Text(
                selected.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'importance ${selected.importanceScore.toStringAsFixed(2)} · '
                'accesses ${selected.accessCount} · ${selected.tier.name}',
              ),
              leading: Icon(
                selected.isPinned ? Icons.push_pin : Icons.psychology,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Text(
                'Connected fragments (${incidentEdges.length})',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
            for (final edge in incidentEdges.take(20))
              _IncidentEdgeTile(
                edge: edge,
                fragments: data.fragments,
                currentId: selectedId!,
                onSelect: onSelect,
              ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Text(
              'Network stats',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.psychology, size: 16),
            title: Text('${data.fragments.length} fragments'),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.account_tree, size: 16),
            title: Text('${data.edges.length} edges'),
          ),
        ],
      ),
    );
  }
}

class _IncidentEdgeTile extends StatelessWidget {
  final HebbianEdge edge;
  final List<MemoryFragment> fragments;
  final String currentId;
  final ValueChanged<String?> onSelect;
  const _IncidentEdgeTile({
    required this.edge,
    required this.fragments,
    required this.currentId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherId = edge.fragmentA == currentId
        ? edge.fragmentB
        : edge.fragmentA;
    final other = fragments.firstWhere(
      (f) => f.id == otherId,
      orElse: () => fragments.first,
    );
    return ListTile(
      dense: true,
      onTap: () => onSelect(otherId),
      title: Text(other.content, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'strength ${edge.strength.toStringAsFixed(2)} · '
        'co-activated ${edge.coAccessCount}×',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      leading: Icon(
        Icons.arrow_outward,
        size: 14,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

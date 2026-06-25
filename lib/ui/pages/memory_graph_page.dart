import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_memory.dart';
import '../../l10n/app_localizations.dart';
import '../../services/memory_service.dart';

part 'memory_graph_painter.dart';
part 'memory_graph_sidebar.dart';

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

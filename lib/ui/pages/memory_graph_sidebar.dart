part of 'memory_graph_page.dart';

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
            ListTile(
              dense: true,
              leading: const Icon(Icons.touch_app, size: 18),
              title: Text(AppLocalizations.of(context)!.tapNodeToInspect),
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

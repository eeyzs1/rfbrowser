// ignore_for_file: unused_element, unused_element_parameter

part of '../memory_browser_page.dart';

class _HebbianTab extends ConsumerStatefulWidget {
  final MemoryService memory;
  final WidgetRef ref;
  const _HebbianTab({required this.memory, required this.ref});

  @override
  ConsumerState<_HebbianTab> createState() => _HebbianTabState();
}

class _HebbianTabState extends ConsumerState<_HebbianTab> {
  String? _selectedId;
  List<HebbianEdge> _edges = const [];
  List<MemoryFragment> _fragments = const [];
  // O(1) id→fragment lookup built once per _load() so the edges list
  // builder doesn't do an O(E×N) firstWhere scan per rebuild.
  Map<String, MemoryFragment> _fragById = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.memory.getAllActiveFragments();
    setState(() {
      _fragments = all;
      _fragById = {for (final f in all) f.id: f};
    });
    if (_selectedId != null) {
      _loadEdges();
    }
  }

  Future<void> _loadEdges() async {
    if (_selectedId == null) return;
    final edges = await widget.memory.getHebbianEdgesFor(_selectedId!);
    setState(() => _edges = edges);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _fragments.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final f = _fragments[i];
              final selected = f.id == _selectedId;
              return ListTile(
                dense: true,
                selected: selected,
                selectedTileColor: theme.colorScheme.primary.withValues(
                  alpha: 0.08,
                ),
                title: Text(
                  f.content.length > 80
                      ? '${f.content.substring(0, 80)}…'
                      : f.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${f.tier.name} · access × ${f.accessCount}',
                  style: theme.textTheme.bodySmall,
                ),
                onTap: () {
                  setState(() => _selectedId = f.id);
                  _loadEdges();
                },
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: _selectedId == null
              ? Center(child: Text(l.selectFragmentToSeeLinks))
              : _edges.isEmpty
              ? Center(child: Text(l.noHebbianLinks))
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _edges.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final edge = _edges[i];
                    final otherId = edge.otherEnd(_selectedId!)!;
                    final other = _fragById[otherId] ??
                        MemoryFragment(
                          id: otherId,
                          sessionId: '?',
                          content: '(unknown fragment)',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                    return ListTile(
                      dense: true,
                      leading: _StrengthBar(strength: edge.strength),
                      title: Text(
                        other.content.length > 80
                            ? '${other.content.substring(0, 80)}…'
                            : other.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'co-access × ${edge.coAccessCount}'
                        ' · stability ${edge.stability.toStringAsFixed(2)}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

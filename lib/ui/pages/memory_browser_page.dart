import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../data/models/chat_memory.dart';
import '../../services/memory_service.dart';

/// Top-level browser for the memory subsystem.
///
/// Renders three panels:
///   - Fragments, grouped by tier (short / mid / long)
///   - L1/L2/L3 summaries
///   - Hebbian edges for the currently-selected fragment
class MemoryBrowserPage extends ConsumerStatefulWidget {
  const MemoryBrowserPage({super.key});

  @override
  ConsumerState<MemoryBrowserPage> createState() => _MemoryBrowserPageState();
}

class _MemoryBrowserPageState extends ConsumerState<MemoryBrowserPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';
  bool _onlyActive = true;
  bool _onlyPinned = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(memoryServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Browser'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: 'Fragments'),
            Tab(icon: Icon(Icons.notes), text: 'Summaries'),
            Tab(icon: Icon(Icons.account_tree), text: 'Hebbian'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search memory…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Active'),
                  selected: _onlyActive,
                  onSelected: (v) => setState(() => _onlyActive = v),
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('Pinned'),
                  selected: _onlyPinned,
                  onSelected: (v) => setState(() => _onlyPinned = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FragmentsTab(
                  query: _query,
                  onlyActive: _onlyActive,
                  onlyPinned: _onlyPinned,
                  memory: memory,
                ),
                _SummariesTab(query: _query, memory: memory),
                _HebbianTab(memory: memory, ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FragmentsTab extends StatelessWidget {
  final String query;
  final bool onlyActive;
  final bool onlyPinned;
  final MemoryService memory;
  const _FragmentsTab({
    required this.query,
    required this.onlyActive,
    required this.onlyPinned,
    required this.memory,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MemoryFragment>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final fragments = snapshot.data ?? [];
        if (fragments.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No fragments match. Try a different query or wait for '
                'the next dreaming cycle to extract new facts.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        // Group by tier.
        final byTier = <MemoryTier, List<MemoryFragment>>{};
        for (final f in fragments) {
          (byTier[f.tier] ??= []).add(f);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final tier in MemoryTier.values)
              if ((byTier[tier] ?? []).isNotEmpty)
                _TierSection(
                  tier: tier,
                  fragments: byTier[tier]!,
                  memory: memory,
                ),
          ],
        );
      },
    );
  }

  Future<List<MemoryFragment>> _load() async {
    if (query.isEmpty) {
      final all = await memory.getAllActiveFragments();
      return all
          .where((f) => !onlyActive || f.isActive)
          .where((f) => !onlyPinned || f.isPinned)
          .toList();
    }
    final results = await memory.searchFragments(query, limit: 200);
    return results
        .where((f) => !onlyActive || f.isActive)
        .where((f) => !onlyPinned || f.isPinned)
        .toList();
  }
}

class _TierSection extends StatelessWidget {
  final MemoryTier tier;
  final List<MemoryFragment> fragments;
  final MemoryService memory;
  const _TierSection({
    required this.tier,
    required this.fragments,
    required this.memory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tier) {
      MemoryTier.short => Colors.green,
      MemoryTier.mid => Colors.orange,
      MemoryTier.long => Colors.red,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                '${tier.name.toUpperCase()} (${fragments.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...fragments.map(
          (f) => _FragmentCard(fragment: f, memory: memory),
        ),
      ],
    );
  }
}

class _FragmentCard extends ConsumerWidget {
  final MemoryFragment fragment;
  final MemoryService memory;
  const _FragmentCard({required this.fragment, required this.memory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final df = intl.DateFormat('yyyy-MM-dd HH:mm');
    final preview = fragment.content.length > 200
        ? '${fragment.content.substring(0, 200)}…'
        : fragment.content;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showDetails(context, ref),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Tag(label: fragment.category, color: theme.colorScheme.primary),
                  if (fragment.isPinned) ...[
                    const SizedBox(width: 4),
                    const _Tag(label: 'pinned', color: Colors.amber),
                  ],
                  if (fragment.summaryTier != MemorySummaryTier.none) ...[
                    const SizedBox(width: 4),
                    _Tag(
                      label: fragment.summaryTier.name,
                      color: Colors.purple,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'access × ${fragment.accessCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      fragment.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 18,
                    ),
                    tooltip: fragment.isPinned ? 'Unpin' : 'Pin',
                    onPressed: () async {
                      await memory.setPinned(fragment.id, !fragment.isPinned);
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(preview, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'imp ${fragment.importanceScore.toStringAsFixed(2)} · '
                'created ${df.format(fragment.createdAt.toLocal())}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Text(
                'Fragment ${fragment.id.substring(0, 8)}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(fragment.content),
              const SizedBox(height: 16),
              _DetailRow(
                label: 'Tier',
                value: fragment.tier.name,
              ),
              _DetailRow(
                label: 'Summary tier',
                value: fragment.summaryTier.name,
              ),
              _DetailRow(
                label: 'Importance',
                value: fragment.importanceScore.toStringAsFixed(3),
              ),
              _DetailRow(
                label: 'Access count',
                value: fragment.accessCount.toString(),
              ),
              _DetailRow(
                label: 'Last accessed',
                value: fragment.lastAccessAt == null
                    ? '—'
                    : fragment.lastAccessAt!.toLocal().toString(),
              ),
              if (fragment.parentSummaryId != null)
                _DetailRow(
                  label: 'Parent summary',
                  value: fragment.parentSummaryId!,
                ),
              if (fragment.archivedAt != null)
                _DetailRow(
                  label: 'Archived',
                  value: fragment.archivedAt!.toLocal().toString(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummariesTab extends StatelessWidget {
  final String query;
  final MemoryService memory;
  const _SummariesTab({required this.query, required this.memory});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MemorySummary>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final summaries = snapshot.data ?? [];
        if (summaries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No summaries yet. Summaries are produced by the dreaming '
                'engine after fragments are aged out of the short tier.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: summaries.length,
          itemBuilder: (_, i) => _SummaryCard(summary: summaries[i]),
        );
      },
    );
  }

  Future<List<MemorySummary>> _load() async {
    if (query.isEmpty) {
      // searchSummaries falls back to LIKE matches. We pull across all
      // tiers to keep the UI simple.
      final result = <MemorySummary>[];
      for (final tier in MemorySummaryTier.values) {
        result.addAll(
          await memory.searchSummaries(
            '',
            limit: 100,
            tiers: [tier],
          ).catchError((Object _) => <MemorySummary>[]),
        );
      }
      return result;
    }
    return memory.searchSummaries(query, limit: 100);
  }
}

class _SummaryCard extends StatelessWidget {
  final MemorySummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = intl.DateFormat('yyyy-MM-dd');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Tag(label: summary.summaryTier.name, color: Colors.purple),
                const SizedBox(width: 6),
                Text(
                  '${df.format(summary.startTimestamp.toLocal())} '
                  '→ ${df.format(summary.endTimestamp.toLocal())}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '${summary.messageCount} records',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(summary.summaryText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: summary.keywords
                  .take(8)
                  .map(
                    (kw) => Chip(
                      label: Text(
                        kw,
                        style: const TextStyle(fontSize: 11),
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.memory.getAllActiveFragments();
    setState(() => _fragments = all);
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
              ? const Center(child: Text('Select a fragment to see its links'))
              : _edges.isEmpty
                  ? const Center(child: Text('No Hebbian links for this fragment'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _edges.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final edge = _edges[i];
                        final otherId = edge.otherEnd(_selectedId!)!;
                        final other = _fragments.firstWhere(
                          (f) => f.id == otherId,
                          orElse: () => MemoryFragment(
                            id: otherId,
                            sessionId: '?',
                            content: '(unknown fragment)',
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
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

class _StrengthBar extends StatelessWidget {
  final double strength;
  const _StrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    // Cap the visual bar at 5.0 so a small edge doesn't disappear.
    final t = (strength / 5.0).clamp(0.0, 1.0);
    final color = t > 0.6
        ? Colors.green
        : t > 0.3
            ? Colors.orange
            : Colors.grey;
    return Container(
      width: 6,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: color.withValues(alpha: 0.2),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 6,
          height: 32 * t,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

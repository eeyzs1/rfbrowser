import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../data/models/chat_memory.dart';
import '../../services/memory_service.dart';
import '../../services/memory_stats_service.dart';
import 'memory_graph_page.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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
            icon: const Icon(Icons.account_tree),
            tooltip: 'View network',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MemoryGraphPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(memoryStatsProvider);
              ref.invalidate(memoryInsightsProvider);
              setState(() {});
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: 'Fragments'),
            Tab(icon: Icon(Icons.notes), text: 'Summaries'),
            Tab(icon: Icon(Icons.account_tree), text: 'Hebbian'),
            Tab(icon: Icon(Icons.insights), text: 'Insights'),
          ],
        ),
      ),
      body: Column(
        children: [
          const _StatsOverview(),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                      const _InsightsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Why this matched" chip — shows the composite score of a search
/// hit. Tap to expand a tooltip with the three sub-scores.
class _WhyMatchedChip extends StatelessWidget {
  final FragmentMatch match;
  const _WhyMatchedChip({required this.match});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message:
          'tokens ${match.matchedTokens}/${match.totalTokens} '
          '· importance ${match.importanceScore.toStringAsFixed(2)} '
          '· recency ${match.recencyScore.toStringAsFixed(2)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 11,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 3),
            Text(
              'why ${match.compositeScore.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact overview card showing fragment / summary / edge counts.
/// Re-fetches when invalidated via [memoryStatsProvider].
class _StatsOverview extends ConsumerWidget {
  const _StatsOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(memoryStatsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: statsAsync.when(
        data: (s) => _StatsCard(stats: s),
        loading: () => const _StatsLoadingPlaceholder(),
        error: (e, _) => _StatsError(message: e.toString()),
      ),
    );
  }
}

class _StatsLoadingPlaceholder extends StatelessWidget {
  const _StatsLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _StatsError extends StatelessWidget {
  final String message;
  const _StatsError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Stats unavailable: $message',
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final MemoryStats stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = intl.DateFormat('MM-dd HH:mm');
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Memory Health',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (stats.memoryHealthLabel != null)
                  _Tag(
                    label: stats.memoryHealthLabel!,
                    color: theme.colorScheme.secondary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _Stat(
                  icon: Icons.psychology,
                  label: 'Fragments',
                  value:
                      '${stats.activeFragments}'
                      '${stats.totalFragments > stats.activeFragments ? '/${stats.totalFragments}' : ''}',
                  hint: stats.archivedFragments > 0
                      ? '${stats.archivedFragments} archived'
                      : null,
                ),
                _Stat(
                  icon: Icons.push_pin,
                  label: 'Pinned',
                  value: '${stats.pinnedFragments}',
                ),
                _Stat(
                  icon: Icons.layers,
                  label: 'Summaries',
                  value: '${stats.totalSummaries}',
                  hint: _summaryBreakdown(stats),
                ),
                _Stat(
                  icon: Icons.account_tree,
                  label: 'Hebbian',
                  value: '${stats.totalHebbianEdges}',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (stats.lastChatMessage != null)
                  _Micro(
                    icon: Icons.chat_bubble_outline,
                    text:
                        'last chat ${df.format(stats.lastChatMessage!.toLocal())}',
                  ),
                if (stats.lastSummary != null) ...[
                  const SizedBox(width: 8),
                  _Micro(
                    icon: Icons.notes,
                    text:
                        'last summary ${df.format(stats.lastSummary!.toLocal())}',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String? _summaryBreakdown(MemoryStats s) {
    final parts = <String>[];
    final l1 = s.summariesByTier[MemorySummaryTier.l1] ?? 0;
    final l2 = s.summariesByTier[MemorySummaryTier.l2] ?? 0;
    final l3 = s.summariesByTier[MemorySummaryTier.l3] ?? 0;
    if (l1 > 0) parts.add('L1:$l1');
    if (l2 > 0) parts.add('L2:$l2');
    if (l3 > 0) parts.add('L3:$l3');
    return parts.isEmpty ? null : parts.join(' ');
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Micro extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Micro({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: theme.hintColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
            fontSize: 10,
          ),
        ),
      ],
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
    return FutureBuilder<_FragmentsLoad>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data?.items ?? const <_FragmentWithMatch>[];
        if (items.isEmpty) {
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
        final byTier = <MemoryTier, List<_FragmentWithMatch>>{};
        for (final wm in items) {
          (byTier[wm.fragment.tier] ??= []).add(wm);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final tier in MemoryTier.values)
              if ((byTier[tier] ?? []).isNotEmpty)
                _TierSection(tier: tier, items: byTier[tier]!, memory: memory),
          ],
        );
      },
    );
  }

  Future<_FragmentsLoad> _load() async {
    if (query.isEmpty) {
      final all = await memory.getAllActiveFragments();
      final filtered = all
          .where((f) => !onlyActive || f.isActive)
          .where((f) => !onlyPinned || f.isPinned)
          .map((f) => _FragmentWithMatch(fragment: f))
          .toList();
      return _FragmentsLoad(items: filtered);
    }
    final results = await memory.searchFragmentsWithScores(query, limit: 200);
    final filtered = results
        .where((m) => !onlyActive || m.fragment.isActive)
        .where((m) => !onlyPinned || m.fragment.isPinned)
        .map((m) => _FragmentWithMatch(fragment: m.fragment, match: m))
        .toList();
    return _FragmentsLoad(items: filtered);
  }
}

class _FragmentsLoad {
  final List<_FragmentWithMatch> items;
  const _FragmentsLoad({this.items = const []});
}

class _FragmentWithMatch {
  final MemoryFragment fragment;
  final FragmentMatch? match;
  const _FragmentWithMatch({required this.fragment, this.match});
}

class _TierSection extends StatelessWidget {
  final MemoryTier tier;
  final List<_FragmentWithMatch> items;
  final MemoryService memory;
  const _TierSection({
    required this.tier,
    required this.items,
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
              Container(width: 6, height: 16, color: color),
              const SizedBox(width: 8),
              Text(
                '${tier.name.toUpperCase()} (${items.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...items.map(
          (wm) => _FragmentCard(
            fragment: wm.fragment,
            memory: memory,
            match: wm.match,
          ),
        ),
      ],
    );
  }
}

class _FragmentCard extends ConsumerWidget {
  final MemoryFragment fragment;
  final MemoryService memory;
  final FragmentMatch? match;
  const _FragmentCard({
    required this.fragment,
    required this.memory,
    this.match,
  });

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
                  _Tag(
                    label: fragment.category,
                    color: theme.colorScheme.primary,
                  ),
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
                  if (match != null)
                    _WhyMatchedChip(match: match!)
                  else
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
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(context, ref),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete fragment?'),
        content: Text(
          'This permanently removes the fragment and any Hebbian links '
          'attached to it. There is no undo.\n\n"${fragment.content.length > 80 ? '${fragment.content.substring(0, 80)}…' : fragment.content}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await memory.deleteFragment(fragment.id);
      ref.invalidate(memoryStatsProvider);
      (context as Element).markNeedsBuild();
    }
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
              _DetailRow(label: 'Tier', value: fragment.tier.name),
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
          await memory
              .searchSummaries('', limit: 100, tiers: [tier])
              .catchError((Object _) => <MemorySummary>[]),
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
                      label: Text(kw, style: const TextStyle(fontSize: 11)),
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
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ─── Insights Tab ──────────────────────────────────────────────────────────

/// Memory insights: trending keywords, top fragments, recent summaries,
/// forgetting activity. Pulls data from [memoryInsightsProvider] and
/// renders a single scrollable list grouped by section.
class _InsightsTab extends ConsumerWidget {
  const _InsightsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInsights = ref.watch(memoryInsightsProvider);
    return asyncInsights.when(
      data: (insights) => _InsightsContent(insights: insights),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Insights unavailable: $e',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _InsightsContent extends StatelessWidget {
  final MemoryInsights insights;
  const _InsightsContent({required this.insights});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (insights.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb_outline, size: 40, color: theme.hintColor),
              const SizedBox(height: 8),
              Text(
                'No insights yet — start chatting to build memory.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (insights.trending.isNotEmpty) ...[
          _SectionHeader(
            title: 'Trending keywords',
            subtitle: 'last ${insights.windowDays} days',
            icon: Icons.trending_up,
          ),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in insights.trending)
                    Chip(
                      label: Text('${t.word} · ${t.count}'),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (insights.topFragments.isNotEmpty) ...[
          _SectionHeader(
            title: 'Top fragments',
            subtitle: 'ranked by importance × recency',
            icon: Icons.star,
          ),
          ...insights.topFragments.map(
            (f) => Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                dense: true,
                title: Text(
                  f.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'importance ${f.importanceScore.toStringAsFixed(2)} · '
                  'accesses ${f.accessCount} · ${f.tier.name}',
                ),
                leading: Icon(
                  f.isPinned ? Icons.push_pin : Icons.psychology_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (insights.recentSummaries.isNotEmpty) ...[
          _SectionHeader(
            title: 'Recent summaries',
            subtitle: 'latest compression events',
            icon: Icons.notes,
          ),
          ...insights.recentSummaries.map(
            (s) => Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                dense: true,
                title: Text(
                  s.summaryText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${s.summaryTier.name.toUpperCase()} · '
                  '${s.messageCount} messages · '
                  '${s.keywords.length} keywords',
                ),
                leading: Icon(
                  Icons.notes,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _SectionHeader(
          title: 'Forgetting activity',
          subtitle:
              'fragments lost in the last '
              '${insights.windowDays} days',
          icon: Icons.auto_awesome,
        ),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: ListTile(
            dense: true,
            leading: Icon(
              Icons.delete_outline,
              size: 18,
              color: theme.colorScheme.tertiary,
            ),
            title: Text('${insights.forgottenCount} forgotten'),
            subtitle: const Text(
              'transitioned, archived, or marked forgotten by the user',
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

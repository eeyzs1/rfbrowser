// ignore_for_file: unused_element, unused_element_parameter

part of '../memory_browser_page.dart';

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
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<_FragmentsLoad>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(l.errorWithMessage(snapshot.error.toString())));
        }
        final items = snapshot.data?.items ?? const <_FragmentWithMatch>[];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.noFragmentsMatch,
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

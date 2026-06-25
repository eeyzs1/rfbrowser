// ignore_for_file: unused_element, unused_element_parameter

part of '../memory_browser_page.dart';

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

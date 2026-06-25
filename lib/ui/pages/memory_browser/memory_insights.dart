// ignore_for_file: unused_element, unused_element_parameter

part of '../memory_browser_page.dart';

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

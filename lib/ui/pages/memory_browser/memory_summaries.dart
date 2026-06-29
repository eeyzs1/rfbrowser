// ignore_for_file: unused_element, unused_element_parameter

part of '../memory_browser_page.dart';

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
      // tiers in parallel via Future.wait so the N DB round-trips run
      // concurrently instead of serially.
      final tierResults = await Future.wait(
        MemorySummaryTier.values.map(
          (t) => memory
              .searchSummaries('', limit: 100, tiers: [t])
              .catchError((Object _) => <MemorySummary>[]),
        ),
      );
      return [for (final r in tierResults) ...r];
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

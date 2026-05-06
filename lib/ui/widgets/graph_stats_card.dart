import 'package:flutter/material.dart';
import '../../data/models/graph_stat.dart';

class GraphStatsCard extends StatelessWidget {
  final GraphStats stats;

  const GraphStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Graph Statistics',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatRow(label: 'Nodes', value: stats.totalNodes.toString(), theme: theme),
          _StatRow(label: 'Edges', value: stats.totalEdges.toString(), theme: theme),
          _StatRow(
            label: 'Avg Degree',
            value: stats.avgDegree.toStringAsFixed(1),
            theme: theme,
          ),
          _StatRow(
            label: 'Components',
            value: stats.componentCount.toString(),
            theme: theme,
          ),
          _StatRow(
            label: 'Largest Component',
            value: stats.maxComponentSize.toString(),
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _StatRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

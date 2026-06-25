// ignore_for_file: unused_element, unused_element_parameter

part of '../graph_page.dart';

class _NodeTooltip extends StatelessWidget {
  final String noteId;
  final List<Note> notes;
  final int linkCount;

  const _NodeTooltip({
    required this.noteId,
    required this.notes,
    required this.linkCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = notes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.md,
        vertical: DesignSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(DesignRadius.md),
        boxShadow: [DesignShadow.md],
      ),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            note.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DesignSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 12, color: theme.hintColor),
              const SizedBox(width: DesignSpacing.xs),
              Text(
                '$linkCount connections',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: DesignSpacing.xs),
            Wrap(
              spacing: DesignSpacing.xs,
              children: note.tags
                  .take(3)
                  .map(
                    (tag) => Text(
                      '#$tag',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _GraphLegend extends StatelessWidget {
  final ThemeData theme;

  const _GraphLegend({required this.theme});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(DesignSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(DesignRadius.md),
        boxShadow: [DesignShadow.sm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Legend',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DesignSpacing.sm),
          _legendItem(theme.colorScheme.primary, 'Normal node'),
          _legendItem(theme.colorScheme.secondary, 'Hovered node'),
          _legendItem(theme.colorScheme.error, 'Bridge node (critical path)'),
          const SizedBox(height: DesignSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Solid line sample (manual link)
              Container(
                width: 16,
                height: 2,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(l.solidManualLink, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: DesignSpacing.xs),
          // Dashed line sample (auto-discovered [[wikilink]])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(16, 2),
                painter: _DashedLineLegendPainter(
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(
                'Dashed = auto [[wikilink]]',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: DesignSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(l.smallFewLinks, style: theme.textTheme.labelSmall),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(l.largeManyLinks, style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: DesignSpacing.sm),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

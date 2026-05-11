import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../theme/design_tokens.dart';

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final knowledgeState = ref.watch(knowledgeProvider);
    final noteCount = knowledgeState.notes.length;
    final links = knowledgeState.links;
    final notesWithLinks = knowledgeState.notes
        .where(
          (n) => links.any((l) => l.sourceId == n.id || l.targetId == n.id),
        )
        .length;
    final notesWithTags = knowledgeState.notes
        .where((n) => n.tags.isNotEmpty)
        .length;
    final currentFilter = knowledgeState.noteFilter;

    return Container(
      padding: const EdgeInsets.all(DesignSpacing.md),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.filter,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DesignSpacing.md),
          _FilterOption(
            icon: Icons.description_outlined,
            label: l.allNotes,
            count: noteCount,
            isActive: currentFilter == NoteFilter.all,
            onTap: () =>
                ref.read(knowledgeProvider.notifier).setFilter(NoteFilter.all),
          ),
          _FilterOption(
            icon: Icons.link,
            label: l.hasLinks,
            count: notesWithLinks,
            isActive: currentFilter == NoteFilter.hasLinks,
            onTap: () => ref
                .read(knowledgeProvider.notifier)
                .setFilter(NoteFilter.hasLinks),
          ),
          _FilterOption(
            icon: Icons.attach_file,
            label: l.hasAttachments,
            count: 0,
            isActive: currentFilter == NoteFilter.hasAttachments,
            onTap: () => ref
                .read(knowledgeProvider.notifier)
                .setFilter(NoteFilter.hasAttachments),
          ),
          _FilterOption(
            icon: Icons.tag,
            label: l.tags,
            count: notesWithTags,
            isActive: currentFilter == NoteFilter.hasTags,
            onTap: () => ref
                .read(knowledgeProvider.notifier)
                .setFilter(NoteFilter.hasTags),
          ),
          const Spacer(),
          Text(
            l.noteCount(noteCount),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback? onTap;

  const _FilterOption({
    required this.icon,
    required this.label,
    required this.count,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.1)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.xs),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignRadius.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.sm,
              vertical: DesignSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isActive ? theme.colorScheme.primary : theme.hintColor,
                ),
                const SizedBox(width: DesignSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodySmall?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: DesignSpacing.xs),
                if (count >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

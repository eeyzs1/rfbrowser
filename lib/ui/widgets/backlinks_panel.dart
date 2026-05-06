import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/knowledge_service.dart';
import '../../data/models/link_type.dart';
import '../../data/models/unlinked_mention.dart';

class BacklinksPanel extends ConsumerWidget {
  const BacklinksPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final theme = Theme.of(context);
    final activeNote = knowledgeState.activeNote;
    final backlinks = knowledgeState.backlinks;

    final unlinkedMentions = activeNote != null
        ? ref.read(knowledgeProvider.notifier).getUnlinkedMentions(activeNote.id)
        : <UnlinkedMentionResult>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.link, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Backlinks',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${backlinks.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: activeNote == null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No note selected',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : backlinks.isEmpty && unlinkedMentions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No backlinks yet',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...backlinks
                        .map(
                          (link) => _BacklinkItem(
                            sourceId: link.sourceId,
                            linkContext: link.context,
                            type: link.type,
                          ),
                        ),
                    if (unlinkedMentions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.link_off,
                              size: 14,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Unlinked Mentions',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${unlinkedMentions.length}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...unlinkedMentions
                          .map(
                            (m) => _UnlinkedMentionItem(
                              mention: m,
                              onLink: () => ref
                                .read(knowledgeProvider.notifier)
                                .linkMention(m.sourceNoteId, m.targetTitle, m.position),
                            ),
                          ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _BacklinkItem extends ConsumerWidget {
  final String sourceId;
  final String? linkContext;
  final LinkType type;

  const _BacklinkItem({
    required this.sourceId,
    this.linkContext,
    required this.type,
  });

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final theme = Theme.of(ctx);
    final knowledgeState = ref.watch(knowledgeProvider);
    final sourceNote = knowledgeState.notes
        .where((n) => n.id == sourceId)
        .firstOrNull;
    final title = sourceNote?.title ?? sourceId;

    return InkWell(
      onTap: () {
        if (sourceNote != null) {
          ref.read(knowledgeProvider.notifier).openNote(sourceNote.filePath);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == LinkType.embed ? Icons.input : Icons.link,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (linkContext != null && linkContext!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2),
                child: Text(
                  linkContext!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnlinkedMentionItem extends ConsumerWidget {
  final UnlinkedMentionResult mention;
  final VoidCallback onLink;

  const _UnlinkedMentionItem({
    required this.mention,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        final knowledgeState = ref.read(knowledgeProvider);
        final note = knowledgeState.notes
            .where((n) => n.title.toLowerCase() == mention.targetTitle.toLowerCase())
            .firstOrNull;
        if (note != null) {
          ref.read(knowledgeProvider.notifier).openNote(note.filePath);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link_off,
                  size: 12,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mention.targetTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_link,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: onLink,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  tooltip: 'Link',
                ),
              ],
            ),
            if (mention.context.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2),
                child: Text(
                  mention.context,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

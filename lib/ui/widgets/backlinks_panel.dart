import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../../data/models/link_type.dart';
import '../../data/models/note.dart';
import '../../data/models/unlinked_mention.dart';

/// Right-hand panel showing backlinks and unlinked mentions for the
/// active note. Backlinks are cheap (a cached list lookup) and render
/// immediately. Unlinked mentions require an O(n_titles × content)
/// regex scan, so on first open (cache miss) the scan is deferred to a
/// microtask so the note can paint first instead of freezing the UI.
class BacklinksPanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const BacklinksPanel({super.key, this.onClose});

  @override
  ConsumerState<BacklinksPanel> createState() => _BacklinksPanelState();
}

class _BacklinksPanelState extends ConsumerState<BacklinksPanel> {
  List<UnlinkedMentionResult> _unlinkedMentions = const [];
  // Tracks the (noteId, content) the current [_unlinkedMentions] was
  // computed for, so we only re-scan when the active note actually
  // changes — not on every keystroke that bubbles through the provider.
  String? _computedNoteId;
  String? _computedContent;

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final activeNote = knowledgeState.activeNote;
    final backlinks = knowledgeState.backlinks;

    _maybeScheduleUnlinkedScan(activeNote);

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
                l.backlinks,
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.onClose != null)
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.hintColor,
                  ),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: l.closePanel,
                ),
            ],
          ),
        ),
        Expanded(
          child: activeNote == null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    l.noNoteSelected,
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : backlinks.isEmpty && _unlinkedMentions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l.noBacklinks, style: theme.textTheme.bodySmall),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...backlinks.map(
                      (link) => _BacklinkItem(
                        sourceId: link.sourceId,
                        linkContext: link.context,
                        type: link.type,
                      ),
                    ),
                    if (_unlinkedMentions.isNotEmpty) ...[
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
                            Flexible(
                              child: Text(
                                l.unlinkedMentions,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_unlinkedMentions.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._unlinkedMentions.map(
                        (m) => _UnlinkedMentionItem(
                          mention: m,
                          onLink: () => ref
                              .read(knowledgeProvider.notifier)
                              .linkMention(
                                m.sourceNoteId,
                                m.targetTitle,
                                m.position,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// Schedules an unlinked-mention scan only when the active note or its
  /// content has changed since the last computation. The scan runs in a
  /// microtask so this build returns immediately and the note can paint
  /// first; the panel then populates once the (cached or fresh) result
  /// is ready.
  void _maybeScheduleUnlinkedScan(Note? activeNote) {
    if (activeNote == null) {
      if (_computedNoteId != null) {
        _computedNoteId = null;
        _computedContent = null;
        _unlinkedMentions = const [];
      }
      return;
    }
    if (activeNote.id == _computedNoteId &&
        activeNote.content == _computedContent) {
      return;
    }
    _computedNoteId = activeNote.id;
    _computedContent = activeNote.content;
    final noteId = activeNote.id;
    Future.microtask(() {
      if (!mounted) return;
      final result =
          ref.read(knowledgeProvider.notifier).getUnlinkedMentions(noteId);
      if (!mounted) return;
      // Guard against the active note having changed again while the
      // microtask was pending.
      final current = ref.read(knowledgeProvider).activeNote;
      if (current?.id != noteId) return;
      setState(() {
        _unlinkedMentions = result;
      });
    });
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
          ref.read(knowledgeProvider.notifier).openNote(sourceNote.id);
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

  const _UnlinkedMentionItem({required this.mention, required this.onLink});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return InkWell(
      onTap: () {
        final knowledgeState = ref.read(knowledgeProvider);
        final note = knowledgeState.notes
            .where(
              (n) => n.title.toLowerCase() == mention.targetTitle.toLowerCase(),
            )
            .firstOrNull;
        if (note != null) {
          ref.read(knowledgeProvider.notifier).openNote(note.id);
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
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  tooltip: l.link,
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

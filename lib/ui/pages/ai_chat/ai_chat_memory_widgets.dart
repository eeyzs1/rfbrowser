part of '../ai_chat_panel.dart';

/// Per-message "Remember this" / "Forget" toggle. Looks up the
/// fragment by the chat message id and switches the icon/label
/// accordingly. Idempotent: clicking twice does no harm.
class _RememberForgetButton extends ConsumerStatefulWidget {
  final ChatMessage message;
  const _RememberForgetButton({required this.message});

  @override
  ConsumerState<_RememberForgetButton> createState() =>
      _RememberForgetButtonState();
}

class _RememberForgetButtonState extends ConsumerState<_RememberForgetButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memory = ref.watch(memoryServiceProvider);

    return FutureBuilder(
      future: memory.getFragmentByMessageId(widget.message.id),
      builder: (context, snap) {
        final fragment = snap.data;
        final isRemembered = fragment != null;
        return TextButton.icon(
          onPressed: _busy ? null : _onTap,
          icon: Icon(
            isRemembered ? Icons.bookmark : Icons.bookmark_outline,
            size: 12,
            color: isRemembered
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          label: Text(
            isRemembered ? 'Remembered' : 'Remember',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isRemembered
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }

  Future<void> _onTap() async {
    if (widget.message.id == null) return;
    setState(() => _busy = true);
    try {
      final memory = ref.read(memoryServiceProvider);
      final existing = await memory.getFragmentByMessageId(widget.message.id);
      if (existing == null) {
        await memory.addFragmentFromMessage(
          sessionId: '',
          messageId: widget.message.id!,
          content: widget.message.content,
          importance: 0.7,
          source: 'manual',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved to memory'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (existing.isActive) {
        await memory.forgetFragment(existing.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from memory'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      // Invalidate stats provider so the browser refreshes.
      ref.invalidate(memoryStatsProvider);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// "Memory footprint" — a small chip cloud below the assistant's reply
/// that lists which memory fragments / summaries influenced the answer.
/// Tapping a chip opens the fragment detail. Only renders after the
/// assistant's reply completes streaming.
class _MemoryFootprint extends ConsumerWidget {
  final ChatMessage message;
  const _MemoryFootprint({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final memory = ref.watch(memoryServiceProvider);
    final fragmentIds = message.usedMemoryFragmentIds;
    final summaryIds = message.usedMemorySummaryIds;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FutureBuilder<_FootprintData>(
        future: _load(memory),
        builder: (context, snap) {
          final data = snap.data ?? const _FootprintData.empty();
          return Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 11,
                    color: theme.hintColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    message.memoryContextTokens > 0
                        ? 'used ${fragmentIds.length + summaryIds.length} '
                              'memories (${message.memoryContextTokens} tok)'
                        : 'used ${fragmentIds.length + summaryIds.length} memories',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              for (final f in data.fragments.take(5))
                _FragmentChip(
                  fragment: f,
                  onTap: () => _showDetail(context, ref, f),
                ),
              if (data.fragments.length > 5)
                Text(
                  '+${data.fragments.length - 5}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 10,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<_FootprintData> _load(MemoryService memory) async {
    final out = <MemoryFragment>[];
    for (final id in message.usedMemoryFragmentIds) {
      final f = await memory.getFragment(id);
      if (f != null) out.add(f);
    }
    return _FootprintData(fragments: out);
  }

  void _showDetail(BuildContext context, WidgetRef ref, MemoryFragment f) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              f.isPinned ? Icons.push_pin : Icons.psychology,
              size: 18,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                f.tier.name.toUpperCase(),
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.content),
              const SizedBox(height: 8),
              Text(
                'importance ${f.importanceScore.toStringAsFixed(2)} · '
                'accesses ${f.accessCount} · ${f.source}',
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx)!.close),
          ),
        ],
      ),
    );
  }
}

class _FragmentChip extends StatelessWidget {
  final MemoryFragment fragment;
  final VoidCallback onTap;
  const _FragmentChip({required this.fragment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = fragment.content.length > 36
        ? '${fragment.content.substring(0, 36)}…'
        : fragment.content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              fragment.isPinned ? Icons.push_pin : Icons.psychology,
              size: 9,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 3),
            Text(
              preview,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FootprintData {
  final List<MemoryFragment> fragments;
  const _FootprintData({required this.fragments});
  const _FootprintData.empty() : fragments = const [];
}

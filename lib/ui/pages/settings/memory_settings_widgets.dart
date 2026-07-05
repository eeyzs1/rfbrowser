part of 'memory_settings_section.dart';

/// Tile that triggers a manual export of the current chat session.
class _ManualExportTile extends ConsumerWidget {
  const _ManualExportTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.file_download),
      title: const Text('Export current chat to Markdown'),
      subtitle: const Text(
        'Writes the active chat session to <vault>/.rfbrowser/chats/ '
        'with YAML frontmatter. The next dreaming cycle will then keep '
        'it in sync.',
      ),
      onTap: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref
          .read(dreamingServiceProvider)
          .exportCurrentSession();
      if (path == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No active chat session to export')),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported to $path'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

/// Row with backup/restore buttons for the memory database.
class _BackupRestoreRow extends ConsumerStatefulWidget {
  const _BackupRestoreRow();
  @override
  ConsumerState<_BackupRestoreRow> createState() => _BackupRestoreRowState();
}

class _BackupRestoreRowState extends ConsumerState<_BackupRestoreRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(memoryServiceProvider);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _exportToJson(memory),
            icon: const Icon(Icons.save_alt),
            label: const Text('Backup to JSON'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _restoreFromJson(memory),
            icon: const Icon(Icons.restore),
            label: const Text('Restore from JSON'),
          ),
        ),
      ],
    );
  }

  Future<void> _exportToJson(MemoryService memory) async {
    setState(() => _busy = true);
    try {
      final data = await memory.exportToJson();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${(data['counts'] as Map)['fragments']} fragments · '
            '${(data['counts'] as Map)['summaries']} summaries · '
            '${(data['counts'] as Map)['hebbian_edges']} edges '
            '(${json.length} bytes)',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      appLog.debug('MemoryService export: ${json.length} bytes');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromJson(MemoryService memory) async {
    setState(() => _busy = true);
    try {
      // 使用 file_picker 让用户选择备份文件
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (pickerResult == null || pickerResult.files.isEmpty) {
        if (!mounted) return;
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.restoreCancelled)));
        return;
      }

      final path = pickerResult.files.first.path;
      if (path == null) {
        if (!mounted) return;
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.restoreInvalidFile)));
        return;
      }

      // 读取并解析 JSON 文件
      final file = File(path);
      final content = await file.readAsString();
      final Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(content);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Root JSON is not an object');
        }
        data = decoded;
      } catch (_) {
        if (!mounted) return;
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.restoreInvalidFile)));
        return;
      }

      // 导入数据
      final result = await memory.importFromJson(data, replaceExisting: false);
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.restoreSuccess(
              result.fragments,
              result.summaries,
              result.hebbianEdges,
            ),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.restoreFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Live status card for the dreaming engine. Shows "when did the system
/// last consolidate, what did it do" without requiring the user to read
/// logs. Auto-refreshes every 30s via [dreamingStatusProvider].
class _DreamingStatusCard extends ConsumerWidget {
  const _DreamingStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final asyncStatus = ref.watch(dreamingStatusProvider);

    return asyncStatus.when(
      data: (s) => _DreamingStatusBody(status: s, theme: theme),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          l.statusUnavailable(e.toString()),
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
    );
  }
}

class _DreamingStatusBody extends ConsumerStatefulWidget {
  final DreamingStatus status;
  final ThemeData theme;
  const _DreamingStatusBody({required this.status, required this.theme});

  @override
  ConsumerState<_DreamingStatusBody> createState() =>
      _DreamingStatusBodyState();
}

class _DreamingStatusBodyState extends ConsumerState<_DreamingStatusBody> {
  /// 点击"立即整理"后本地 loading 标记，直到状态流刷新出 isConsolidating。
  bool _triggering = false;

  bool get _busy => _triggering || widget.status.isConsolidating;

  Future<void> _consolidateNow() async {
    if (_busy) return;
    setState(() => _triggering = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dreamingServiceProvider).consolidateNow();
      // 立即刷新状态流，让卡片显示最新整理结果。
      ref.invalidate(dreamingStatusProvider);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Dreaming consolidation completed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Consolidation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final theme = widget.theme;
    final l = AppLocalizations.of(context)!;
    final df = _relativeDateFormat(status.lastConsolidationAt);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.tertiary,
                  ),
                )
              else
                Icon(
                  status.lastConsolidationAt == null
                      ? Icons.nightlight_outlined
                      : Icons.auto_awesome,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _busy
                      ? l.dreamingInProgress
                      : (status.lastConsolidationAt == null
                            ? l.noDreamsYet
                            : l.lastDream(df)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 立即整理按钮
              TextButton.icon(
                onPressed: _busy ? null : _consolidateNow,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt, size: 16),
                label: Text(l.consolidateNow),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (status.lastConsolidationAt != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _StatusChip(
                  icon: Icons.add_circle_outline,
                  label: '${status.lastNewFragments} extracted',
                ),
                _StatusChip(
                  icon: Icons.notes,
                  label: '${status.lastSummariesCreated} summaries',
                ),
                _StatusChip(
                  icon: Icons.swap_vert,
                  label: '${status.lastRecordsTransitioned} transitioned',
                ),
                if (status.lastStaleEdgesPruned > 0)
                  _StatusChip(
                    icon: Icons.cleaning_services,
                    label: '${status.lastStaleEdgesPruned} edges pruned',
                  ),
                if (status.lastExportAt != null)
                  _StatusChip(
                    icon: Icons.save_alt,
                    label:
                        'last export ${_relativeDateFormat(status.lastExportAt)}',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _relativeDateFormat(DateTime? t) {
    if (t == null) return 'never';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 5) return 'just now';
    if (d.inMinutes < 1) return '${d.inSeconds}s ago';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

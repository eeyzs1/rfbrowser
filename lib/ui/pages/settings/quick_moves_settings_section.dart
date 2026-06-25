import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/quick_move_service.dart';
import '../../../data/models/quick_move.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/create_quick_move_dialog.dart';

part 'quick_moves_settings_section_edit.dart';

class QuickMovesSettingsSection extends ConsumerWidget {
  const QuickMovesSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickMoveState = ref.watch(quickMoveProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return SettingsSection(
      title: l?.quickMoves ?? 'Quick Moves',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manage your quick commands',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => showCreateQuickMoveDialog(context, ref),
                    tooltip: 'Add Command',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restore, size: 18),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            l?.restoreDefaultCommands ??
                                'Restore Default Commands',
                          ),
                          content: Text(
                            l?.restoreDefaultCommandsDesc ??
                                'Restore default commands?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l?.cancel ?? 'Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l?.restore ?? 'Restore'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref.read(quickMoveProvider.notifier).restoreDefaults();
                      }
                    },
                    tooltip: 'Restore Defaults',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.any,
                      );
                      if (result != null && result.files.single.path != null) {
                        final file = await File(
                          result.files.single.path!,
                        ).readAsString();
                        final success = await ref
                            .read(quickMoveProvider.notifier)
                            .importFromJson(file);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? (l?.importSuccess ?? 'Import successful')
                                    : (l?.importFailed ?? 'Import failed'),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    tooltip: 'Import',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    onPressed: () {
                      final _ = ref
                          .read(quickMoveProvider.notifier)
                          .exportToJson();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('JSON data ready for export'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: 'Export',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              if (quickMoveState.moves.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.bolt, size: 32, color: theme.hintColor),
                        const SizedBox(height: 8),
                        Text(
                          'No quick moves yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              showCreateQuickMoveDialog(context, ref),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Create your first quick move'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < quickMoveState.moves.length; i++)
                      _buildMoveTile(
                        context,
                        ref,
                        theme,
                        quickMoveState.moves[i],
                        index: i,
                        total: quickMoveState.moves.length,
                        key: ValueKey(quickMoveState.moves[i].id),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoveTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    QuickMove move, {
    required int index,
    required int total,
    Key? key,
  }) {
    final l = AppLocalizations.of(context);
    final canMoveUp = index > 0;
    final canMoveDown = index < total - 1;
    return Dismissible(
      key: key ?? ValueKey(move.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l?.deleteCommand ?? 'Delete Command'),
            content: Text(
              l?.deleteCommandConfirm(move.name) ?? 'Delete "${move.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l?.cancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: Text(l?.delete ?? 'Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          ref.read(quickMoveProvider.notifier).deleteMove(move.id);
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(move.icon, size: 18, color: move.color),
        title: Text(
          '/${move.name}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: move.promptTemplate.length > 40
            ? Text(
                '${move.promptTemplate.substring(0, 40)}...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              )
            : Text(
                move.promptTemplate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              move.type == QuickMoveType.preset ? 'Preset' : 'Custom',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Move Up',
              onPressed: canMoveUp
                  ? () => ref
                      .read(quickMoveProvider.notifier)
                      .reorderMove(move.id, index - 1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Move Down',
              onPressed: canMoveDown
                  ? () => ref
                      .read(quickMoveProvider.notifier)
                      .reorderMove(move.id, index + 1)
                  : null,
            ),
          ],
        ),
        onTap: () => _showEditQuickMoveDialog(context, ref, move),
      ),
    );
  }
}

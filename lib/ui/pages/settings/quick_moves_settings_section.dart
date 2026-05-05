import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/quick_move_service.dart';
import '../../../data/models/quick_move.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/create_quick_move_dialog.dart';

class QuickMovesSettingsSection extends ConsumerWidget {
  const QuickMovesSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickMoveState = ref.watch(quickMoveProvider);
    final theme = Theme.of(context);

    return SettingsSection(
      title: 'Quick Moves',
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
                    onPressed: () => showCreateQuickMoveDialog(
                      context,
                      ref,
                    ),
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
                          title: const Text('恢复默认命令'),
                          content: const Text('将恢复所有已删除的预设命令，不会影响你创建的命令。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('恢复'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref
                            .read(quickMoveProvider.notifier)
                            .restoreDefaults();
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
                                success ? '导入成功' : '导入失败，请检查文件格式',
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
                        Icon(Icons.bolt,
                            size: 32, color: theme.hintColor),
                        const SizedBox(height: 8),
                        Text(
                          'No quick moves yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => showCreateQuickMoveDialog(
                            context,
                            ref,
                          ),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Create your first quick move'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: quickMoveState.moves.length,
                  onReorder: (oldIndex, newIndex) {
                    final move = quickMoveState.moves[oldIndex];
                    ref
                        .read(quickMoveProvider.notifier)
                        .reorderMove(move.id, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final move = quickMoveState.moves[index];
                    return _buildMoveTile(
                      context,
                      ref,
                      theme,
                      move,
                      key: ValueKey(move.id),
                    );
                  },
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
    Key? key,
  }) {
    return Dismissible(
      key: key ?? ValueKey(move.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除命令'),
            content: Text('确定删除命令 "${move.name}" 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: const Text('删除'),
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
        leading: Icon(
          move.icon,
          size: 18,
          color: move.color,
        ),
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
                  fontSize: 11,
                ),
              )
            : Text(
                move.promptTemplate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontSize: 11,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              move.type == QuickMoveType.preset ? 'Preset' : 'Custom',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.drag_handle, size: 16, color: theme.hintColor),
          ],
        ),
        onTap: () => _editQuickMove(context, ref, move),
      ),
    );
  }

  void _editQuickMove(
    BuildContext context,
    WidgetRef ref,
    QuickMove move,
  ) {
    final nameController = TextEditingController(text: move.name);
    final promptController =
        TextEditingController(text: move.promptTemplate);
    var iconCodePoint = move.iconCodePoint;
    var colorValue = move.colorValue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: const Text('Edit Quick Move'),
            contentPadding:
                const EdgeInsets.fromLTRB(24, 16, 24, 0),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Command Name',
                        prefixText: '/',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: promptController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Prompt Template',
                        helperText:
                            'Supported: {input}, {pageContent}, {selectedText}, {pageUrl}, {noteContent}',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Icon',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _iconOptions.map((icon) {
                        final isSelected =
                            icon.codePoint == iconCodePoint;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              iconCodePoint = icon.codePoint;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(colorValue)
                                      .withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: Color(colorValue),
                                      width: 2,
                                    )
                                  : Border.all(
                                      color: Colors.transparent),
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: isSelected
                                  ? Color(colorValue)
                                  : theme.hintColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Color',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _colorOptions.map((colorVal) {
                        final isSelected = colorVal == colorValue;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              colorValue = colorVal;
                            });
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(colorVal)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final prompt = promptController.text.trim();
                  if (name.isEmpty || prompt.isEmpty) return;

                  ref.read(quickMoveProvider.notifier).updateMove(
                        move.id,
                        name: name,
                        promptTemplate: prompt,
                        iconCodePoint: iconCodePoint,
                        colorValue: colorValue,
                      );
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _iconOptions = [
  Icons.translate,
  Icons.summarize,
  Icons.psychology,
  Icons.mail,
  Icons.spellcheck,
  Icons.bolt,
  Icons.star,
  Icons.favorite,
  Icons.lightbulb,
  Icons.auto_awesome,
  Icons.search,
  Icons.code,
  Icons.edit,
  Icons.share,
  Icons.bookmark,
];

const _colorOptions = [
  0xFF0EA5E9,
  0xFF8B5CF6,
  0xFFF43F5E,
  0xFF10B981,
  0xFFF59E0B,
  0xFF6366F1,
  0xFF14B8A6,
  0xFFF97316,
  0xFF64748B,
];

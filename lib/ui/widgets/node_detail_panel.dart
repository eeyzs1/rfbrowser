import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/knowledge_service.dart';
import '../theme/design_tokens.dart';

class NodeDetailPanel extends ConsumerWidget {
  final VoidCallback? onClose;
  const NodeDetailPanel({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final knowledgeState = ref.watch(knowledgeProvider);
    final activeNote = knowledgeState.activeNote;

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    activeNote != null ? '节点详情' : '节点详情',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: Icon(Icons.chevron_right, size: 16, color: theme.hintColor),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: '关闭面板',
                  ),
              ],
            ),
          ),
          Expanded(
            child: activeNote == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hub,
                          size: 32,
                          color: theme.hintColor.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: DesignSpacing.sm),
                        Text(
                          '点击图谱节点查看详情',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeNote.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _infoRow(theme, Icons.label_outline, 'ID', activeNote.id),
                        if (activeNote.tags.isNotEmpty)
                          _infoRow(theme, Icons.tag, '标签', activeNote.tags.join(', ')),
                        _infoRow(theme, Icons.link, '反向链接', '${knowledgeState.backlinks.length}'),
                        _infoRow(theme, Icons.access_time, '修改时间', _formatDate(activeNote.modified)),
                        const SizedBox(height: 12),
                        Text(
                          '内容预览',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            activeNote.content.length > 300
                                ? '${activeNote.content.substring(0, 300)}...'
                                : activeNote.content,
                            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: theme.hintColor),
          const SizedBox(width: 4),
          Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
            fontSize: 11,
          )),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

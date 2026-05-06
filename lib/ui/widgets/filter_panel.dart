import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/knowledge_service.dart';
import '../theme/design_tokens.dart';

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final knowledgeState = ref.watch(knowledgeProvider);
    final noteCount = knowledgeState.notes.length;

    return Container(
      padding: const EdgeInsets.all(DesignSpacing.md),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '筛选',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: DesignSpacing.md),
          _FilterOption(
            icon: Icons.description_outlined,
            label: '所有笔记',
            count: noteCount,
            isActive: true,
          ),
          _FilterOption(
            icon: Icons.link,
            label: '有链接',
            count: -1,
          ),
          _FilterOption(
            icon: Icons.attach_file,
            label: '有附件',
            count: -1,
          ),
          _FilterOption(
            icon: Icons.tag,
            label: '标签',
            count: -1,
          ),
          const Spacer(),
          Text(
            '$noteCount 条笔记',
            style: TextStyle(
              fontSize: 11,
              color: theme.hintColor,
            ),
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

  const _FilterOption({
    required this.icon,
    required this.label,
    required this.count,
    this.isActive = false,
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
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.sm,
              vertical: DesignSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: theme.hintColor),
                const SizedBox(width: DesignSpacing.sm),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
                const Spacer(),
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
                      style: TextStyle(fontSize: 10, color: theme.hintColor),
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

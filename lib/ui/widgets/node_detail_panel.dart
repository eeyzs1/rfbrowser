import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/design_tokens.dart';

class NodeDetailPanel extends ConsumerWidget {
  const NodeDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Center(
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
      ),
    );
  }
}

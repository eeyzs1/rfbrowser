import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/design_tokens.dart';

class EmptyVaultGuide extends ConsumerWidget {
  final VoidCallback? onCreateVault;

  const EmptyVaultGuide({super.key, this.onCreateVault});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(DesignSpacing.xxl),
        margin: const EdgeInsets.all(DesignSpacing.xxl),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(DesignRadius.xl),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: DesignSpacing.lg),
            Text(
              '欢迎使用 RFBrowser',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: DesignSpacing.sm),
            Text(
              '打开知识库文件夹开始探索和学习',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: DesignSpacing.xl),
            FilledButton.icon(
              onPressed: onCreateVault,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('打开知识库'),
            ),
            const SizedBox(height: DesignSpacing.md),
            Text(
              '支持 Obsidian 兼容的 Markdown 文件',
              style: TextStyle(
                fontSize: 11,
                color: theme.hintColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

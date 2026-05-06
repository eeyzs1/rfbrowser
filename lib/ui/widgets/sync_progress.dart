import 'package:flutter/material.dart';
import '../../data/models/sync_conflict.dart';

class SyncProgressWidget extends StatelessWidget {
  final SyncProgress progress;
  final VoidCallback? onCancel;

  const SyncProgressWidget({super.key, required this.progress, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progress.isUploading ? 'Uploading...' : 'Downloading...',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${progress.filesProcessed}/${progress.totalFiles}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: onCancel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          if (progress.currentFile.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              progress.currentFile,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

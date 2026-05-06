import 'package:flutter/material.dart';
import '../../data/models/sync_conflict.dart';

class SyncConflictDialog extends StatelessWidget {
  final SyncConflict conflict;
  final void Function(ConflictResolution) onResolve;

  const SyncConflictDialog({
    super.key,
    required this.conflict,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: theme.colorScheme.tertiary, size: 20),
          const SizedBox(width: 8),
          const Text('Sync Conflict'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Both local and remote versions have been modified:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'File',
              value: conflict.relativePath.split('/').last,
              icon: Icons.description,
            ),
            if (conflict.localModified != null)
              _InfoRow(
                label: 'Local modified',
                value: _formatDate(conflict.localModified!),
                icon: Icons.computer,
              ),
            if (conflict.remoteModified != null)
              _InfoRow(
                label: 'Remote modified',
                value: _formatDate(conflict.remoteModified!),
                icon: Icons.cloud,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => onResolve(ConflictResolution.keepLocal),
          child: const Text('Keep Local'),
        ),
        TextButton(
          onPressed: () => onResolve(ConflictResolution.keepRemote),
          child: const Text('Keep Remote'),
        ),
        FilledButton(
          onPressed: () => onResolve(ConflictResolution.keepBoth),
          child: const Text('Keep Both'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.hintColor),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const Spacer(),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

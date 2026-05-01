import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/stores/vault_store.dart';

class WelcomePage extends ConsumerWidget {
  final VoidCallback onVaultOpened;

  const WelcomePage({super.key, required this.onVaultOpened});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'RFBrowser',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 36,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI-Powered Knowledge Browser',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openVault(context, ref),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open Vault'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => _createVault(context, ref),
                    icon: const Icon(Icons.create_new_folder),
                    label: const Text('Create Vault'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              if (vaultState.recentVaults.isNotEmpty) ...[
                const SizedBox(height: 48),
                Text(
                  'Recent Vaults',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...vaultState.recentVaults.map(
                  (vault) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(vault.name),
                      subtitle: Text(vault.path),
                      trailing: Text(
                        _formatDate(vault.lastOpened),
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () async {
                        await ref
                            .read(vaultProvider.notifier)
                            .openVault(vault.path);
                        onVaultOpened();
                      },
                    ),
                  ),
                ),
              ],
              if (vaultState.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          vaultState.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVault(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Vault Location',
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).openVault(result);
      onVaultOpened();
    }
  }

  Future<void> _createVault(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Vault Location',
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).createVault(result);
      onVaultOpened();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

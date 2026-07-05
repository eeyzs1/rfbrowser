import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/stores/vault_store.dart';
import '../../services/browser_service.dart';
import '../../l10n/app_localizations.dart';

part 'welcome_page_recent_vaults.dart';

// ignore: unused_element
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

class WelcomePage extends ConsumerWidget {
  final VoidCallback onVaultOpened;

  const WelcomePage({super.key, required this.onVaultOpened});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text(l.appName, style: theme.textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(
                  l.appSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l.vaultExplanation,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openVault(context, ref),
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text(l.openVault),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _createVault(context, ref),
                      icon: const Icon(Icons.create_new_folder, size: 18),
                      label: Text(l.createVault),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                if (vaultState.recentVaults.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  Expanded(
                    child: _RecentVaultsList(
                      vaults: vaultState.recentVaults,
                      onSelect: (vault) async {
                        await ref
                            .read(vaultProvider.notifier)
                            .openVault(vault.path);
                        onVaultOpened();
                      },
                      onRemove: (vault) =>
                          _confirmAndRemove(context, ref, vault),
                    ),
                  ),
                ],
                if (vaultState.error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: vaultState.error!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAndRemove(
    BuildContext context,
    WidgetRef ref,
    VaultConfig vault,
  ) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.removeVault),
        content: Text(l.removeVaultConfirm(vault.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vaultProvider.notifier).removeFromRecent(vault.path);
            },
            child: Text(l.remove),
          ),
        ],
      ),
    );
  }

  Future<void> _openVault(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l.selectVault,
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).openVault(result);
      ref.read(browserProvider.notifier).loadBookmarks();
      onVaultOpened();
    }
  }

  Future<void> _createVault(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l.selectVault,
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).createVault(result);
      onVaultOpened();
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/stores/vault_store.dart';
import '../../../plugins/host/plugin_host.dart';
import '../../../plugins/plugin_registry.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/plugin_install_dialog.dart';
import '../../widgets/plugin_marketplace_page.dart';

part 'plugin_settings_card.dart';

class PluginSettingsSection extends ConsumerWidget {
  const PluginSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pluginHostProvider);
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pluginIds = state.manifests.keys.toList();

    return SettingsSection(
      title: l.plugins,
      children: [
        const SizedBox(height: 4),
        if (pluginIds.isEmpty)
          _buildEmptyState(context, theme, l)
        else
          ...pluginIds.map(
            (id) => _PluginCard(
              pluginId: id,
              manifest: state.manifests[id]!,
              isRunning: state.running[id] == true,
              isEnabled: state.enabled[id] == true,
              isBuiltin: PluginRegistry.findById(id) != null,
              commands: state.commands[id] ?? [],
              hasError: state.error != null,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: OutlinedButton.icon(
                  onPressed: () {
                    final vaultState = ref.read(vaultProvider);
                    final vault = vaultState.currentVault;
                    if (vault != null) {
                      final host = ref.read(pluginHostProvider.notifier);
                      PluginInstallDialog.show(context, vault.path, host);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.extrazerodoNoVault),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(l.extrazerodoInstallBtn),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: () {
                  final vaultState = ref.read(vaultProvider);
                  final vault = vaultState.currentVault;
                  if (vault != null) {
                    final host = ref.read(pluginHostProvider.notifier);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PluginMarketplacePage(
                          vaultPath: vault.path,
                          host: host,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.store, size: 18),
                label: Text(l.extrazerodoMarketplace),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.extension_off,
            size: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            l.extrazerodoDesc,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/webhook_server.dart';
import '../../widgets/settings_section.dart';

class AgentSettingsSection extends ConsumerStatefulWidget {
  const AgentSettingsSection({super.key});

  @override
  ConsumerState<AgentSettingsSection> createState() =>
      _AgentSettingsSectionState();
}

class _AgentSettingsSectionState extends ConsumerState<AgentSettingsSection> {
  final _portController = TextEditingController(text: '18765');

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  /// Persist the port change to the provider and, if the webhook is currently
  /// running, restart it on the new port so the change takes effect immediately.
  Future<void> _onPortChanged(int newPort) async {
    final notifier = ref.read(webhookServerProvider.notifier);
    final wasRunning = ref.read(webhookServerProvider).isRunning;
    notifier.setPort(newPort);
    if (!wasRunning) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.restartingWebhook),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    try {
      await notifier.stop();
      await notifier.start(port: newPort);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n?.webhookRestartFailed ?? "Restart failed:"} $e',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final webhookState = ref.watch(webhookServerProvider);

    return SettingsSection(
      title: l10n.agent,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.http),
          title: Text(l10n.webhookServerTitle),
          subtitle: Text(
            webhookState.isRunning
                ? l10n.webhookServerRunning(webhookState.baseUrl ?? '')
                : l10n.webhookServerStopped,
            style: webhookState.isRunning
                ? theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade700,
                  )
                : null,
          ),
          value: webhookState.isRunning,
          onChanged: (val) async {
            if (val) {
              final port = int.tryParse(_portController.text) ?? 18765;
              await ref.read(webhookServerProvider.notifier).start(port: port);
            } else {
              await ref.read(webhookServerProvider.notifier).stop();
            }
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.numbers),
          title: Text(l10n.webhookServerPort),
          trailing: SizedBox(
            width: 100,
            child: TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                final p = int.tryParse(v.trim());
                if (p != null && p > 0 && p < 65536) {
                  _onPortChanged(p);
                }
              },
            ),
          ),
        ),
        if (webhookState.apiKey != null) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.key),
            title: Text(l10n.webhookServerApiKey),
            subtitle: Text(
              _maskKey(webhookState.apiKey!),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: l10n.webhookServerCopyKey,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: webhookState.apiKey!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.webhookServerApiKeyCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
        if (webhookState.isRunning && webhookState.baseUrl != null) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('URL'),
            subtitle: Text(
              webhookState.baseUrl!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: webhookState.baseUrl!));
              },
            ),
          ),
        ],
      ],
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return key;
    return '${key.substring(0, 4)}${'•' * (key.length - 8)}${key.substring(key.length - 4)}';
  }
}

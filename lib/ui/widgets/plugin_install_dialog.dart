import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../plugins/plugin_registry.dart';
import '../../../plugins/host/plugin_host.dart';

class PluginInstallDialog extends ConsumerStatefulWidget {
  final String vaultPath;
  final PluginHostNotifier host;

  const PluginInstallDialog({
    super.key,
    required this.vaultPath,
    required this.host,
  });

  static Future<void> show(
    BuildContext context,
    String vaultPath,
    PluginHostNotifier host,
  ) {
    return showDialog(
      context: context,
      builder: (_) => PluginInstallDialog(vaultPath: vaultPath, host: host),
    );
  }

  @override
  ConsumerState<PluginInstallDialog> createState() =>
      _PluginInstallDialogState();
}

class _PluginInstallDialogState extends ConsumerState<PluginInstallDialog> {
  final _urlController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l.extrazerodoInstallDialogTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.extrazerodoInstallDialogDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: l.extrazerodoInstallUrlHint,
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              enabled: !_loading,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _install,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 18),
          label: Text(
            _loading ? l.extrazerodoInstalling : l.extrazerodoInstallBtn,
          ),
        ),
      ],
    );
  }

  Future<void> _install() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final l = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.of(context);
      final manifest = await PluginRegistry.installFromGit(
        url,
        widget.vaultPath,
      );
      if (!mounted) return;
      if (manifest != null) {
        await widget.host.registerManifestAndEnable(
          manifest,
          enabledByDefault: false,
        );
        messenger.showSnackBar(
          SnackBar(content: Text(l.extrazerodoInstalled(manifest.name))),
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
}

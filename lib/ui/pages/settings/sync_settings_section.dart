import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/git_sync_service.dart';
import '../../../services/webdav_sync_service.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/settings_dialogs.dart';

class SyncSettingsSection extends ConsumerWidget {
  const SyncSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final webdavState = ref.watch(webdavSyncProvider);
    final gitService = ref.watch(gitSyncProvider);

    return SettingsSection(
      title: l.syncSection,
      children: [
        ListTile(
          title: Text(l.gitSync),
          subtitle: Text(l.configureGitRemote),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showGitConfigDialog(context, ref, l, gitService),
        ),
        ListTile(
          title: Text(l.webdavSync),
          subtitle: Text(
            webdavState.serverUrl == null
                ? l.configureWebdav
                : '${webdavState.serverUrl}'
                      '${webdavState.username != null ? '  •  ${webdavState.username}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showWebdavConfigDialog(context, ref, l, webdavState),
        ),
      ],
    );
  }

  Future<void> _showGitConfigDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    GitSyncService? gitService,
  ) async {
    if (gitService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.vaultRequiredForSync),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    String? currentRemote;
    try {
      currentRemote = await gitService.getRemoteUrl();
    } catch (_) {
      currentRemote = null;
    }

    if (!context.mounted) return;
    final result = await showMultiFieldDialog(
      context: context,
      title: l.gitSyncConfig,
      fields: [
        DialogFieldConfig(
          key: 'url',
          labelText: l.remoteUrl,
          hintText: 'https://github.com/user/vault.git',
          initialValue: currentRemote,
        ),
      ],
    );

    if (result == null || result['url'] == null) return;
    final url = result['url']!.trim();
    if (url.isEmpty) return;

    try {
      await gitService.init(url);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.gitRemoteSaveFailed} $e'),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.gitRemoteSaved),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showWebdavConfigDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    WebDAVSyncState current,
  ) async {
    final result = await showMultiFieldDialog(
      context: context,
      title: l.webdavConfig,
      fields: [
        DialogFieldConfig(
          key: 'url',
          labelText: l.serverUrl,
          hintText: 'https://dav.example.com/',
          initialValue: current.serverUrl,
        ),
        DialogFieldConfig(
          key: 'username',
          labelText: l.username,
          initialValue: current.username,
        ),
        DialogFieldConfig(
          key: 'password',
          labelText: l.password,
          obscureText: true,
          hintText: current.isPasswordSet ? '••••••••' : null,
        ),
      ],
    );

    if (result == null) return;
    final url = result['url']?.trim() ?? '';
    final username = result['username']?.trim() ?? '';
    final password = result['password'] ?? '';

    if (url.isEmpty || username.isEmpty) return;

    ref
        .read(webdavSyncProvider.notifier)
        .configure(serverUrl: url, username: username, password: password);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.webdavConfigSaved),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

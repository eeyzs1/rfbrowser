import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/settings_dialogs.dart';

class SyncSettingsSection extends ConsumerWidget {
  const SyncSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.syncSection,
      children: [
        ListTile(
          title: Text(l.gitSync),
          subtitle: Text(l.configureGitRemote),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showGitConfigDialog(context, l),
        ),
        ListTile(
          title: Text(l.webdavSync),
          subtitle: Text(l.configureWebdav),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showWebdavConfigDialog(context, l),
        ),
      ],
    );
  }

  void _showGitConfigDialog(BuildContext context, AppLocalizations l) {
    showMultiFieldDialog(
      context: context,
      title: l.gitSyncConfig,
      fields: [
        DialogFieldConfig(
          key: 'url',
          labelText: l.remoteUrl,
          hintText: 'https://github.com/user/vault.git',
        ),
      ],
    );
  }

  void _showWebdavConfigDialog(BuildContext context, AppLocalizations l) {
    showMultiFieldDialog(
      context: context,
      title: l.webdavConfig,
      fields: [
        DialogFieldConfig(
          key: 'url',
          labelText: l.serverUrl,
          hintText: 'https://dav.example.com/',
        ),
        DialogFieldConfig(
          key: 'username',
          labelText: l.username,
        ),
        DialogFieldConfig(
          key: 'password',
          labelText: l.password,
          obscureText: true,
        ),
      ],
    );
  }
}

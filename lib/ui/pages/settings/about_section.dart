import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/settings_section.dart';

/// Keep in sync with `pubspec.yaml` (version: MAJOR.MINOR.PATCH+BUILD).
/// To make this fully dynamic without adding a dependency, see
/// `scripts/sync-app-version.ps1` (planned).
const String _kAppVersion = '0.3.0';
const String _kAppBuild = '3';
const String _kAppDescription = 'AI-Powered Knowledge Browser';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.about,
      children: [
        ListTile(
          leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
          title: const Text('RFBrowser'),
          subtitle: Text('v$_kAppVersion+$_kAppBuild • $_kAppDescription'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l.license),
          subtitle: const Text('MIT License'),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('GitHub'),
          subtitle: const Text('github.com/rfbrowser/rfbrowser'),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Open github.com/rfbrowser/rfbrowser'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/settings_section.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.about,
      children: [
        const ListTile(
          title: Text('RFBrowser'),
          subtitle: Text('v0.2.0 - AI-Powered Knowledge Browser'),
        ),
        ListTile(title: Text(l.license), subtitle: const Text('MIT License')),
      ],
    );
  }
}

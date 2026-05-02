import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';

class EditorSettingsSection extends ConsumerWidget {
  const EditorSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.editorSection,
      children: [
        SwitchListTile(
          title: Text(l.alwaysShowWelcomePage),
          subtitle: Text(l.alwaysShowWelcomePageDesc),
          value: settings.alwaysShowWelcomePage,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setAlwaysShowWelcomePage(v),
        ),
        ListTile(
          title: Text(l.fontSize),
          subtitle: Text('${settings.editorFontSize.toInt()}px'),
          trailing: SizedBox(
            width: 200,
            child: Slider(
              value: settings.editorFontSize,
              min: 8,
              max: 48,
              divisions: 40,
              label: '${settings.editorFontSize.toInt()}px',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setEditorFontSize(v),
            ),
          ),
        ),
      ],
    );
  }
}

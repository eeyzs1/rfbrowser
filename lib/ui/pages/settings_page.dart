import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'settings/theme_settings_section.dart';
import 'settings/component_settings_section.dart';
import 'settings/language_settings_section.dart';
import 'settings/ai_settings_section.dart';
import 'settings/editor_settings_section.dart';
import 'settings/shortcut_settings_section.dart';
import 'settings/sync_settings_section.dart';
import 'settings/quick_moves_settings_section.dart';
import 'settings/about_section.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          QuickMovesSettingsSection(),
          SizedBox(height: 20),
          ThemeSettingsSection(),
          SizedBox(height: 20),
          ComponentSettingsSection(),
          SizedBox(height: 20),
          LanguageSettingsSection(),
          SizedBox(height: 20),
          AISettingsSection(),
          SizedBox(height: 20),
          EditorSettingsSection(),
          SizedBox(height: 20),
          ShortcutSettingsSection(),
          SizedBox(height: 20),
          SyncSettingsSection(),
          SizedBox(height: 20),
          AboutSection(),
        ],
      ),
    );
  }
}

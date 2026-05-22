import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'settings/theme_settings_section.dart';
import 'settings/component_settings_section.dart';
import 'settings/language_settings_section.dart';
import 'settings/ai_settings_section.dart';
import 'settings/agent_settings_section.dart';
import 'settings/editor_settings_section.dart';
import 'settings/shortcut_settings_section.dart';
import 'settings/sync_settings_section.dart';
import 'settings/plugin_settings_section.dart';
import 'settings/quick_moves_settings_section.dart';
import 'settings/about_section.dart';
import 'skills_management_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CategoryHeader(title: l.settingsCategoryGeneral),
          const SizedBox(height: 8),
          const ThemeSettingsSection(),
          const SizedBox(height: 16),
          const ComponentSettingsSection(),
          const SizedBox(height: 16),
          const LanguageSettingsSection(),
          const SizedBox(height: 16),
          const EditorSettingsSection(),
          const SizedBox(height: 16),
          const QuickMovesSettingsSection(),
          const SizedBox(height: 24),
          _CategoryHeader(title: l.settingsCategoryAI),
          const SizedBox(height: 8),
          const AISettingsSection(),
          const SizedBox(height: 16),
          const AgentSettingsSection(),
          const SizedBox(height: 16),
          _SkillsSettingsTile(),
          const SizedBox(height: 16),
          const ShortcutSettingsSection(),
          const SizedBox(height: 24),
          _CategoryHeader(title: l.settingsCategoryAdvanced),
          const SizedBox(height: 8),
          const SyncSettingsSection(),
          const SizedBox(height: 16),
          const PluginSettingsSection(),
          const SizedBox(height: 16),
          const AboutSection(),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;

  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsSettingsTile extends ConsumerWidget {
  const _SkillsSettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Icon(Icons.auto_awesome,
            size: 18, color: theme.colorScheme.primary),
      ),
      title: Text(l.skills),
      subtitle: Text(
        l.extrazerodoSkillEmptyHint,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const SkillsManagementPage()),
        );
      },
    );
  }
}

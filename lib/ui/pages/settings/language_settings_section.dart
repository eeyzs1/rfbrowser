import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/settings_dialogs.dart';

class LanguageSettingsSection extends ConsumerWidget {
  const LanguageSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 用 select 只 watch locale 字段（参见 editor_settings_section.dart 中的
    // 详细注释）。本 section 只在 locale 真正变化时重建。
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    final l = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l.language,
      children: [
        ListTile(
          title: Text(l.language),
          subtitle: Text(_localeLabel(locale, l)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, ref, locale, l),
        ),
      ],
    );
  }

  String _localeLabel(String locale, AppLocalizations l) {
    return switch (locale) {
      'zh' => l.chinese,
      'en' => l.english,
      _ => l.followSystem,
    };
  }

  void _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
    AppLocalizations l,
  ) {
    showSelectionDialog<String>(
      context: context,
      title: l.selectLanguage,
      selectedValue: current,
      options: [
        SelectionOption(value: 'system', label: l.followSystem),
        SelectionOption(value: 'en', label: l.english),
        SelectionOption(value: 'zh', label: l.chinese),
      ],
    ).then((value) {
      if (value != null) {
        ref.read(settingsProvider.notifier).setLocale(value);
      }
    });
  }
}

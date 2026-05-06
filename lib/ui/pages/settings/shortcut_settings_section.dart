import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/shortcut_service.dart';
import '../../widgets/settings_section.dart';

final shortcutServiceProvider = Provider<ShortcutService>((ref) {
  final service = ShortcutService();
  service.load();
  return service;
});

class ShortcutSettingsSection extends ConsumerStatefulWidget {
  const ShortcutSettingsSection({super.key});

  @override
  ConsumerState<ShortcutSettingsSection> createState() =>
      _ShortcutSettingsSectionState();
}

class _ShortcutSettingsSectionState
    extends ConsumerState<ShortcutSettingsSection> {
  late ShortcutService _service;
  String? _editingAction;

  @override
  void initState() {
    super.initState();
    _service = ref.read(shortcutServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SettingsSection(
      title: l.shortcuts,
      children: [
        ..._service.allBindings.entries.map((entry) {
          final isEditing = _editingAction == entry.key;
          return ListTile(
            title: Text(_actionLabel(entry.key, l)),
            subtitle: isEditing
                ? Text(
                    l.pressNewShortcut,
                    style: TextStyle(color: theme.colorScheme.primary),
                  )
                : null,
            trailing: isEditing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _editingAction = null),
                        child: Text(l.cancel),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.value,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: () =>
                            setState(() => _editingAction = entry.key),
                        tooltip: l.edit,
                      ),
                    ],
                  ),
            onTap: isEditing
                ? null
                : () => setState(() => _editingAction = entry.key),
          );
        }),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.restore, size: 18, color: theme.hintColor),
          title: Text(l.resetToDefaults),
          onTap: _resetToDefaults,
        ),
      ],
    );
  }

  String _actionLabel(String action, AppLocalizations l) {
    return switch (action) {
      'new_note' => l.newNote,
      'save' => l.save,
      'search' => l.search,
      'toggle_editor' => l.editor,
      'toggle_browser' => l.browser,
      'toggle_graph' => l.graph,
      'daily_note' => l.dailyNotes,
      'toggle_preview' => l.preview,
      'settings' => l.settings,
      'find' => l.search,
      _ => action,
    };
  }

  void _resetToDefaults() {
    setState(() {
      _service.resetToDefaults();
      _editingAction = null;
    });
    _service.persist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.shortcutsReset)),
    );
  }
}

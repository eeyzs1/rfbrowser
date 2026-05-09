import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/design_tokens.dart';
import '../pages/settings_page.dart';
import '../../data/stores/vault_store.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import 'scene_scaffold.dart';
import '../../../l10n/app_localizations.dart';

class SceneSwitcher extends ConsumerStatefulWidget {
  final SceneType currentScene;
  final ValueChanged<SceneType> onSceneChanged;

  const SceneSwitcher({
    super.key,
    required this.currentScene,
    required this.onSceneChanged,
  });

  @override
  ConsumerState<SceneSwitcher> createState() => _SceneSwitcherState();
}

class _SceneSwitcherState extends ConsumerState<SceneSwitcher> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final vaultState = ref.watch(vaultProvider);
    final vaultName = vaultState.currentVault?.name ?? 'No Vault';
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.lg),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.explore, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text('RFBrowser', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          const SizedBox(width: 8),
          _VaultSwitcher(vaultName: vaultName),
          const Spacer(),
          _SceneButton(scene: SceneType.capture, icon: Icons.explore, label: l.capture, shortcut: 'Ctrl+1', isActive: widget.currentScene == SceneType.capture, onTap: () => widget.onSceneChanged(SceneType.capture)),
          const SizedBox(width: DesignSpacing.xs),
          _SceneButton(scene: SceneType.think, icon: Icons.edit_note, label: l.think, shortcut: 'Ctrl+2', isActive: widget.currentScene == SceneType.think, onTap: () => widget.onSceneChanged(SceneType.think)),
          const SizedBox(width: DesignSpacing.xs),
          _SceneButton(scene: SceneType.connect, icon: Icons.hub, label: l.connect, shortcut: 'Ctrl+3', isActive: widget.currentScene == SceneType.connect, onTap: () => widget.onSceneChanged(SceneType.connect)),
          const SizedBox(width: DesignSpacing.xs),
          _SettingsButton(),
        ],
      ),
    );
  }
}

class _VaultSwitcher extends ConsumerStatefulWidget {
  final String vaultName;
  const _VaultSwitcher({required this.vaultName});

  @override
  ConsumerState<_VaultSwitcher> createState() => _VaultSwitcherState();
}

class _VaultSwitcherState extends ConsumerState<_VaultSwitcher> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _showVaultMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _isHovered ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open, size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(widget.vaultName, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
              Icon(Icons.arrow_drop_down, size: 12, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showVaultMenu(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vaultState = ref.read(vaultProvider);
    final theme = Theme.of(context);
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.folder_open, size: 14, color: theme.hintColor), const SizedBox(width: 8), Text(l.openOtherVault)])),
      PopupMenuItem(value: 'new', child: Row(children: [Icon(Icons.create_new_folder, size: 14, color: theme.hintColor), const SizedBox(width: 8), Text(l.createNewVault)])),
    ];
    if (vaultState.recentVaults.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.add(PopupMenuItem(enabled: false, height: 24, child: Text(l.recentlyOpened, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.hintColor))));
      for (final vault in vaultState.recentVaults.take(5)) {
        final isCurrent = vaultState.currentVault?.path == vault.path;
        items.add(PopupMenuItem(
          value: 'vault:${vault.path}',
          child: Row(children: [
            Icon(isCurrent ? Icons.folder_special : Icons.folder, size: 14, color: isCurrent ? theme.colorScheme.primary : theme.hintColor),
            const SizedBox(width: 8),
            Expanded(child: Text(vault.name, style: isCurrent ? TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600) : null, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ));
      }
    }
    showMenu(context: context, position: RelativeRect.fromLTRB(10, 44, 200, 0), items: items).then((value) async {
      if (value == null) return;
      if (value == 'open') {
        final result = await FilePicker.platform.getDirectoryPath(dialogTitle: l.selectVaultLocation);
        if (result != null) {
          await ref.read(vaultProvider.notifier).openVault(result);
          ref.read(knowledgeProvider.notifier).loadAllNotes();
          ref.read(browserProvider.notifier).loadBookmarks();
        }
      } else if (value == 'new') {
        final result = await FilePicker.platform.getDirectoryPath(dialogTitle: l.selectVaultLocation);
        if (result != null) {
          await ref.read(vaultProvider.notifier).createVault(result);
          ref.read(knowledgeProvider.notifier).loadAllNotes();
          ref.read(browserProvider.notifier).loadBookmarks();
        }
      } else if (value.startsWith('vault:')) {
        final path = value.substring(6);
        await ref.read(vaultProvider.notifier).openVault(path);
        ref.read(knowledgeProvider.notifier).loadAllNotes();
        ref.read(browserProvider.notifier).loadBookmarks();
      }
    });
  }
}

class _SettingsButton extends StatefulWidget {
  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: _isHovered
          ? theme.colorScheme.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(DesignRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignRadius.sm),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
        onHover: (hovered) => setState(() => _isHovered = hovered),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.settings, size: 18),
        ),
      ),
    );
  }
}

class _SceneButton extends StatefulWidget {
  final SceneType scene;
  final IconData icon;
  final String label;
  final String shortcut;
  final bool isActive;
  final VoidCallback onTap;

  const _SceneButton({
    required this.scene,
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SceneButton> createState() => _SceneButtonState();
}

class _SceneButtonState extends State<_SceneButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.isActive;
    final primary = theme.colorScheme.primary;

    return Material(
      color: active
          ? primary.withValues(alpha: 0.15)
          : (_isHovered ? primary.withValues(alpha: 0.05) : Colors.transparent),
      borderRadius: BorderRadius.circular(DesignRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignRadius.sm),
        onTap: active ? null : widget.onTap,
        onHover: (hovered) => setState(() => _isHovered = hovered),
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.sm,
            vertical: 2,
          ),
          decoration: active
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: primary, width: 2),
                  ),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: active ? primary : theme.colorScheme.onSurfaceVariant,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.shortcut,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: active
                          ? primary.withValues(alpha: 0.6)
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

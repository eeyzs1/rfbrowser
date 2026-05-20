import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/design_tokens.dart';
import '../pages/settings_page.dart';
import '../../data/stores/vault_store.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/shortcut_service.dart';
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
          const SizedBox(width: DesignSpacing.sm),
          Text(
            'RFBrowser',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: DesignSpacing.sm),
          Flexible(child: _VaultSwitcher(vaultName: vaultName)),
          const Spacer(),
          Flexible(
            child: _SceneButton(
              scene: SceneType.capture,
              icon: Icons.explore,
              label: l.capture,
              shortcut: ref.read(shortcutServiceProvider).getShortcut('switch_capture') ?? 'Ctrl+1',
              tooltip: l.captureTooltip,
              isActive: widget.currentScene == SceneType.capture,
              onTap: () => widget.onSceneChanged(SceneType.capture),
            ),
          ),
          const SizedBox(width: DesignSpacing.xs),
          Flexible(
            child: _SceneButton(
              scene: SceneType.think,
              icon: Icons.edit_note,
              label: l.think,
              shortcut: ref.read(shortcutServiceProvider).getShortcut('switch_think') ?? 'Ctrl+2',
              tooltip: l.thinkTooltip,
              isActive: widget.currentScene == SceneType.think,
              onTap: () => widget.onSceneChanged(SceneType.think),
            ),
          ),
          const SizedBox(width: DesignSpacing.xs),
          Flexible(
            child: _SceneButton(
              scene: SceneType.connect,
              icon: Icons.hub,
              label: l.connect,
              shortcut: ref.read(shortcutServiceProvider).getShortcut('switch_connect') ?? 'Ctrl+3',
              tooltip: l.connectTooltip,
              isActive: widget.currentScene == SceneType.connect,
              onTap: () => widget.onSceneChanged(SceneType.connect),
            ),
          ),
          const SizedBox(width: DesignSpacing.xs),
          const _SettingsButton(),
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
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l != null ? '${l.openVault}: ${widget.vaultName}' : 'Vault: ${widget.vaultName}',
      child: Material(
        color: _isHovered
            ? DesignColors.primaryHover
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(DesignRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignRadius.sm),
          onTap: () => _showVaultMenu(context),
          onHover: (hovered) => setState(() => _isHovered = hovered),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.sm,
              vertical: DesignSpacing.sm,
            ),
            constraints: const BoxConstraints(minHeight: DesignTouchTarget.minSize),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: DesignSpacing.xs),
                Flexible(
                  child: Text(
                    widget.vaultName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 14, color: theme.hintColor),
              ],
            ),
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
      PopupMenuItem(
        value: 'open',
        child: Row(
          children: [
            Icon(Icons.folder_open, size: 14, color: theme.hintColor),
            const SizedBox(width: DesignSpacing.sm),
            Text(l.openOtherVault),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'new',
        child: Row(
          children: [
            Icon(Icons.create_new_folder, size: 14, color: theme.hintColor),
            const SizedBox(width: DesignSpacing.sm),
            Text(l.createNewVault),
          ],
        ),
      ),
    ];
    if (vaultState.recentVaults.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.add(
        PopupMenuItem(
          enabled: false,
          height: 24,
          child: Text(
            l.recentlyOpened,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
            ),
          ),
        ),
      );
      for (final vault in vaultState.recentVaults.take(5)) {
        final isCurrent = vaultState.currentVault?.path == vault.path;
        items.add(
          PopupMenuItem(
            value: 'vault:${vault.path}',
            child: Row(
              children: [
                Icon(
                  isCurrent ? Icons.folder_special : Icons.folder,
                  size: 14,
                  color: isCurrent
                      ? theme.colorScheme.primary
                      : theme.hintColor,
                ),
                const SizedBox(width: DesignSpacing.sm),
                Expanded(
                  child: Text(
                    vault.name,
                    style: isCurrent
                        ? TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(10, 44, 200, 0),
      items: items,
    ).then((value) async {
      if (value == null) return;
      if (value == 'open') {
        final result = await FilePicker.platform.getDirectoryPath(
          dialogTitle: l.selectVaultLocation,
        );
        if (result != null) {
          await ref.read(vaultProvider.notifier).openVault(result);
          ref.read(knowledgeProvider.notifier).loadAllNotes();
          ref.read(browserProvider.notifier).loadBookmarks();
        }
      } else if (value == 'new') {
        final result = await FilePicker.platform.getDirectoryPath(
          dialogTitle: l.selectVaultLocation,
        );
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
  const _SettingsButton();

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Settings',
      child: Material(
        color: _isHovered
            ? DesignColors.primaryHover
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
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: Container(
            padding: const EdgeInsets.all(DesignSpacing.sm),
            constraints: const BoxConstraints(
              minWidth: DesignTouchTarget.minSize,
              minHeight: DesignTouchTarget.minSize,
            ),
            decoration: _isFocused
                ? BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(DesignRadius.sm),
                  )
                : null,
            child: const Icon(Icons.settings, size: 18),
          ),
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
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _SceneButton({
    required this.scene,
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SceneButton> createState() => _SceneButtonState();
}

class _SceneButtonState extends State<_SceneButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.isActive;
    final primary = theme.colorScheme.primary;

    return Semantics(
      button: true,
      selected: active,
      label: widget.label,
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: active
              ? DesignColors.primaryMuted
              : (_isHovered ? DesignColors.primaryHover : Colors.transparent),
          borderRadius: BorderRadius.circular(DesignRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(DesignRadius.sm),
            onTap: active ? null : widget.onTap,
            onHover: (hovered) => setState(() => _isHovered = hovered),
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSpacing.md,
                vertical: DesignSpacing.sm,
              ),
              constraints: const BoxConstraints(minHeight: DesignTouchTarget.minSize),
              decoration: BoxDecoration(
                border: _isFocused && !active
                    ? Border.all(color: primary, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(DesignRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: active ? primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: DesignSpacing.xs),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active
                            ? primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: DesignSpacing.xs),
                  Flexible(
                    child: Text(
                      widget.shortcut,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: active
                            ? primary.withValues(alpha: 0.6)
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

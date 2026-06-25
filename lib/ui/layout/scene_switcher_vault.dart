part of 'scene_switcher.dart';

/// Vault switcher button + dropdown menu for the [SceneSwitcher] bar.
///
/// Shows the current vault name and a popup menu with options to open another
/// vault, create a new vault, or switch to one of the recent vaults.
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
      label: l != null
          ? '${l.openVault}: ${widget.vaultName}'
          : 'Vault: ${widget.vaultName}',
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
            constraints: const BoxConstraints(
              minHeight: DesignTouchTarget.minSize,
            ),
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

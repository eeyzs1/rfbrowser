part of '../note_sidebar.dart';

mixin _SidebarVaultMixin on _NoteSidebarStateBase {
  Widget _buildNoVaultPrompt(ThemeData theme, AppLocalizations l) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(DesignSpacing.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.notes,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_off, size: 40, color: theme.hintColor),
                  const SizedBox(height: 12),
                  Text(
                    l.noVaultConnected,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.openVaultToManageNotes,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openVault(),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: Text(l.openVault),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _createVault(),
                    icon: const Icon(Icons.create_new_folder, size: 16),
                    label: Text(l.createVault),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openVault() async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l.selectVaultLocation,
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).openVault(result);
      ref.read(knowledgeProvider.notifier).loadAllNotes();
      ref.read(browserProvider.notifier).loadBookmarks();
      await _scanDiskFolders();
    }
  }

  Future<void> _createVault() async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l.selectVaultLocation,
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).createVault(result);
      ref.read(knowledgeProvider.notifier).loadAllNotes();
      ref.read(browserProvider.notifier).loadBookmarks();
      await _scanDiskFolders();
    }
  }
}

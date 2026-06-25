part of 'welcome_page.dart';

class _RecentVaultsList extends StatelessWidget {
  final List<VaultConfig> vaults;
  final ValueChanged<VaultConfig> onSelect;
  final ValueChanged<VaultConfig> onRemove;

  const _RecentVaultsList({
    required this.vaults,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            l.recentVaults,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(3),
              child: ListView.separated(
                primary: true,
                shrinkWrap: false,
                padding: EdgeInsets.zero,
                itemCount: vaults.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 52,
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
                itemBuilder: (context, index) => _VaultListItem(
                  vault: vaults[index],
                  onTap: () => onSelect(vaults[index]),
                  onRemove: () => onRemove(vaults[index]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VaultListItem extends StatefulWidget {
  final VaultConfig vault;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _VaultListItem({
    required this.vault,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_VaultListItem> createState() => _VaultListItemState();
}

class _VaultListItemState extends State<_VaultListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: _isHovered
            ? theme.colorScheme.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vault.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.vault.path,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(widget.vault.lastOpened, l),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                _IconButton(
                  icon: Icons.close_rounded,
                  tooltip: l.removeVault,
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return l.today;
    if (diff.inDays == 1) return l.yesterday;
    if (diff.inDays < 7) return l.daysAgo(diff.inDays);
    return '${date.month}/${date.day}';
  }
}

class _IconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hovered
                ? theme.colorScheme.error.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: _hovered
                ? theme.colorScheme.error
                : theme.hintColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

part of '../command_bar.dart';

/// Tile builder methods for CommandBar list items.
mixin _CommandBarTilesMixin on _CommandBarStateBase {
  Widget _buildListItem(
    BuildContext context,
    ThemeData theme,
    List<_CommandDef> commands,
    bool showCommands,
    int index,
  ) {
    if (showCommands && index < commands.length) {
      final cmd = commands[index];
      final globalIndex = index;
      return _buildCommandTile(
        theme,
        cmd,
        globalIndex == _selectedIndex,
        () => _selectItem(globalIndex),
      );
    }
    final resultIndex = showCommands ? index - commands.length : index;
    final globalIndex = index;
    if (resultIndex < _results.length) {
      final result = _results[resultIndex];
      return _buildNoteTile(
        theme,
        result,
        globalIndex == _selectedIndex,
        () => _selectItem(globalIndex),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildQuickMoveTile(
    ThemeData theme,
    QuickMove move,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: DesignColors.primarySubtle,
      leading: Icon(move.icon, size: 18, color: move.color),
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(
              '/${move.name}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: move.promptTemplate.length > 60
          ? Text(
              '${move.promptTemplate.substring(0, 60)}...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        move.type == QuickMoveType.preset ? 'Preset' : 'Quick Move',
        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
      ),
    );
  }

  Widget _buildCommandTile(
    ThemeData theme,
    _CommandDef cmd,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: DesignColors.primarySubtle,
      leading: Icon(cmd.icon, size: 18, color: theme.hintColor),
      title: Text(cmd.label, style: theme.textTheme.bodyMedium),
      trailing: Text(
        'Command',
        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
      ),
      onTap: onTap,
    );
  }

  Widget _buildNoteTile(
    ThemeData theme,
    _SearchResult result,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: DesignColors.primarySubtle,
      leading: Icon(
        Icons.description,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              result.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: result.tags.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: DesignSpacing.xs),
              child: Wrap(
                spacing: DesignSpacing.xs,
                children: result.tags
                    .take(3)
                    .map(
                      (tag) => Text(
                        '#$tag',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.source.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSpacing.xs,
                vertical: DesignSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: DesignColors.primarySubtle,
                borderRadius: BorderRadius.circular(DesignRadius.sm),
              ),
              child: Text(
                result.source == 'semantic' ? 'semantic' : 'keyword',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (result.sourceUrl != null) ...[
            const SizedBox(width: DesignSpacing.xs),
            Icon(Icons.language, size: 12, color: theme.hintColor),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

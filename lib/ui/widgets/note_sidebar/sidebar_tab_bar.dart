part of '../note_sidebar.dart';

mixin _SidebarTabBarMixin on _NoteSidebarStateBase {
  Widget _buildTabBar(ThemeData theme, AppLocalizations l) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabBtn(
              theme,
              _SidebarTab.notes,
              Icons.description_outlined,
              Icons.description,
              l.notes,
              ref.watch(knowledgeProvider).notes.length,
            ),
          ),
          Expanded(
            child: _tabBtn(
              theme,
              _SidebarTab.bookmarks,
              Icons.bookmark_border,
              Icons.bookmark,
              l.bookmarks,
              ref.watch(browserProvider).bookmarks.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(
    ThemeData theme,
    _SidebarTab tab,
    IconData icon,
    IconData activeIcon,
    String label,
    int count,
  ) {
    final isActive = _activeTab == tab;
    final primary = theme.colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 14,
                color: isActive ? primary : theme.hintColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: _baseFontSize,
                    color: isActive ? primary : theme.hintColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? primary.withValues(alpha: 0.1)
                        : theme.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: _baseFontSize - 2,
                      color: isActive ? primary : theme.hintColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

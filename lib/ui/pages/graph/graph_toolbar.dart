part of '../graph_page.dart';

/// Builds the graph page toolbar with layout/view mode toggles, zoom controls,
/// and export menu.
mixin _GraphToolbarMixin on _GraphViewStateBase {
  @override
  Widget _buildToolbar(
    ThemeData theme,
    AppLocalizations l,
    List<Note> displayNotes,
    List<GraphLink> displayLinks,
  ) {
    return Positioned(
      top: DesignSpacing.md,
      left: DesignSpacing.md,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.md,
          vertical: DesignSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(DesignRadius.md),
          boxShadow: [DesignShadow.sm],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: DesignSpacing.sm),
            Text(
              l.noteCount(displayNotes.length),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: DesignSpacing.sm),
            IconButton(
              icon: Icon(
                _layoutMode == GraphLayoutMode.forceDirected
                    ? Icons.scatter_plot
                    : Icons.circle,
                size: 14,
              ),
              onPressed: () => setState(() {
                _layoutMode = _layoutMode == GraphLayoutMode.forceDirected
                    ? GraphLayoutMode.circular
                    : GraphLayoutMode.forceDirected;
                _cachedLayoutKey = null;
              }),
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
              tooltip: _layoutMode == GraphLayoutMode.forceDirected
                  ? 'Switch to circular'
                  : l.switchToForceLayout,
            ),
            IconButton(
              icon: Icon(
                _viewMode == GraphViewMode.full
                    ? Icons.account_tree
                    : Icons.hub,
                size: 14,
              ),
              onPressed: () => setState(() {
                _viewMode = _viewMode == GraphViewMode.full
                    ? GraphViewMode.local
                    : GraphViewMode.full;
                if (_viewMode == GraphViewMode.local &&
                    _localGraphCenter == null) {
                  _localGraphCenter =
                      ref.read(knowledgeProvider).activeNote?.id ??
                      displayNotes.first.id;
                }
                _cachedLayoutKey = null;
              }),
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
              tooltip: _viewMode == GraphViewMode.full
                  ? l.localGraph
                  : 'Full graph',
            ),
            const SizedBox(width: DesignSpacing.xs),
            IconButton(
              icon: Icon(
                _showStats ? Icons.analytics : Icons.analytics_outlined,
                size: 16,
              ),
              onPressed: () => setState(() => _showStats = !_showStats),
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
              tooltip: 'Toggle statistics',
            ),
            IconButton(
              icon: Icon(
                _showLegend
                    ? Icons.legend_toggle
                    : Icons.legend_toggle_outlined,
                size: 16,
              ),
              onPressed: () => setState(() => _showLegend = !_showLegend),
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
              tooltip: l.toggleLegend,
            ),
            const SizedBox(width: DesignSpacing.xs),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 16),
              onPressed: () =>
                  setState(() => _scale = (_scale * 1.2).clamp(0.3, 3.0)),
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 16),
              onPressed: () =>
                  setState(() => _scale = (_scale / 1.2).clamp(0.3, 3.0)),
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.center_focus_strong, size: 16),
              onPressed: () => setState(() {
                _offset = Offset.zero;
                _scale = 1.0;
              }),
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
            ),
            const SizedBox(width: DesignSpacing.xs),
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download, size: 16),
              tooltip: l.export,
              constraints: const BoxConstraints(
                minWidth: DesignTouchTarget.iconButtonSize,
                minHeight: DesignTouchTarget.iconButtonSize,
              ),
              onSelected: (value) =>
                  _handleGraphExport(value, displayNotes, displayLinks),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'png',
                  child: Row(
                    children: [
                      Icon(Icons.image, size: 14, color: theme.hintColor),
                      const SizedBox(width: 8),
                      Text(l.exportGraphPng),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'svg',
                  child: Row(
                    children: [
                      Icon(Icons.code, size: 14, color: theme.hintColor),
                      const SizedBox(width: 8),
                      Text(l.exportGraphSvg),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'json',
                  child: Row(
                    children: [
                      Icon(Icons.data_object, size: 14, color: theme.hintColor),
                      const SizedBox(width: 8),
                      Text(l.exportGraphJson),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

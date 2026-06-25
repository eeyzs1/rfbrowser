part of '../canvas_page.dart';

mixin _CanvasToolbarMixin on _CanvasViewStateBase {
  @override
  Widget _buildToolbar(
    ThemeData theme,
    CanvasData canvasData,
    bool autoEnabled,
    CanvasNotifier notifier,
    AppLocalizations l,
  ) {
    final hasMultiSelection = canvasData.selectedCardIds.length >= 2;
    return Container(
      height: _CanvasViewStateBase._toolbarHeight,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.dashboard,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  _buildCanvasSwitcher(theme),
                  const SizedBox(width: 6),
                  _toolbarDivider(theme),
                  const SizedBox(width: 4),
                  _toolbarButton(theme, Icons.add, l.tooltipAddCard, () {
                    final worldPos = Offset(_cameraX, _cameraY);
                    _addCardAt(worldPos);
                  }),
                  _toolbarButton(
                    theme,
                    autoEnabled ? Icons.auto_fix_high : Icons.auto_fix_off,
                    l.tooltipAutoConnect,
                    () => ref
                        .read(canvasProvider.notifier)
                        .toggleAutoConnections(),
                  ),
                  const SizedBox(width: 4),
                  _toolbarDivider(theme),
                  const SizedBox(width: 4),
                  _toolbarButton(
                    theme,
                    Icons.undo,
                    l.tooltipUndo,
                    () => _undo(),
                    enabled: notifier.canUndo,
                  ),
                  _toolbarButton(
                    theme,
                    Icons.redo,
                    l.tooltipRedo,
                    () => _redo(),
                    enabled: notifier.canRedo,
                  ),
                  _toolbarDivider(theme),
                  const SizedBox(width: 4),
                  if (hasMultiSelection)
                    ..._buildAlignPopupSection(theme, canvasData, l),
                  _buildViewPopup(theme, canvasData, l),
                  _buildCreatePopup(theme, l),
                  _buildShapesPopup(theme, l),
                  _buildTemplatesPopup(theme, l),
                  _toolbarButton(
                    theme,
                    Icons.format_paint,
                    l.tooltipStyleBrush,
                    () {
                      final ids = _selectedCardIds;
                      if (ids.length == 1) {
                        final card = ref
                            .read(canvasProvider.notifier)
                            .cardById(ids.first);
                        if (card != null) {
                          setState(() {
                            _styleBrushMode = true;
                            _copiedStyle =
                                card.style ?? CanvasCardStyle.defaults;
                          });
                        }
                      }
                    },
                    enabled: _selectedCardIds.length == 1,
                    highlight: _styleBrushMode,
                  ),
                  _buildAutoLayoutPopup(theme, l),
                  _buildExportPopup(theme, l),
                  _buildOrganizePopup(theme, l),
                  _buildSettingsPopup(theme, canvasData, l),
                  _toolbarDivider(theme),
                  const SizedBox(width: 6),
                  Text(
                    l.canvasStatusCardsConnectionsGroups(
                      canvasData.cards.length,
                      canvasData.connections.length,
                      canvasData.groups.length,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  if (canvasData.selectedCardIds.length > 1) ...[
                    const SizedBox(width: 6),
                    Text(
                      l.selectedGroupHint(canvasData.selectedCardIds.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (canvasData.selectedCardIds.length == 1 &&
                      _inlineEditingCardId == null) ...[
                    const SizedBox(width: 6),
                    Text(
                      l.selectedSingleHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                  if (_inlineEditingCardId != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      l.editingHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (_connectingFromCardId != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      l.connectCardHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (_styleBrushMode) ...[
                    const SizedBox(width: 6),
                    Text(
                      l.styleBrushHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toolbarDivider(theme),
                const SizedBox(width: 4),
                _toolbarButton(
                  theme,
                  Icons.search,
                  l.tooltipSearch,
                  _toggleSearch,
                ),
                if (_searchVisible)
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l.searchCards,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: _clearSearch,
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: theme.hintColor,
                                ),
                              )
                            : null,
                      ),
                      style: theme.textTheme.bodySmall,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmit,
                    ),
                  ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _searchPrev,
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      size: 16,
                      color: theme.hintColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: _searchNext,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${_searchActiveIndex + 1}/${_searchMatchedIds.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget _toolbarDivider(ThemeData theme) {
    return Container(width: 1, height: 16, color: theme.dividerColor);
  }

  @override
  Widget _popupRow(
    IconData icon,
    String text, {
    Widget? trailing,
    String? tooltip,
  }) {
    final row = Row(
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 8),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: row);
    }
    return row;
  }
}

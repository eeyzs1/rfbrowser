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
                  if (hasMultiSelection) ...[
                    HoverPopupMenuButton<String>(
                      tooltip: l.tooltipAlign,
                      icon: Icon(
                        Icons.align_horizontal_left,
                        size: 14,
                        color: theme.hintColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onSelected: (value) {
                        final notifier = ref.read(canvasProvider.notifier);
                        final ids = canvasData.selectedCardIds;
                        switch (value) {
                          case 'left':
                            notifier.alignCards(ids, AlignmentType.left);
                          case 'centerH':
                            notifier.alignCards(ids, AlignmentType.centerH);
                          case 'right':
                            notifier.alignCards(ids, AlignmentType.right);
                          case 'top':
                            notifier.alignCards(ids, AlignmentType.top);
                          case 'centerV':
                            notifier.alignCards(ids, AlignmentType.centerV);
                          case 'bottom':
                            notifier.alignCards(ids, AlignmentType.bottom);
                          case 'distH':
                            notifier.distributeCards(
                              ids,
                              DistributeType.horizontal,
                            );
                          case 'distV':
                            notifier.distributeCards(
                              ids,
                              DistributeType.vertical,
                            );
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'left',
                          child: _popupRow(
                            Icons.align_horizontal_left,
                            l.alignLeft,
                            tooltip: l.ttAlignLeft,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'centerH',
                          child: _popupRow(
                            Icons.align_horizontal_center,
                            l.alignCenterH,
                            tooltip: l.ttAlignCenterH,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'right',
                          child: _popupRow(
                            Icons.align_horizontal_right,
                            l.alignRight,
                            tooltip: l.ttAlignRight,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'top',
                          child: _popupRow(
                            Icons.align_vertical_top,
                            l.alignTop,
                            tooltip: l.ttAlignTop,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'centerV',
                          child: _popupRow(
                            Icons.align_vertical_center,
                            l.alignCenterV,
                            tooltip: l.ttAlignCenterV,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'bottom',
                          child: _popupRow(
                            Icons.align_vertical_bottom,
                            l.alignBottom,
                            tooltip: l.ttAlignBottom,
                          ),
                        ),
                        if (canvasData.selectedCardIds.length >= 3) ...[
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'distH',
                            child: _popupRow(
                              Icons.space_bar,
                              l.distributeH,
                              tooltip: l.ttDistributeH,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'distV',
                            child: _popupRow(
                              Icons.view_headline,
                              l.distributeV,
                              tooltip: l.ttDistributeV,
                            ),
                          ),
                        ],
                      ],
                    ),
                    _toolbarButton(
                      theme,
                      Icons.group_work,
                      l.tooltipGroup,
                      _groupSelected,
                    ),
                    _toolbarDivider(theme),
                    const SizedBox(width: 4),
                  ],
                  HoverPopupMenuButton<String>(
                    tooltip: l.toolbarViewDesc,
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'grid':
                          ref.read(canvasProvider.notifier).toggleGridVisible();
                        case 'snap':
                          ref.read(canvasProvider.notifier).toggleSnapToGrid();
                        case 'rulers':
                          ref.read(canvasProvider.notifier).toggleRulers();
                        case 'fit':
                          _fitToContent();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'grid',
                        child: _popupRow(
                          canvasData.settings.gridVisible
                              ? Icons.grid_on
                              : Icons.grid_off,
                          l.tooltipGrid,
                          trailing: canvasData.settings.gridVisible
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          tooltip: l.ttGrid,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'snap',
                        child: _popupRow(
                          canvasData.settings.snapToGrid
                              ? Icons.grid_on_outlined
                              : Icons.grid_4x4,
                          l.tooltipSnap,
                          trailing: canvasData.settings.snapToGrid
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          tooltip: l.ttSnap,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rulers',
                        child: _popupRow(
                          Icons.straighten,
                          l.tooltipRulers,
                          trailing: canvasData.settings.rulersVisible
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          tooltip: l.ttRulers,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'fit',
                        child: _popupRow(
                          Icons.fit_screen,
                          l.tooltipFit,
                          tooltip: l.ttFit,
                        ),
                      ),
                    ],
                  ),
                  HoverPopupMenuButton<String>(
                    tooltip: l.toolbarCreateDesc,
                    icon: Icon(
                      Icons.add_box_outlined,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'container':
                          final worldPos = Offset(_cameraX, _cameraY);
                          _addContainerAt(worldPos);
                        case 'freehand':
                          setState(() {
                            _isFreehandDrawing = !_isFreehandDrawing;
                          });
                          if (_isFreehandDrawing) {
                            final fhType = CanvasCardType.freehand;
                            final card = CanvasCard(
                              id: 'fh_${DateTime.now().millisecondsSinceEpoch}',
                              type: fhType,
                              x: _cameraX,
                              y: _cameraY,
                              width: fhType.defaultWidth,
                              height: fhType.defaultHeight,
                              freehandPoints: [],
                            );
                            ref.read(canvasProvider.notifier).addCard(card);
                            _freehandCardId = card.id;
                            _freehandPoints = [];
                          } else {
                            _freehandCardId = null;
                            _freehandPoints = [];
                          }
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'container',
                        child: _popupRow(
                          Icons.crop_square,
                          l.tooltipContainer,
                          tooltip: l.ttContainer,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'freehand',
                        child: _popupRow(
                          Icons.draw,
                          l.tooltipFreehand,
                          trailing: _isFreehandDrawing
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          tooltip: l.ttFreehand,
                        ),
                      ),
                    ],
                  ),
                  HoverPopupMenuButton<CanvasCardType>(
                    tooltip: l.tooltipShapes,
                    icon: Icon(
                      Icons.category,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onSelected: (type) {
                      final worldPos = Offset(_cameraX, _cameraY);
                      final card = ref
                          .read(canvasProvider.notifier)
                          .createCard(type, worldPos);
                      ref.read(canvasProvider.notifier).addCard(card);
                      ref.read(canvasProvider.notifier).selectCard(card.id);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: CanvasCardType.rectangle,
                        child: _popupRow(Icons.rectangle, l.rectangle),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.roundedRect,
                        child: _popupRow(Icons.rounded_corner, l.roundedRect),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.ellipse,
                        child: _popupRow(Icons.circle, l.ellipse),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.diamond,
                        child: _popupRow(Icons.diamond, l.diamond),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.hexagon,
                        child: _popupRow(Icons.hexagon, l.hexagon),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.parallelogram,
                        child: _popupRow(Icons.change_history, l.parallelogram),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.triangle,
                        child: _popupRow(Icons.details, l.triangle),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.cylinder,
                        child: _popupRow(Icons.view_column, l.cylinder),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.star,
                        child: _popupRow(Icons.star_outline, l.star),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.swimlaneH,
                        child: _popupRow(Icons.view_stream, l.swimlaneH),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.swimlaneV,
                        child: _popupRow(Icons.view_week, l.swimlaneV),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.table,
                        child: _popupRow(Icons.table_chart, l.table),
                      ),
                      PopupMenuItem(
                        value: CanvasCardType.freehand,
                        child: _popupRow(Icons.draw, l.freehand),
                      ),
                    ],
                  ),
                  HoverPopupMenuButton<String>(
                    tooltip: l.tooltipTemplates,
                    icon: Icon(
                      Icons.dashboard_customize,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onSelected: (name) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l.loadTemplate),
                          content: Text(l.loadTemplateConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l.cancel),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ref
                                    .read(canvasProvider.notifier)
                                    .loadTemplate(name);
                              },
                              child: Text(l.load),
                            ),
                          ],
                        ),
                      );
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'flowchart',
                        child: _popupRow(Icons.account_tree, l.flowchart),
                      ),
                      PopupMenuItem(
                        value: 'uml_class',
                        child: _popupRow(Icons.class_, l.umlClass),
                      ),
                      PopupMenuItem(
                        value: 'swimlane',
                        child: _popupRow(Icons.view_stream, l.swimlane),
                      ),
                      PopupMenuItem(
                        value: 'mindmap',
                        child: _popupRow(Icons.psychology, l.mindMap),
                      ),
                      PopupMenuItem(
                        value: 'network',
                        child: _popupRow(Icons.cloud, l.network),
                      ),
                      PopupMenuItem(
                        value: 'er_diagram',
                        child: _popupRow(Icons.schema, l.erDiagram),
                      ),
                      PopupMenuItem(
                        value: 'kanban',
                        child: _popupRow(Icons.view_kanban, l.kanban),
                      ),
                      PopupMenuItem(
                        value: 'org_chart',
                        child: _popupRow(Icons.corporate_fare, l.orgChart),
                      ),
                      PopupMenuItem(
                        value: 'state_machine',
                        child: _popupRow(Icons.sync, l.stateMachine),
                      ),
                      PopupMenuItem(
                        value: 'venn',
                        child: _popupRow(Icons.circle, l.vennDiagram),
                      ),
                      PopupMenuItem(
                        value: 'timeline',
                        child: _popupRow(Icons.timeline, l.timeline),
                      ),
                      PopupMenuItem(
                        value: 'gantt',
                        child: _popupRow(Icons.view_timeline, l.gantt),
                      ),
                      PopupMenuItem(
                        value: 'decision_tree',
                        child: _popupRow(Icons.device_hub, l.decisionTree),
                      ),
                    ],
                  ),
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
                  HoverPopupMenuButton<AutoLayoutType>(
                    tooltip: l.tooltipAutoLayout,
                    icon: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onSelected: (type) =>
                        ref.read(canvasProvider.notifier).autoLayout(type),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: AutoLayoutType.forceDirected,
                        child: _popupRow(
                          Icons.bubble_chart,
                          l.forceDirected,
                          tooltip: l.ttForceDirected,
                        ),
                      ),
                      PopupMenuItem(
                        value: AutoLayoutType.hierarchical,
                        child: _popupRow(
                          Icons.account_tree,
                          l.hierarchical,
                          tooltip: l.ttHierarchical,
                        ),
                      ),
                      PopupMenuItem(
                        value: AutoLayoutType.grid,
                        child: _popupRow(
                          Icons.grid_view,
                          l.grid,
                          tooltip: l.ttGridLayout,
                        ),
                      ),
                    ],
                  ),
                  HoverPopupMenuButton<String>(
                    tooltip: l.tooltipExport,
                    icon: Icon(
                      Icons.file_download,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onSelected: (value) => _handleExport(value),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'png',
                        child: _popupRow(
                          Icons.image,
                          l.exportPng,
                          tooltip: l.ttExportPng,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'svg',
                        child: _popupRow(
                          Icons.code,
                          l.exportSvg,
                          tooltip: l.ttExportSvg,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'markdown',
                        child: _popupRow(
                          Icons.description,
                          l.exportMarkdown,
                          tooltip: l.ttExportMarkdown,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'html',
                        child: _popupRow(
                          Icons.web,
                          l.exportHtml,
                          tooltip: l.ttExportHtml,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'svgWithMeta',
                        child: _popupRow(
                          Icons.data_object,
                          l.exportSvgWithData,
                          tooltip: l.ttExportSvgMeta,
                        ),
                      ),
                    ],
                  ),
                  HoverPopupMenuButton<String>(
                    tooltip: l.toolbarOrganizeDesc,
                    icon: Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'layers':
                          _showLayerPanel();
                        case 'scratchpad':
                          _showScratchpad();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'layers',
                        child: _popupRow(
                          Icons.layers,
                          l.tooltipLayers,
                          tooltip: l.ttLayers,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'scratchpad',
                        child: _popupRow(
                          Icons.bookmark_border,
                          l.tooltipScratchpad,
                          tooltip: l.ttScratchpad,
                        ),
                      ),
                    ],
                  ),
                  HoverPopupMenuButton<String>(
                    tooltip: l.tooltipCanvasSettings,
                    icon: Icon(
                      Icons.settings,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onSelected: (value) {
                      if (value == 'background') {
                        _showBackgroundColorPicker();
                      } else if (value == 'defaultCardStyle') {
                        _showDefaultStyleDialog();
                      } else if (value == 'clearBackground') {
                        ref
                            .read(canvasProvider.notifier)
                            .setBackgroundColor(null);
                      } else if (value == 'enumerate') {
                        ref.read(canvasProvider.notifier).enumerateAllCards();
                      } else if (value == 'importCsv') {
                        _showImportDialog('csv');
                      } else if (value == 'importMermaid') {
                        _showImportDialog('mermaid');
                      } else if (value == 'importSvg') {
                        _showImportDialog('svg');
                      } else if (value == 'shareUrl') {
                        _shareViaUrl();
                      } else if (value == 'clear') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              AppLocalizations.of(context)!.clearCanvas,
                            ),
                            content: Text(
                              AppLocalizations.of(context)!.clearCanvasConfirm,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  AppLocalizations.of(context)!.cancel,
                                ),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ref
                                      .read(canvasProvider.notifier)
                                      .clearCanvas();
                                  ref
                                      .read(canvasProvider.notifier)
                                      .selectCard(null);
                                  _connectingFromCardId = null;
                                },
                                child: Text(
                                  AppLocalizations.of(context)!.clear,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'background',
                        child: _popupRow(
                          Icons.palette,
                          l.backgroundColor,
                          tooltip: l.ttBackground,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'clearBackground',
                        child: _popupRow(
                          Icons.clear,
                          l.clearBackground,
                          tooltip: l.ttClearBackground,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'defaultCardStyle',
                        child: _popupRow(
                          Icons.style,
                          l.defaultCardStyle,
                          tooltip: l.ttDefaultCardStyle,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'enumerate',
                        child: _popupRow(
                          Icons.format_list_numbered,
                          l.enumerateShapes,
                          tooltip: l.ttEnumerate,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'importCsv',
                        child: _popupRow(
                          Icons.table_chart,
                          l.importCsv,
                          tooltip: l.ttImportCsv,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'importMermaid',
                        child: _popupRow(
                          Icons.code,
                          l.importMermaid,
                          tooltip: l.ttImportMermaid,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'importSvg',
                        child: _popupRow(
                          Icons.draw,
                          l.importSvg,
                          tooltip: l.ttImportSvg,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'shareUrl',
                        child: _popupRow(
                          Icons.share,
                          l.shareViaUrl,
                          tooltip: l.ttShareUrl,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'clear',
                        child: Tooltip(
                          message: l.ttClearCanvas,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 14,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l.clearCanvas,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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

part of '../canvas_page.dart';

mixin _CanvasToolbarPopupsMixin on _CanvasViewStateBase {
  @override
  List<Widget> _buildAlignPopupSection(
    ThemeData theme,
    CanvasData canvasData,
    AppLocalizations l,
  ) {
    return [
      HoverPopupMenuButton<String>(
        tooltip: l.tooltipAlign,
        icon: Icon(
          Icons.align_horizontal_left,
          size: 14,
          color: theme.hintColor,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
              notifier.distributeCards(ids, DistributeType.horizontal);
            case 'distV':
              notifier.distributeCards(ids, DistributeType.vertical);
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
      _toolbarButton(theme, Icons.group_work, l.tooltipGroup, _groupSelected),
      _toolbarDivider(theme),
      const SizedBox(width: 4),
    ];
  }

  @override
  Widget _buildViewPopup(
    ThemeData theme,
    CanvasData canvasData,
    AppLocalizations l,
  ) {
    return HoverPopupMenuButton<String>(
      tooltip: l.toolbarViewDesc,
      icon: Icon(Icons.visibility_outlined, size: 14, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
            canvasData.settings.gridVisible ? Icons.grid_on : Icons.grid_off,
            l.tooltipGrid,
            trailing: canvasData.settings.gridVisible
                ? Icon(Icons.check, size: 14, color: theme.colorScheme.primary)
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
                ? Icon(Icons.check, size: 14, color: theme.colorScheme.primary)
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
                ? Icon(Icons.check, size: 14, color: theme.colorScheme.primary)
                : null,
            tooltip: l.ttRulers,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'fit',
          child: _popupRow(Icons.fit_screen, l.tooltipFit, tooltip: l.ttFit),
        ),
      ],
    );
  }

  @override
  Widget _buildCreatePopup(ThemeData theme, AppLocalizations l) {
    return HoverPopupMenuButton<String>(
      tooltip: l.toolbarCreateDesc,
      icon: Icon(Icons.add_box_outlined, size: 14, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
                ? Icon(Icons.check, size: 14, color: theme.colorScheme.primary)
                : null,
            tooltip: l.ttFreehand,
          ),
        ),
      ],
    );
  }

  @override
  Widget _buildShapesPopup(ThemeData theme, AppLocalizations l) {
    return HoverPopupMenuButton<CanvasCardType>(
      tooltip: l.tooltipShapes,
      icon: Icon(Icons.category, size: 14, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
    );
  }

  @override
  Widget _buildTemplatesPopup(ThemeData theme, AppLocalizations l) {
    return HoverPopupMenuButton<String>(
      tooltip: l.tooltipTemplates,
      icon: Icon(Icons.dashboard_customize, size: 14, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
                  ref.read(canvasProvider.notifier).loadTemplate(name);
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
    );
  }
}

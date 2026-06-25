part of '../canvas_page.dart';

/// Additional toolbar popup menus: auto-layout, export, organize, settings.
mixin _CanvasToolbarPopupsMoreMixin on _CanvasViewStateBase {
  @override
  Widget _buildAutoLayoutPopup(ThemeData theme, AppLocalizations l) {
    return HoverPopupMenuButton<AutoLayoutType>(
      tooltip: l.tooltipAutoLayout,
      icon: Icon(Icons.auto_awesome, size: 14, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onSelected: (type) => ref.read(canvasProvider.notifier).autoLayout(type),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: AutoLayoutType.forceDirected,
          child: _popupRow(Icons.bubble_chart, l.forceDirected, tooltip: l.ttForceDirected),
        ),
        PopupMenuItem(
          value: AutoLayoutType.hierarchical,
          child: _popupRow(Icons.account_tree, l.hierarchical, tooltip: l.ttHierarchical),
        ),
        PopupMenuItem(
          value: AutoLayoutType.grid,
          child: _popupRow(Icons.grid_view, l.grid, tooltip: l.ttGridLayout),
        ),
      ],
    );
  }

  @override
  Widget _buildExportPopup(ThemeData theme, AppLocalizations l) {
    return HoverPopupMenuButton<String>(
      tooltip: l.tooltipExport,
      icon: Icon(Icons.file_download, size: 14, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onSelected: (value) => _handleExport(value),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'png',
          child: _popupRow(Icons.image, l.exportPng, tooltip: l.ttExportPng),
        ),
        PopupMenuItem(
          value: 'svg',
          child: _popupRow(Icons.code, l.exportSvg, tooltip: l.ttExportSvg),
        ),
        PopupMenuItem(
          value: 'markdown',
          child: _popupRow(Icons.description, l.exportMarkdown, tooltip: l.ttExportMarkdown),
        ),
        PopupMenuItem(
          value: 'html',
          child: _popupRow(Icons.web, l.exportHtml, tooltip: l.ttExportHtml),
        ),
        PopupMenuItem(
          value: 'svgWithMeta',
          child: _popupRow(Icons.data_object, l.exportSvgWithData, tooltip: l.ttExportSvgMeta),
        ),
      ],
    );
  }

  @override
  Widget _buildOrganizePopup(ThemeData theme, AppLocalizations l) {
    return HoverPopupMenuButton<String>(
      tooltip: l.toolbarOrganizeDesc,
      icon: Icon(Icons.folder_outlined, size: 14, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
          child: _popupRow(Icons.layers, l.tooltipLayers, tooltip: l.ttLayers),
        ),
        PopupMenuItem(
          value: 'scratchpad',
          child: _popupRow(Icons.bookmark_border, l.tooltipScratchpad, tooltip: l.ttScratchpad),
        ),
      ],
    );
  }

  @override
  Widget _buildSettingsPopup(ThemeData theme, CanvasData canvasData, AppLocalizations l) {
    return HoverPopupMenuButton<String>(
      tooltip: l.tooltipCanvasSettings,
      icon: Icon(Icons.settings, size: 14, color: theme.hintColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onSelected: (value) {
        if (value == 'background') {
          _showBackgroundColorPicker();
        } else if (value == 'defaultCardStyle') {
          _showDefaultStyleDialog();
        } else if (value == 'clearBackground') {
          ref.read(canvasProvider.notifier).setBackgroundColor(null);
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
              title: Text(AppLocalizations.of(context)!.clearCanvas),
              content: Text(AppLocalizations.of(context)!.clearCanvasConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(canvasProvider.notifier).clearCanvas();
                    ref.read(canvasProvider.notifier).selectCard(null);
                    _connectingFromCardId = null;
                  },
                  child: Text(AppLocalizations.of(context)!.clear),
                ),
              ],
            ),
          );
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'background',
          child: _popupRow(Icons.palette, l.backgroundColor, tooltip: l.ttBackground),
        ),
        PopupMenuItem(
          value: 'clearBackground',
          child: _popupRow(Icons.clear, l.clearBackground, tooltip: l.ttClearBackground),
        ),
        PopupMenuItem(
          value: 'defaultCardStyle',
          child: _popupRow(Icons.style, l.defaultCardStyle, tooltip: l.ttDefaultCardStyle),
        ),
        PopupMenuItem(
          value: 'enumerate',
          child: _popupRow(Icons.format_list_numbered, l.enumerateShapes, tooltip: l.ttEnumerate),
        ),
        PopupMenuItem(
          value: 'importCsv',
          child: _popupRow(Icons.table_chart, l.importCsv, tooltip: l.ttImportCsv),
        ),
        PopupMenuItem(
          value: 'importMermaid',
          child: _popupRow(Icons.code, l.importMermaid, tooltip: l.ttImportMermaid),
        ),
        PopupMenuItem(
          value: 'importSvg',
          child: _popupRow(Icons.draw, l.importSvg, tooltip: l.ttImportSvg),
        ),
        PopupMenuItem(
          value: 'shareUrl',
          child: _popupRow(Icons.share, l.shareViaUrl, tooltip: l.ttShareUrl),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'clear',
          child: Tooltip(
            message: l.ttClearCanvas,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 14, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l.clearCanvas,
                    style: TextStyle(color: theme.colorScheme.error),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

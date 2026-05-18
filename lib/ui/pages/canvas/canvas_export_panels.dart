part of '../canvas_page.dart';

mixin _CanvasExportPanelsMixin on _CanvasViewStateBase {
    @override
    void _fitToContent() {
      final cards = ref.read(canvasProvider).cards;
      if (cards.isEmpty) {
        _cameraX = 0;
        _cameraY = 0;
        _scale = 1.0;
        _cameraNotifier.notify();
        return;
      }
      double minX = double.infinity,
          minY = double.infinity,
          maxX = double.negativeInfinity,
          maxY = double.negativeInfinity;
      for (final card in cards) {
        minX = math.min(minX, card.x);
        minY = math.min(minY, card.y);
        maxX = math.max(maxX, card.x + card.width);
        maxY = math.max(maxY, card.y + card.height);
      }
      final contentW = maxX - minX + 100;
      final contentH = maxY - minY + 100;
      final fitScale = math
          .min(_viewW / contentW, _viewH / contentH)
          .clamp(0.05, 2.0);
      _cameraX = (minX + maxX) / 2;
      _cameraY = (minY + maxY) / 2;
      _scale = fitScale;
      _cameraNotifier.notify();
    }

    @override
    void _handleExport(String format) {
      final notifier = ref.read(canvasProvider.notifier);
      switch (format) {
        case 'svg':
          final svg = notifier.exportToSvg();
          _saveExportFile('canvas_${notifier.activeCanvasName}.svg', svg);
        case 'markdown':
          final md = notifier.exportToMarkdown();
          _saveExportFile('canvas_${notifier.activeCanvasName}.md', md);
        case 'png':
          _exportToPng();
        case 'html':
          final html = notifier.exportToHtml();
          _saveExportFile('canvas_${notifier.activeCanvasName}.html', html);
        case 'svgWithMeta':
          final (svg, _) = notifier.exportWithEmbeddedData();
          _saveExportFile('canvas_${notifier.activeCanvasName}.svg', svg);
      }
    }

    @override
  Future<void> _exportToPng() async {
      final l = AppLocalizations.of(context)!;
      try {
        final boundary =
            _canvasPaintKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary == null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.exportFailedNotRendered)));
          }
          return;
        }
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.exportFailedPng)));
          }
          return;
        }
        final notifier = ref.read(canvasProvider.notifier);
        final vaultPath = ref.read(vaultProvider).currentVault?.path;
        if (vaultPath == null) return;
        final dir = Directory('$vaultPath/attachments');
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/canvas_${notifier.activeCanvasName}.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        image.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.exportedPngTo(file.path)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.pngExportFailed('$e'))));
        }
      }
    }

    @override
    void _saveExportFile(String filename, String content) async {
      final l = AppLocalizations.of(context)!;
      try {
        final vaultPath = ref.read(vaultProvider).currentVault?.path;
        if (vaultPath == null) return;
        final dir = Directory('$vaultPath/attachments');
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/$filename');
        await file.writeAsString(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.exportedTo(file.path)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
        }
      }
    }

    @override
    void _showLayerPanel() {
      final l = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final notifier = ref.read(canvasProvider.notifier);
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final canvasData = ref.read(canvasProvider);
            final sortedLayers = List<CanvasLayer>.from(canvasData.layers)
              ..sort((a, b) => a.order.compareTo(b.order));
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.layers, size: 18),
                  const SizedBox(width: 8),
                  Text(l.layers),
                  const Spacer(),
                  Text(
                    '${canvasData.layers.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sortedLayers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: 40,
                              color: theme.hintColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l.noLayersYet,
                              style: TextStyle(color: theme.hintColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.addLayersToOrganize,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...sortedLayers.map((layer) {
                      final cardCount = notifier.cardCountForLayer(layer.id);
                      return ListTile(
                        dense: true,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                layer.visible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 16,
                                color: layer.visible
                                    ? theme.colorScheme.primary
                                    : theme.hintColor,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () {
                                notifier.toggleLayerVisibility(layer.id);
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                        title: GestureDetector(
                          onDoubleTap: () {
                            final ctrl = TextEditingController(text: layer.name);
                            showDialog(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                title: Text(l.renameLayerTitle),
                                content: TextField(
                                  controller: ctrl,
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: l.layerName,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dctx),
                                    child: Text(l.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      notifier.renameLayer(
                                        layer.id,
                                        ctrl.text.trim(),
                                      );
                                      Navigator.pop(dctx);
                                      setDialogState(() {});
                                    },
                                    child: Text(l.renameLayer),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  layer.name,
                                  style: TextStyle(
                                    color: layer.locked ? theme.hintColor : null,
                                    decoration: layer.visible
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$cardCount',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_upward,
                                size: 14,
                                color: theme.hintColor,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              tooltip: l.moveUp,
                              onPressed: () {
                                notifier.moveLayerUp(layer.id);
                                setDialogState(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                size: 14,
                                color: theme.hintColor,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              tooltip: l.moveDown,
                              onPressed: () {
                                notifier.moveLayerDown(layer.id);
                                setDialogState(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                layer.locked ? Icons.lock : Icons.lock_open,
                                size: 16,
                                color: layer.locked
                                    ? Colors.orange
                                    : theme.hintColor,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              tooltip: layer.locked ? l.unlock : l.lock,
                              onPressed: () {
                                notifier.toggleLayerLock(layer.id);
                                setDialogState(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              tooltip: l.deleteLayer,
                              onPressed: () {
                                notifier.removeLayer(layer.id);
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l.close),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final name = 'Layer ${canvasData.layers.length + 1}';
                    notifier.addLayer(name);
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l.addLayer),
                ),
              ],
            );
          },
        ),
      );
    }

    @override
    void _showScratchpad() async {
      final l = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final notifier = ref.read(canvasProvider.notifier);
      final items = await notifier.loadScratchpad();
      if (!mounted) return;
      const kAllCategory = '__all__';
      String filterCategory = kAllCategory;
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final categories = [
              kAllCategory,
              ...items.map((i) => i.category).toSet(),
            ];
            final filtered = filterCategory == kAllCategory
                ? items
                : items.where((i) => i.category == filterCategory).toList();
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.bookmark_border, size: 18),
                  const SizedBox(width: 8),
                  Text(l.scratchpad),
                  const Spacer(),
                  Text(
                    '${items.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (categories.length > 2)
                      SizedBox(
                        height: 28,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: categories
                              .map(
                                (cat) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: FilterChip(
                                    label: Text(
                                      cat == kAllCategory ? l.all : cat,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    selected: cat == filterCategory,
                                    onSelected: (_) => setDialogState(
                                      () => filterCategory = cat,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    if (categories.length > 2) const SizedBox(height: 8),
                    ...filtered.map((item) {
                      final previewColor = Color(item.colorValue);
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 32,
                          height: 24,
                          decoration: BoxDecoration(
                            color: previewColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: previewColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              item.type.icon,
                              size: 12,
                              color: previewColor,
                            ),
                          ),
                        ),
                        title: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        subtitle: Text(
                          '${item.category} · ${item.width.round()}×${item.height.round()}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_outline,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              tooltip: l.addToCanvas,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () {
                                final card = notifier.createCardFromScratchpad(
                                  item,
                                  Offset(_cameraX, _cameraY),
                                );
                                notifier.addCard(card);
                                notifier.selectCard(card.id);
                                Navigator.pop(ctx);
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () {
                                notifier.removeScratchpadItem(item.id);
                                items.removeWhere((i) => i.id == item.id);
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bookmark_outline,
                              size: 40,
                              color: theme.hintColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l.noTemplatesYet,
                              style: TextStyle(color: theme.hintColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.scratchpadEmptyHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l.close),
                ),
              ],
            );
          },
        ),
      );
    }

}

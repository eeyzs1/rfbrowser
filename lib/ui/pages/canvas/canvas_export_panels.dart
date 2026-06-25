part of '../canvas_page.dart';

mixin _CanvasExportPanelsMixin on _CanvasViewStateBase {
  @override
  void _fitToContent() {
    final canvasData = ref.read(canvasProvider);
    final cards = canvasData.cards.where((c) {
      if (canvasData.selectedLayerId == null) return true;
      if (canvasData.selectedLayerId == CanvasData.unassignedSentinel) {
        return c.layerId == null;
      }
      return c.layerId == canvasData.selectedLayerId;
    }).toList();
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
    showDialog(
      context: context,
      builder: (ctx) => const LayerPanelDialog(),
    );
  }

  @override
  void _showScratchpad() async {
    final notifier = ref.read(canvasProvider.notifier);
    final items = await notifier.loadScratchpad();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => ScratchpadDialog(
        items: items,
        cameraPosition: Offset(_cameraX, _cameraY),
      ),
    );
  }
}

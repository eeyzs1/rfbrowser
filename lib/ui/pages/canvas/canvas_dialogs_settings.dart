part of '../canvas_page.dart';

/// Canvas-level settings dialogs: layer, background color, default card
/// style, tag management, import/share.
mixin _CanvasDialogsSettingsMixin on _CanvasViewStateBase {
  @override
  void _showMoveToLayerDialog(CanvasCard card) {
    final canvasData = ref.read(canvasProvider);
    showDialog<({String? layerId})>(
      context: context,
      builder: (ctx) => MoveToLayerDialog(
        currentLayerId: card.layerId,
        layers: canvasData.layers,
      ),
    ).then((result) {
      if (result == null) return;
      ref
          .read(canvasProvider.notifier)
          .moveCardToLayer(card.id, result.layerId);
    });
  }

  @override
  void _showBackgroundColorPicker() {
    final canvasData = ref.read(canvasProvider);
    final current = canvasData.settings.backgroundColorValue;
    showDialog<({int? colorValue})>(
      context: context,
      builder: (ctx) => BackgroundColorPickerDialog(currentColorValue: current),
    ).then((result) {
      if (result == null) return;
      ref.read(canvasProvider.notifier).setBackgroundColor(result.colorValue);
    });
  }

  @override
  void _showDefaultStyleDialog() {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(canvasProvider.notifier);
    final canvasData = ref.read(canvasProvider);
    final currentCardStyle =
        canvasData.settings.defaultCardStyle ?? CanvasCardStyle.defaults;
    showDialog(
      context: context,
      builder: (ctx) {
        final ctxTheme = Theme.of(ctx);
        return AlertDialog(
          title: Text(l.defaultCardStyle),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.fillColor, style: ctxTheme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      [
                            0xFFFFFFFF,
                            0xFFF5F5F5,
                            0xFFE3F2FD,
                            0xFFE8F5E9,
                            0xFFFFF3E0,
                            0xFFFCE4EC,
                            0xFFF3E5F5,
                            0xFFE0E0E0,
                          ]
                          .map(
                            (v) => GestureDetector(
                              onTap: () => notifier.setDefaultCardStyle(
                                currentCardStyle.copyWith(fillColor: v),
                              ),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Color(v),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: currentCardStyle.fillColor == v
                                        ? ctxTheme.colorScheme.primary
                                        : ctxTheme.dividerColor,
                                    width: currentCardStyle.fillColor == v
                                        ? 2
                                        : 1,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
                Text(l.borderRadius, style: ctxTheme.textTheme.bodySmall),
                Slider(
                  value: currentCardStyle.borderRadius,
                  min: 0,
                  max: 24,
                  divisions: 12,
                  label: currentCardStyle.borderRadius.round().toString(),
                  onChanged: (v) => notifier.setDefaultCardStyle(
                    currentCardStyle.copyWith(borderRadius: v),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.borderWidth, style: ctxTheme.textTheme.bodySmall),
                Slider(
                  value: currentCardStyle.borderWidth,
                  min: 0,
                  max: 4,
                  divisions: 8,
                  label: currentCardStyle.borderWidth.toStringAsFixed(1),
                  onChanged: (v) => notifier.setDefaultCardStyle(
                    currentCardStyle.copyWith(borderWidth: v),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                notifier.setDefaultCardStyle(null);
                Navigator.pop(ctx);
              },
              child: Text(l.reset),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.close),
            ),
          ],
        );
      },
    );
  }

  @override
  void _showAddTagDialog(CanvasCard card) {
    showDialog<String>(
      context: context,
      builder: (ctx) => const AddTagDialog(),
    ).then((tag) {
      if (tag != null && tag.isNotEmpty) {
        ref.read(canvasProvider.notifier).addTag(card.id, tag);
      }
    });
  }

  @override
  void _showRemoveTagDialog(CanvasCard card) {
    showDialog<String>(
      context: context,
      builder: (ctx) => RemoveTagDialog(tags: card.tags),
    ).then((tag) {
      if (tag != null) {
        ref.read(canvasProvider.notifier).removeTag(card.id, tag);
      }
    });
  }

  @override
  void _showImportDialog(String format) {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.importFormat(format.toUpperCase())),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: format == 'csv'
                  ? 'Name,Relation\nAlice,Bob\nBob,Charlie'
                  : format == 'mermaid'
                  ? 'graph TD\n    A-->B\n    B-->C'
                  : '<svg>...</svg>',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final data = switch (format) {
                'csv' => CanvasNotifier.importFromCsv(ctrl.text),
                'mermaid' => CanvasNotifier.importFromMermaid(ctrl.text),
                'svg' => CanvasNotifier.importFromSvg(ctrl.text),
                _ => null,
              };
              Navigator.pop(ctx);
              if (data != null) {
                ref.read(canvasProvider.notifier).loadFromData(data);
              }
            },
            child: Text(l.import),
          ),
        ],
      ),
    );
  }

  @override
  void _shareViaUrl() {
    final l = AppLocalizations.of(context)!;
    final url = ref.read(canvasProvider.notifier).encodeToUrl();
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.shareUrlCopied),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

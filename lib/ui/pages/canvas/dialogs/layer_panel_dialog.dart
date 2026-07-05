import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/canvas_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/canvas_service.dart';

/// Dialog for managing canvas layers.
///
/// Reads [canvasProvider] via [ref.watch] so the list auto-rebuilds when
/// layers are added, removed, reordered, or renamed. Layer actions (visibility,
/// lock, move, delete, rename, add) are dispatched through the canvas notifier.
class LayerPanelDialog extends ConsumerStatefulWidget {
  const LayerPanelDialog({super.key});

  @override
  ConsumerState<LayerPanelDialog> createState() => _LayerPanelDialogState();
}

class _LayerPanelDialogState extends ConsumerState<LayerPanelDialog> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canvasData = ref.watch(canvasProvider);
    final notifier = ref.read(canvasProvider.notifier);
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
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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
              final isFilterActive = canvasData.selectedLayerId == layer.id;
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.layers_outlined,
                  size: 16,
                  color: isFilterActive
                      ? theme.colorScheme.primary
                      : theme.hintColor,
                ),
                title: GestureDetector(
                  onDoubleTap: () => _showRenameDialog(layer),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          layer.name,
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
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$cardCount',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                      if (isFilterActive) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l.tagActiveFilter,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        layer.visible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 14,
                        color: layer.visible
                            ? theme.colorScheme.primary
                            : theme.hintColor.withValues(alpha: 0.4),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      tooltip: layer.visible ? l.hideLayer : l.showLayer,
                      onPressed: () {
                        notifier.setLayerVisible(layer.id, !layer.visible);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        layer.locked
                            ? Icons.lock_outlined
                            : Icons.lock_open_outlined,
                        size: 14,
                        color: layer.locked
                            ? theme.colorScheme.error
                            : theme.hintColor.withValues(alpha: 0.4),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      tooltip: layer.locked ? l.unlockLayer : l.lockLayer,
                      onPressed: () {
                        notifier.setLayerLocked(layer.id, !layer.locked);
                      },
                    ),
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
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
        FilledButton.icon(
          onPressed: () {
            final name = 'Layer ${canvasData.layers.length + 1}';
            notifier.addLayer(name);
          },
          icon: const Icon(Icons.add, size: 16),
          label: Text(l.addLayer),
        ),
      ],
    );
  }

  void _showRenameDialog(CanvasLayer layer) {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(canvasProvider.notifier);
    final ctrl = TextEditingController(text: layer.name);
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l.renameLayerTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l.layerName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              notifier.renameLayer(layer.id, ctrl.text.trim());
              Navigator.pop(dctx);
            },
            child: Text(l.renameLayer),
          ),
        ],
      ),
    );
  }
}

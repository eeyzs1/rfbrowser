import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/canvas_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/canvas_service.dart';

const String _kAllCategory = '__all__';

/// Dialog for browsing and inserting scratchpad templates.
///
/// Takes the initial [items] (loaded from the canvas notifier) and the
/// [cameraPosition] used to place new cards at the current view center.
/// Items can be filtered by category and inserted into the canvas or deleted.
class ScratchpadDialog extends ConsumerStatefulWidget {
  final List<ScratchpadItem> items;
  final Offset cameraPosition;

  const ScratchpadDialog({
    super.key,
    required this.items,
    required this.cameraPosition,
  });

  @override
  ConsumerState<ScratchpadDialog> createState() => _ScratchpadDialogState();
}

class _ScratchpadDialogState extends ConsumerState<ScratchpadDialog> {
  late final List<ScratchpadItem> _items = List.from(widget.items);
  String _filterCategory = _kAllCategory;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notifier = ref.read(canvasProvider.notifier);
    final categories = [
      _kAllCategory,
      ..._items.map((i) => i.category).toSet(),
    ];
    final filtered = _filterCategory == _kAllCategory
        ? _items
        : _items.where((i) => i.category == _filterCategory).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.bookmark_border, size: 18),
          const SizedBox(width: 8),
          Text(l.scratchpad),
          const Spacer(),
          Text(
            '${_items.length}',
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
                              cat == _kAllCategory ? l.all : cat,
                              style: theme.textTheme.bodySmall,
                            ),
                            selected: cat == _filterCategory,
                            onSelected: (_) =>
                                setState(() => _filterCategory = cat),
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
                          widget.cameraPosition,
                        );
                        notifier.addCard(card);
                        notifier.selectCard(card.id);
                        Navigator.pop(context);
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
                        setState(() {
                          _items.removeWhere((i) => i.id == item.id);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
            if (_items.isEmpty)
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
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}

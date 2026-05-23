import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/services/canvas_service.dart';

class CanvasTagFilterPanel extends ConsumerWidget {
  const CanvasTagFilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final canvasData = ref.watch(canvasProvider);
    final notifier = ref.read(canvasProvider.notifier);
    final layers = canvasData.layers;
    final unassignedCount = notifier.unassignedCardCount;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l.layers,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _SidebarFilterChip(
          label: l.all,
          isSelected: canvasData.selectedLayerId == null,
          count: canvasData.cards.length,
          theme: theme,
          onTap: () => notifier.setSelectedLayer(null),
        ),
        if (unassignedCount > 0)
          _SidebarFilterChip(
            label: l.tagFilterUnassigned,
            isSelected:
                canvasData.selectedLayerId == CanvasData.unassignedSentinel,
            count: unassignedCount,
            theme: theme,
            onTap: () =>
                notifier.setSelectedLayer(CanvasData.unassignedSentinel),
          ),
        if (layers.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l.noLayersYet,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l.addLayersHint,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (layers.isNotEmpty)
          ...layers.map((layer) {
            final count = notifier.cardCountForLayer(layer.id);
            return _SidebarFilterChip(
              label: layer.name,
              isSelected: canvasData.selectedLayerId == layer.id,
              count: count,
              theme: theme,
              onTap: () => notifier.setSelectedLayer(layer.id),
            );
          }),
      ],
    );
  }
}

class _SidebarFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int count;
  final ThemeData theme;
  final VoidCallback onTap;

  const _SidebarFilterChip({
    required this.label,
    required this.isSelected,
    required this.count,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      width: 1,
                    )
                  : Border.all(color: Colors.transparent, width: 1),
            ),
            child: Row(
              children: [
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.80),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0 || isSelected)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.hintColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

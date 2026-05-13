import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class CanvasZoomControls extends StatelessWidget {
  final double scale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomReset;

  const CanvasZoomControls({
    required this.scale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Positioned(
      right: 12,
      bottom: 40,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              onPressed: onZoomIn,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l.zoomIn,
              color: theme.hintColor,
            ),
            Container(
              width: 32,
              height: 24,
              alignment: Alignment.center,
              child: Text(
                '${(scale * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove, size: 16),
              onPressed: onZoomOut,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l.zoomOut,
              color: theme.hintColor,
            ),
            Container(width: 24, height: 1, color: theme.dividerColor),
            IconButton(
              icon: const Icon(Icons.filter_center_focus, size: 16),
              onPressed: onZoomReset,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l.resetZoom,
              color: theme.hintColor,
            ),
          ],
        ),
      ),
    );
  }
}

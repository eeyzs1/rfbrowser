import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/services/canvas_service.dart';

class ConnectionPropertiesPanel extends ConsumerWidget {
  final VoidCallback onClose;

  const ConnectionPropertiesPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final canvasData = ref.watch(canvasProvider);
    final connId = canvasData.selectedConnectionId;
    if (connId == null) return const SizedBox.shrink();
    final conn = canvasData.connections
        .where((c) => c.id == connId)
        .firstOrNull;
    if (conn == null) return const SizedBox.shrink();
    final style = conn.style ?? CanvasConnectionStyle.defaults;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Icon(
              Icons.settings_ethernet,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.connectionProperties,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                ref.read(canvasProvider.notifier).selectConnection(null);
                onClose();
              },
              child: Icon(Icons.close, size: 14, color: theme.hintColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _propSection(
          theme,
          l.fromCard,
          _cardDropdown(theme, canvasData.cards, conn.fromCardId, (cardId) {
            final latestConn =
                ref
                    .read(canvasProvider)
                    .connections
                    .where((c) => c.id == conn.id)
                    .firstOrNull ??
                conn;
            final newFromCard = ref
                .read(canvasProvider.notifier)
                .cardById(cardId);
            final toCard = ref
                .read(canvasProvider.notifier)
                .cardById(latestConn.toCardId);
            if (newFromCard != null && toCard != null) {
              final (fromSide, toSide) = CanvasConnection.computeSides(
                newFromCard,
                toCard,
              );
              ref
                  .read(canvasProvider.notifier)
                  .updateConnection(
                    latestConn.copyWith(
                      fromCardId: cardId,
                      fromSide: fromSide,
                      toSide: toSide,
                    ),
                  );
            } else {
              ref
                  .read(canvasProvider.notifier)
                  .updateConnection(latestConn.copyWith(fromCardId: cardId));
            }
          }),
        ),
        const SizedBox(height: 8),
        _propSection(
          theme,
          l.toCard,
          _cardDropdown(theme, canvasData.cards, conn.toCardId, (cardId) {
            final latestConn =
                ref
                    .read(canvasProvider)
                    .connections
                    .where((c) => c.id == conn.id)
                    .firstOrNull ??
                conn;
            final fromCard = ref
                .read(canvasProvider.notifier)
                .cardById(latestConn.fromCardId);
            final newToCard = ref
                .read(canvasProvider.notifier)
                .cardById(cardId);
            if (fromCard != null && newToCard != null) {
              final (fromSide, toSide) = CanvasConnection.computeSides(
                fromCard,
                newToCard,
              );
              ref
                  .read(canvasProvider.notifier)
                  .updateConnection(
                    latestConn.copyWith(
                      toCardId: cardId,
                      fromSide: fromSide,
                      toSide: toSide,
                    ),
                  );
            } else {
              ref
                  .read(canvasProvider.notifier)
                  .updateConnection(latestConn.copyWith(toCardId: cardId));
            }
          }),
        ),
        const SizedBox(height: 12),
        _panelDropdown<ConnectionPath>(
          theme,
          l.pathType,
          style.pathType,
          ConnectionPath.values,
          (v) => _updateConnectionStyle(ref, conn, pathType: v),
        ),
        const SizedBox(height: 8),
        _panelDropdown<ArrowStyle>(
          theme,
          l.endArrow,
          style.arrowStyle,
          ArrowStyle.values,
          (v) => _updateConnectionStyle(ref, conn, arrowStyle: v),
        ),
        const SizedBox(height: 8),
        _panelDropdown<ArrowStyle>(
          theme,
          l.startArrow,
          style.startArrowStyle,
          ArrowStyle.values,
          (v) => _updateConnectionStyle(ref, conn, startArrowStyle: v),
        ),
        const SizedBox(height: 8),
        _propSection(
          theme,
          l.arrowSize,
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: style.arrowSize,
                  min: 4,
                  max: 20,
                  divisions: 16,
                  label: style.arrowSize.toStringAsFixed(0),
                  onChanged: (v) =>
                      _updateConnectionStyle(ref, conn, arrowSize: v),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  style.arrowSize.toStringAsFixed(0),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _propSection(
          theme,
          l.lineWidth,
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: style.strokeWidth,
                  min: 0.5,
                  max: 6,
                  divisions: 11,
                  label: style.strokeWidth.toStringAsFixed(1),
                  onChanged: (v) =>
                      _updateConnectionStyle(ref, conn, strokeWidth: v),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  style.strokeWidth.toStringAsFixed(1),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _propSection(
          theme,
          l.lineColor,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                [
                  0xFF000000,
                  0xFF1565C0,
                  0xFF2E7D32,
                  0xFFE65100,
                  0xFFC62828,
                  0xFF6A1B9A,
                  0xFF00838F,
                  0xFF4E342E,
                ].map((v) {
                  final isSelected = style.colorValue == v;
                  return GestureDetector(
                    onTap: () =>
                        _updateConnectionStyle(ref, conn, colorValue: v),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(v),
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : Border.all(color: theme.dividerColor),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _panelDropdown<LineJumpStyle>(
          theme,
          l.lineJump,
          style.lineJumpStyle,
          LineJumpStyle.values,
          (v) => _updateConnectionStyle(ref, conn, lineJumpStyle: v),
        ),
        const SizedBox(height: 8),
        _panelDropdown<FlowAnimationStyle>(
          theme,
          l.flowAnimation,
          style.flowAnimation,
          FlowAnimationStyle.values,
          (v) => _updateConnectionStyle(ref, conn, flowAnimation: v),
        ),
        const SizedBox(height: 8),
        _propSection(
          theme,
          'Waypoint Size',
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: style.waypointSize,
                  min: 3,
                  max: 16,
                  divisions: 13,
                  label: style.waypointSize.toStringAsFixed(0),
                  onChanged: (v) =>
                      _updateConnectionStyle(ref, conn, waypointSize: v),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  style.waypointSize.toStringAsFixed(0),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _propSection(
          theme,
          l.label,
          TextFormField(
            initialValue: conn.label,
            decoration: InputDecoration(
              isDense: true,
              hintText: l.connectionLabel,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
            ),
            style: theme.textTheme.bodySmall,
            onChanged: (v) => _updateConnectionLabel(ref, conn, v),
          ),
        ),
        const SizedBox(height: 8),
        _propSection(
          theme,
          l.labelFontSize,
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: style.labelFontSize == 0 ? 10 : style.labelFontSize,
                  min: 8,
                  max: 24,
                  divisions: 16,
                  label: (style.labelFontSize == 0 ? 10 : style.labelFontSize)
                      .toStringAsFixed(0),
                  onChanged: (v) =>
                      _updateConnectionStyle(ref, conn, labelFontSize: v),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  (style.labelFontSize == 0 ? 10 : style.labelFontSize)
                      .toStringAsFixed(0),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(canvasProvider.notifier).removeConnection(conn.id);
              ref.read(canvasProvider.notifier).selectConnection(null);
            },
            icon: Icon(
              Icons.delete_outline,
              size: 14,
              color: theme.colorScheme.error,
            ),
            label: Text(
              l.deleteConnection,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
          ),
        ),
      ],
    );
  }

  void _updateConnectionStyle(
    WidgetRef ref,
    CanvasConnection conn, {
    ConnectionPath? pathType,
    ArrowStyle? arrowStyle,
    ArrowStyle? startArrowStyle,
    double? strokeWidth,
    int? colorValue,
    LineJumpStyle? lineJumpStyle,
    FlowAnimationStyle? flowAnimation,
    double? arrowSize,
    double? labelFontSize,
    double? waypointSize,
  }) {
    final latestConn =
        ref
            .read(canvasProvider)
            .connections
            .where((c) => c.id == conn.id)
            .firstOrNull ??
        conn;
    final currentStyle = latestConn.style ?? CanvasConnectionStyle.defaults;
    final newStyle = CanvasConnectionStyle(
      pathType: pathType ?? currentStyle.pathType,
      arrowStyle: arrowStyle ?? currentStyle.arrowStyle,
      startArrowStyle: startArrowStyle ?? currentStyle.startArrowStyle,
      strokeWidth: strokeWidth ?? currentStyle.strokeWidth,
      colorValue: colorValue ?? currentStyle.colorValue,
      lineJumpStyle: lineJumpStyle ?? currentStyle.lineJumpStyle,
      lineJumpSize: currentStyle.lineJumpSize,
      flowAnimation: flowAnimation ?? currentStyle.flowAnimation,
      arrowSize: arrowSize ?? currentStyle.arrowSize,
      labelFontSize: labelFontSize ?? currentStyle.labelFontSize,
      waypointSize: waypointSize ?? currentStyle.waypointSize,
    );
    ref
        .read(canvasProvider.notifier)
        .updateConnection(
          latestConn.copyWith(style: newStyle, clearStyle: false),
        );
  }

  void _updateConnectionLabel(
    WidgetRef ref,
    CanvasConnection conn,
    String label,
  ) {
    final latestConn =
        ref
            .read(canvasProvider)
            .connections
            .where((c) => c.id == conn.id)
            .firstOrNull ??
        conn;
    ref
        .read(canvasProvider.notifier)
        .updateConnection(latestConn.copyWith(label: label));
  }

  Widget _propSection(ThemeData theme, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
          ),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }

  Widget _panelDropdown<T>(
    ThemeData theme,
    String label,
    T value,
    List<T> items,
    ValueChanged<T> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
          ),
        ),
        const SizedBox(height: 2),
        DropdownButtonFormField<T>(
          // ignore: deprecated_member_use
          value: value,
          key: ValueKey(value),
          isDense: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          items: items
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(
                    (v as Enum).name,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _cardDropdown(
    ThemeData theme,
    List<CanvasCard> cards,
    String selectedCardId,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: cards.any((c) => c.id == selectedCardId) ? selectedCardId : null,
      key: ValueKey(selectedCardId),
      isDense: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      items: cards
          .map(
            (card) => DropdownMenuItem(
              value: card.id,
              child: Text(
                card.title.isEmpty ? 'Untitled' : card.title,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

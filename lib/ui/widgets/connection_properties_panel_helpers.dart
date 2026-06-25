part of 'connection_properties_panel.dart';

/// Updates a connection's style with the given overrides.
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

/// Updates a connection's label.
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

/// Builds a labeled property section.
Widget _propSection(ThemeData theme, String label, Widget child) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
      ),
      const SizedBox(height: 2),
      child,
    ],
  );
}

/// Builds a labeled dropdown for enum selection.
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
        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
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

/// Builds a dropdown for selecting a card.
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

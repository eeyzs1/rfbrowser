import 'package:flutter/material.dart';
import '../../../../data/models/canvas_model.dart';
import '../../../../l10n/app_localizations.dart';

/// Result type for [MoveToLayerDialog].
///
/// - `null` → dialog cancelled.
/// - `(layerId: null)` → user chose "No Layer" (default layer).
/// - `(layerId: 'xxx')` → user chose the layer with id `xxx`.
typedef MoveToLayerResult = ({String? layerId})?;

/// Dialog for moving a card to a different layer.
///
/// Renders a radio list of available layers plus a "No Layer" (default) option.
/// The selected choice is returned as a [MoveToLayerResult]; dismissing the
/// dialog without a choice returns `null`.
class MoveToLayerDialog extends StatelessWidget {
  final String? currentLayerId;
  final List<CanvasLayer> layers;

  const MoveToLayerDialog({
    super.key,
    required this.currentLayerId,
    required this.layers,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.moveToLayer),
      content: SizedBox(
        width: 240,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(l.noLayerDefault),
              leading: Radio<String?>(
                // ignore: deprecated_member_use
                value: null,
                // ignore: deprecated_member_use
                groupValue: currentLayerId,
                // ignore: deprecated_member_use
                onChanged: (_) =>
                    Navigator.pop(context, (layerId: null)),
              ),
            ),
            ...layers.map(
              (layer) => ListTile(
                dense: true,
                title: Text(layer.name),
                leading: Radio<String?>(
                  // ignore: deprecated_member_use
                  value: layer.id,
                  // ignore: deprecated_member_use
                  groupValue: currentLayerId,
                  // ignore: deprecated_member_use
                  onChanged: (_) =>
                      Navigator.pop(context, (layerId: layer.id)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}

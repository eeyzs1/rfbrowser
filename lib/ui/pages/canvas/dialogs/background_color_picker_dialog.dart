import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

/// Result type for [BackgroundColorPickerDialog].
///
/// - `null` → dialog cancelled.
/// - `(colorValue: 0xFF...)` → user picked a background color.
/// - `(colorValue: null)` → user pressed "Clear" to remove the background color.
typedef BackgroundColorResult = ({int? colorValue})?;

/// Dialog for picking the canvas background color from a preset palette.
///
/// Returns a [BackgroundColorResult] via [Navigator.pop]. The "Clear" action
/// returns `(colorValue: null)` to distinguish it from cancellation.
class BackgroundColorPickerDialog extends StatelessWidget {
  final int? currentColorValue;

  const BackgroundColorPickerDialog({
    super.key,
    required this.currentColorValue,
  });

  static const List<Color> _presets = [
    Colors.white,
    Color(0xFFF5F5F5), // grey[100]
    Color(0xFFEEEEEE), // grey[200]
    Color(0xFFE3F2FD), // blue[50]
    Color(0xFFE8F5E9), // green[50]
    Color(0xFFFFF3E0), // orange[50]
    Color(0xFFF3E5F5), // purple[50]
    Color(0xFFFFEBEE), // red[50]
    Color(0xFF424242), // grey[800]
    Color(0xFF212121), // grey[900]
    Color(0xFF0D47A1), // blue[900]
    Color(0xFF1B5E20), // green[900]
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l.backgroundColor),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets
                .map(
                  (c) => GestureDetector(
                    onTap: () =>
                        Navigator.pop(context, (colorValue: c.toARGB32())),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: currentColorValue == c.toARGB32()
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          width: currentColorValue == c.toARGB32() ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (colorValue: null)),
          child: Text(l.clear),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}

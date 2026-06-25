import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

/// Dialog for picking a card color from a preset palette.
///
/// Returns the selected [Color] via [Navigator.pop], or `null` when cancelled.
/// When [isMulti] is `true`, the title reflects the number of selected cards.
class ColorPickerDialog extends StatelessWidget {
  final int currentColorValue;
  final bool isMulti;
  final int selectedCount;

  const ColorPickerDialog({
    super.key,
    required this.currentColorValue,
    this.isMulti = false,
    this.selectedCount = 0,
  });

  /// Preset color palette shared with the canvas view.
  static const List<Color> presets = [
    Color(0xFFFFFFFF),
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFFFF3E0),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFE0F7FA),
    Color(0xFFFFEBEE),
    Color(0xFFF1F8E9),
    Color(0xFFEDE7F6),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        isMulti
            ? 'Change Color ($selectedCount cards)'
            : l.changeColor,
      ),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets
              .map(
                (color) => GestureDetector(
                  onTap: () => Navigator.pop(context, color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: currentColorValue == color.toARGB32()
                            ? theme.colorScheme.primary
                            : theme.dividerColor,
                        width:
                            currentColorValue == color.toARGB32() ? 2.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: currentColorValue == color.toARGB32()
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                ),
              )
              .toList(),
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

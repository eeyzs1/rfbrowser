import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

/// Dialog for removing a tag from a card.
///
/// Returns the selected tag string via [Navigator.pop], or `null` when
/// dismissed without a selection.
class RemoveTagDialog extends StatelessWidget {
  final List<String> tags;

  const RemoveTagDialog({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SimpleDialog(
      title: Text(l.removeTag),
      children: tags
          .map(
            (tag) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, tag),
              child: Row(
                children: [
                  Icon(Icons.label, size: 14, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text(tag),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

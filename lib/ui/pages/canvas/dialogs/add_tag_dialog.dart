import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

/// Dialog for adding a tag to a card.
///
/// Returns the trimmed tag string via [Navigator.pop] when the user submits,
/// or `null` when cancelled. An empty string is returned as-is; callers should
/// treat empty strings as "no action".
class AddTagDialog extends StatelessWidget {
  const AddTagDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    return AlertDialog(
      title: Text(l.addTag),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: l.tagName),
        onSubmitted: (_) => Navigator.pop(context, ctrl.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: Text(l.add),
        ),
      ],
    );
  }
}

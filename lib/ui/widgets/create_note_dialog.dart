import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

Future<String?> showCreateNoteDialog(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final controller = TextEditingController();
      return AlertDialog(
        title: Text(l.newNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l.noteTitle),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.create),
          ),
        ],
      );
    },
  );
}

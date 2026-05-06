import 'package:flutter/material.dart';

Future<String?> showCreateNoteDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final controller = TextEditingController();
      return AlertDialog(
        title: const Text('New Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Note title'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
}

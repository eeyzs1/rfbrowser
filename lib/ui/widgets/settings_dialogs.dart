import 'package:flutter/material.dart';

class SelectionOption<T> {
  final T value;
  final String label;

  const SelectionOption({required this.value, required this.label});
}

Future<T?> showSelectionDialog<T>({
  required BuildContext context,
  required String title,
  required List<SelectionOption<T>> options,
  T? selectedValue,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => _SelectionDialog<T>(
      title: title,
      options: options,
      selectedValue: selectedValue,
      onSelected: (value) => Navigator.pop(ctx, value),
    ),
  );
}

class _SelectionDialog<T> extends StatelessWidget {
  final String title;
  final List<SelectionOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T> onSelected;

  const _SelectionDialog({
    required this.title,
    required this.options,
    this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(title),
      children: options.map((option) {
        final isSelected = selectedValue == option.value;
        return SimpleDialogOption(
          onPressed: () => onSelected(option.value),
          child: Row(
            children: [
              if (isSelected) const Icon(Icons.check, size: 16),
              const SizedBox(width: 8),
              Text(option.label),
            ],
          ),
        );
      }).toList(),
    );
  }
}

Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  String? hintText,
  String? labelText,
  bool obscureText = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _InputDialog(
      title: title,
      hintText: hintText,
      labelText: labelText,
      obscureText: obscureText,
      onSave: (value) => Navigator.pop(ctx, value),
    ),
  );
}

class _InputDialog extends StatelessWidget {
  final String title;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final ValueChanged<String> onSave;

  const _InputDialog({
    required this.title,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(hintText: hintText, labelText: labelText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onSave(controller.text);
            Navigator.pop(context, controller.text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<Map<String, String>?> showMultiFieldDialog({
  required BuildContext context,
  required String title,
  required List<DialogFieldConfig> fields,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => _MultiFieldDialog(
      title: title,
      fields: fields,
      onSave: (values) => Navigator.pop(ctx, values),
    ),
  );
}

class _MultiFieldDialog extends StatelessWidget {
  final String title;
  final List<DialogFieldConfig> fields;
  final ValueChanged<Map<String, String>> onSave;

  const _MultiFieldDialog({
    required this.title,
    required this.fields,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final controllers = {
      for (final field in fields)
        field.key: TextEditingController(text: field.initialValue),
    };

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in fields) ...[
            TextField(
              controller: controllers[field.key],
              obscureText: field.obscureText,
              decoration: InputDecoration(
                labelText: field.labelText,
                hintText: field.hintText,
              ),
            ),
            if (field != fields.last) const SizedBox(height: 8),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final values = {
              for (final field in fields)
                field.key: controllers[field.key]!.text,
            };
            onSave(values);
            Navigator.pop(context, values);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class DialogFieldConfig {
  final String key;
  final String? labelText;
  final String? hintText;
  final String? initialValue;
  final bool obscureText;

  const DialogFieldConfig({
    required this.key,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.obscureText = false,
  });
}

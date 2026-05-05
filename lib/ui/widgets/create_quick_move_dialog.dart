import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/quick_move_service.dart';

const _iconOptions = [
  Icons.translate,
  Icons.summarize,
  Icons.psychology,
  Icons.mail,
  Icons.spellcheck,
  Icons.bolt,
  Icons.star,
  Icons.favorite,
  Icons.lightbulb,
  Icons.auto_awesome,
  Icons.search,
  Icons.code,
  Icons.edit,
  Icons.share,
  Icons.bookmark,
];

const _colorOptions = [
  0xFF0EA5E9,
  0xFF8B5CF6,
  0xFFF43F5E,
  0xFF10B981,
  0xFFF59E0B,
  0xFF6366F1,
  0xFF14B8A6,
  0xFFF97316,
  0xFF64748B,
];

void showCreateQuickMoveDialog(
  BuildContext context,
  WidgetRef ref, {
  String prefillName = '',
}) {
  final nameController = TextEditingController(text: prefillName);
  final promptController = TextEditingController();
  var selectedIconCodePoint = Icons.bolt.codePoint;
  var selectedColorValue = 0xFF0EA5E9;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Create Quick Move'),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Command Name',
                      hintText: 'e.g. 翻译',
                      prefixText: '/',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Prompt Template',
                      hintText:
                          'Translate to English:\n\n{input}',
                      helperText: 'Supported: {input}, {pageContent}, {selectedText}, {pageUrl}, {noteContent}',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Icon',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _iconOptions.map((icon) {
                      final isSelected =
                          icon.codePoint == selectedIconCodePoint;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedIconCodePoint = icon.codePoint;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(
                                    selectedColorValue,
                                  ).withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                    color: Color(selectedColorValue),
                                    width: 2,
                                  )
                                : Border.all(color: Colors.transparent),
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: isSelected
                                ? Color(selectedColorValue)
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Color',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _colorOptions.map((colorValue) {
                      final isSelected = colorValue == selectedColorValue;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColorValue = colorValue;
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(colorValue)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final prompt = promptController.text.trim();
                if (name.isEmpty || prompt.isEmpty) return;

                ref.read(quickMoveProvider.notifier).createMove(
                      name,
                      prompt,
                      iconCodePoint: selectedIconCodePoint,
                      colorValue: selectedColorValue,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ),
  );
}

part of 'quick_moves_settings_section.dart';

/// Shows the edit dialog for an existing [QuickMove]. Extracted into a
/// part file because the icon/color picker UI makes it the single
/// largest method in the widget.
void _showEditQuickMoveDialog(
  BuildContext context,
  WidgetRef ref,
  QuickMove move,
) {
  final nameController = TextEditingController(text: move.name);
  final promptController = TextEditingController(text: move.promptTemplate);
  var iconCodePoint = move.iconCodePoint;
  var colorValue = move.colorValue;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Edit Quick Move'),
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
                      prefixText: '/',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Prompt Template',
                      helperText:
                          'Supported: {input}, {pageContent}, {selectedText}, {pageUrl}, {noteContent}',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Icon',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _iconOptions.map((icon) {
                      final isSelected = icon.codePoint == iconCodePoint;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            iconCodePoint = icon.codePoint;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(colorValue).withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                    color: Color(colorValue),
                                    width: 2,
                                  )
                                : Border.all(color: Colors.transparent),
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: isSelected
                                ? Color(colorValue)
                                : theme.hintColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Color',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _colorOptions.map((colorVal) {
                      final isSelected = colorVal == colorValue;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            colorValue = colorVal;
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(
                                        colorVal,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color:
                                      (Color(colorVal).r * 0.299 +
                                              Color(colorVal).g * 0.587 +
                                              Color(colorVal).b * 0.114) >
                                          128
                                      ? Colors.black
                                      : Colors.white,
                                )
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

                ref
                    .read(quickMoveProvider.notifier)
                    .updateMove(
                      move.id,
                      name: name,
                      promptTemplate: prompt,
                      iconCodePoint: iconCodePoint,
                      colorValue: colorValue,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}

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

part of '../canvas_page.dart';

/// The full-screen card editor dialog. Pulled into its own part file
/// because the rich-text + style controls make it the single largest
/// dialog in the canvas.
mixin _CanvasDialogsEditMixin on _CanvasViewStateBase,
    _CanvasDialogsEditRichMixin {
  @override
  void _editCard(String cardId) {
    final card = ref.read(canvasProvider.notifier).cardById(cardId);
    if (card == null) return;
    final settings = ref.read(settingsProvider);
    final l = AppLocalizations.of(context)!;
    final dialogTheme = Theme.of(context);
    final titleCtrl = TextEditingController(text: card.title);
    final titleFocus = FocusNode();
    final contentCtrl = TextEditingController(text: card.content);
    double cardFontSize = card.fontSize > 0
        ? card.fontSize
        : settings.editorFontSize * 0.85;
    int selectedColorValue = card.colorValue;
    int selectedTextColorValue = card.textColorValue;
    String selectedFontFamily = card.fontFamily;
    TextAlignH selectedAlignH = card.textAlignH;
    TextAlignV selectedAlignV = card.textAlignV;
    List<RichTextSegment> richSegments = List.from(card.richContent);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.editCardType(card.type.label)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    focusNode: titleFocus,
                    decoration: InputDecoration(labelText: l.noteTitle),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    decoration: InputDecoration(
                      labelText: switch (card.type) {
                        CanvasCardType.note => l.contentPreview,
                        CanvasCardType.text => l.note,
                        CanvasCardType.image => l.imagePath,
                        CanvasCardType.link => l.url,
                        CanvasCardType.container => l.contentPreview,
                        _ => l.contentPreview,
                      },
                    ),
                    maxLines:
                        card.type == CanvasCardType.note ||
                            card.type == CanvasCardType.text
                        ? 5
                        : 1,
                  ),
                  const SizedBox(height: 12),
                  ..._buildRichTextSection(
                    ctx: ctx,
                    l: l,
                    dialogTheme: dialogTheme,
                    richSegments: richSegments,
                    cardFontSize: cardFontSize,
                    setDialogState: setDialogState,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(l.alignH, style: dialogTheme.textTheme.bodySmall),
                      const SizedBox(width: 4),
                      SegmentedButton<TextAlignH>(
                        segments: const [
                          ButtonSegment(
                            value: TextAlignH.left,
                            icon: Icon(Icons.format_align_left, size: 16),
                          ),
                          ButtonSegment(
                            value: TextAlignH.center,
                            icon: Icon(Icons.format_align_center, size: 16),
                          ),
                          ButtonSegment(
                            value: TextAlignH.right,
                            icon: Icon(Icons.format_align_right, size: 16),
                          ),
                        ],
                        selected: {selectedAlignH},
                        onSelectionChanged: (v) =>
                            setDialogState(() => selectedAlignH = v.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(l.alignV, style: dialogTheme.textTheme.bodySmall),
                      const SizedBox(width: 4),
                      SegmentedButton<TextAlignV>(
                        segments: const [
                          ButtonSegment(
                            value: TextAlignV.top,
                            icon: Icon(Icons.vertical_align_top, size: 16),
                          ),
                          ButtonSegment(
                            value: TextAlignV.middle,
                            icon: Icon(Icons.vertical_align_center, size: 16),
                          ),
                          ButtonSegment(
                            value: TextAlignV.bottom,
                            icon: Icon(Icons.vertical_align_bottom, size: 16),
                          ),
                        ],
                        selected: {selectedAlignV},
                        onSelectionChanged: (v) =>
                            setDialogState(() => selectedAlignV = v.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(l.font, style: dialogTheme.textTheme.bodySmall),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedFontFamily.isEmpty
                            ? 'default'
                            : selectedFontFamily,
                        items: ['default', 'monospace', 'serif', 'sans-serif']
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontFamily: f == 'default' ? null : f,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(
                          () => selectedFontFamily = v == 'default' ? '' : v!,
                        ),
                        isDense: true,
                        underline: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(l.fontSize, style: dialogTheme.textTheme.bodySmall),
                      Expanded(
                        child: Slider(
                          value: cardFontSize,
                          min: 8,
                          max: 32,
                          divisions: 24,
                          label: cardFontSize.round().toString(),
                          onChanged: (v) =>
                              setDialogState(() => cardFontSize = v),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          cardFontSize.round().toString(),
                          style: dialogTheme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l.textColor,
                      style: dialogTheme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        [
                              0xFF000000,
                              0xFF444444,
                              0xFF1565C0,
                              0xFF2E7D32,
                              0xFFE65100,
                              0xFFC62828,
                              0xFF6A1B9A,
                              0xFFFFFFFF,
                            ]
                            .map(
                              (v) => GestureDetector(
                                onTap: () => setDialogState(
                                  () => selectedTextColorValue = v,
                                ),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Color(v),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: selectedTextColorValue == v
                                          ? dialogTheme.colorScheme.primary
                                          : dialogTheme.dividerColor,
                                      width: selectedTextColorValue == v
                                          ? 2
                                          : 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l.cardColor,
                      style: dialogTheme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _CanvasViewStateBase._cardColorPresets
                        .map(
                          (color) => GestureDetector(
                            onTap: () => setDialogState(
                              () => selectedColorValue = color.toARGB32(),
                            ),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: selectedColorValue == color.toARGB32()
                                      ? dialogTheme.colorScheme.primary
                                      : dialogTheme.dividerColor,
                                  width: selectedColorValue == color.toARGB32()
                                      ? 2.5
                                      : 1,
                                ),
                              ),
                              child: selectedColorValue == color.toARGB32()
                                  ? Icon(
                                      Icons.check,
                                      size: 14,
                                      color: dialogTheme.colorScheme.primary,
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final defaultSize = settings.editorFontSize * 0.85;
                ref
                    .read(canvasProvider.notifier)
                    .updateCard(
                      card.copyWith(
                        title: titleCtrl.text.trim(),
                        content: contentCtrl.text.trim(),
                        fontSize: (cardFontSize - defaultSize).abs() < 0.5
                            ? 0
                            : cardFontSize,
                        colorValue: selectedColorValue,
                        textColorValue: selectedTextColorValue,
                        fontFamily: selectedFontFamily,
                        textAlignH: selectedAlignH,
                        textAlignV: selectedAlignV,
                        richContent: richSegments,
                      ),
                    );
                Navigator.pop(ctx);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    ).then((_) => titleFocus.dispose());
  }
}

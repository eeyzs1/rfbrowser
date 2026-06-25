part of '../canvas_page.dart';

/// Rich-text editing section of the card editor dialog. Extracted into
/// its own part file because the toolbar + segment list is the single
/// largest chunk of the editor UI.
mixin _CanvasDialogsEditRichMixin on _CanvasViewStateBase {
  /// Builds the rich-text toolbar and segment list widgets for the card
  /// editor dialog. Returns a list of widgets to be inserted into the
  /// dialog's column.
  List<Widget> _buildRichTextSection({
    required BuildContext ctx,
    required AppLocalizations l,
    required ThemeData dialogTheme,
    required List<RichTextSegment> richSegments,
    required double cardFontSize,
    required void Function(void Function()) setDialogState,
  }) {
    return [
      Text(l.richText, style: dialogTheme.textTheme.bodySmall),
      const SizedBox(height: 4),
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.format_bold, size: 18),
            tooltip: l.bold,
            onPressed: () {
              richSegments.add(
                const RichTextSegment(
                  text: 'bold text',
                  type: RichTextSegmentType.bold,
                ),
              );
              setDialogState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.format_italic, size: 18),
            tooltip: l.italic,
            onPressed: () {
              richSegments.add(
                const RichTextSegment(
                  text: 'italic text',
                  type: RichTextSegmentType.italic,
                ),
              );
              setDialogState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.format_underlined, size: 18),
            tooltip: l.underline,
            onPressed: () {
              richSegments.add(
                const RichTextSegment(
                  text: 'underlined',
                  type: RichTextSegmentType.underline,
                ),
              );
              setDialogState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.code, size: 18),
            tooltip: l.code,
            onPressed: () {
              richSegments.add(
                const RichTextSegment(
                  text: 'code',
                  type: RichTextSegmentType.code,
                ),
              );
              setDialogState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.strikethrough_s, size: 18),
            tooltip: l.strikethrough,
            onPressed: () {
              richSegments.add(
                const RichTextSegment(
                  text: 'deleted',
                  type: RichTextSegmentType.strikethrough,
                ),
              );
              setDialogState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: l.text,
            onPressed: () {
              richSegments.add(const RichTextSegment(text: 'text'));
              setDialogState(() {});
            },
          ),
          const Spacer(),
          if (richSegments.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: l.clear,
              onPressed: () {
                richSegments.clear();
                setDialogState(() {});
              },
            ),
        ],
      ),
      if (richSegments.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: dialogTheme.dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: richSegments.asMap().entries.map((e) {
              final idx = e.key;
              final seg = e.value;
              final style = switch (seg.type) {
                RichTextSegmentType.bold => const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                RichTextSegmentType.italic => const TextStyle(
                  fontStyle: FontStyle.italic,
                ),
                RichTextSegmentType.underline => const TextStyle(
                  decoration: TextDecoration.underline,
                ),
                RichTextSegmentType.code => const TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: Colors.black12,
                ),
                RichTextSegmentType.strikethrough => const TextStyle(
                  decoration: TextDecoration.lineThrough,
                ),
                RichTextSegmentType.text => const TextStyle(),
              };
              return GestureDetector(
                onDoubleTap: () {
                  final ctrl = TextEditingController(text: seg.text);
                  showDialog(
                    context: ctx,
                    builder: (dctx) => AlertDialog(
                      title: Text(l.editSegment(seg.type.name)),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: Text(l.cancel),
                        ),
                        FilledButton(
                          onPressed: () {
                            richSegments[idx] = RichTextSegment(
                              text: ctrl.text,
                              type: seg.type,
                            );
                            Navigator.pop(dctx);
                            setDialogState(() {});
                          },
                          child: Text(l.ok),
                        ),
                      ],
                    ),
                  );
                },
                child: Chip(
                  label: Text(
                    seg.text,
                    style: style.copyWith(
                      fontSize: cardFontSize * 0.8,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 12),
                  onDeleted: () {
                    richSegments.removeAt(idx);
                    setDialogState(() {});
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }).toList(),
          ),
        ),
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/canvas_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/canvas_service.dart';
import '../../../services/settings_service.dart';

class CanvasInlineEditor extends ConsumerStatefulWidget {
  final String cardId;
  final double scale;
  final Offset screenPos;
  final double cardScreenW;
  final double cardScreenH;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode titleFocus;
  final FocusNode contentFocus;
  final VoidCallback onTitleSubmitted;

  const CanvasInlineEditor({
    required this.cardId,
    required this.scale,
    required this.screenPos,
    required this.cardScreenW,
    required this.cardScreenH,
    required this.titleController,
    required this.contentController,
    required this.titleFocus,
    required this.contentFocus,
    required this.onTitleSubmitted,
    super.key,
  });

  @override
  ConsumerState<CanvasInlineEditor> createState() => _CanvasInlineEditorState();
}

class _CanvasInlineEditorState extends ConsumerState<CanvasInlineEditor> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final card = ref.read(canvasProvider.notifier).cardById(widget.cardId);
    if (card == null) return const SizedBox.shrink();

    final settings = ref.read(settingsProvider);
    final cardFontSize = card.effectiveFontSize(settings.editorFontSize);
    final scaledFont = cardFontSize * widget.scale;
    final headerH = 30.0 * widget.scale;
    final accentW = 3.0 * widget.scale;
    final padH = 10.0 * widget.scale;

    return Positioned(
      left: widget.screenPos.dx,
      top: widget.screenPos.dy,
      width: widget.cardScreenW,
      height: widget.cardScreenH,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    Container(
                      height: headerH,
                      padding: EdgeInsets.only(
                        left: accentW + padH,
                        right: accentW + padH,
                      ),
                      color: Colors.transparent,
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: widget.titleController,
                        focusNode: widget.titleFocus,
                        style: TextStyle(
                          fontSize: scaledFont,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2 / widget.scale,
                          height: 1.0,
                        ),
                        strutStyle: StrutStyle(
                          forceStrutHeight: true,
                          height: 1.0,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: l.title,
                          hintStyle: TextStyle(
                            color: theme.hintColor.withValues(alpha: 0.5),
                            fontSize: scaledFont,
                          ),
                        ),
                        onSubmitted: (_) => widget.onTitleSubmitted(),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.transparent,
                        padding: EdgeInsets.only(
                          left: accentW + padH,
                          right: accentW + padH,
                          top: 4 * widget.scale,
                        ),
                        child: TextField(
                          controller: widget.contentController,
                          focusNode: widget.contentFocus,
                          style: TextStyle(
                            fontSize: scaledFont * 1.06,
                            height: 1.4,
                          ),
                          strutStyle: StrutStyle(
                            forceStrutHeight: true,
                            height: 1.4,
                          ),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: card.type == CanvasCardType.note
                                ? l.noteContent
                                : l.typeSomething,
                            hintStyle: TextStyle(
                              color: theme.hintColor.withValues(alpha: 0.5),
                              fontSize: scaledFont * 1.06,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: accentW,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/editor/markdown_highlighter.dart';

class HighlightedTextEditingController extends TextEditingController {
  final MarkdownHighlighter _highlighter = MarkdownHighlighter();
  ThemeData? _theme;

  void setTheme(ThemeData theme) {
    _theme = theme;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = _theme ?? Theme.of(context);
    final text = this.text;

    if (text.isEmpty) {
      return TextSpan(text: '', style: style);
    }

    final ranges = _highlighter.highlight(text);

    if (ranges.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    int currentPos = 0;

    for (final range in ranges) {
      if (range.start > currentPos) {
        spans.add(TextSpan(
          text: text.substring(currentPos, range.start),
          style: style,
        ));
      }
      if (range.start >= currentPos) {
        final rangeText = text.substring(
          range.start,
          range.end.clamp(0, text.length),
        );
        spans.add(TextSpan(
          text: rangeText,
          style: range.style(theme).merge(style?.copyWith(
            color: null,
            fontWeight: null,
            fontStyle: null,
            fontSize: null,
            decoration: null,
            backgroundColor: null,
          )),
        ));
        currentPos = range.end;
      }
    }

    if (currentPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPos),
        style: style,
      ));
    }

    return TextSpan(style: style, children: spans);
  }
}

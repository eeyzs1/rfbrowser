import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/editor/markdown_highlighter.dart';

/// A [TextEditingController] that applies markdown syntax highlighting.
///
/// Highlighting strategy (mirrors how VS Code / Obsidian stay responsive):
/// - Short notes (≤ [_syncThreshold] chars): highlighted synchronously in
///   [buildTextSpan]. The 12-regex scan takes only a few ms for small text,
///   so this is imperceptible and avoids a second layout pass.
/// - Long notes (> [_syncThreshold] chars): [buildTextSpan] returns plain
///   text instantly so the note paints immediately, then a debounced
///   background scan produces the [HighlightRange]s and triggers a re-render.
///   The scan runs in a [Timer] callback — the frame has already painted by
///   then, so the user never sees a frozen UI.
class HighlightedTextEditingController extends TextEditingController {
  final MarkdownHighlighter _highlighter = MarkdownHighlighter();
  ThemeData? _theme;

  List<HighlightRange>? _ranges;
  String? _rangesForText;
  String? _pendingText;
  Timer? _highlightTimer;
  bool _disposed = false;

  /// Notes at or below this length are highlighted synchronously.
  static const _syncThreshold = 2000;

  void setTheme(ThemeData theme) {
    _theme = theme;
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _disposed = true;
    super.dispose();
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
      _highlightTimer?.cancel();
      _pendingText = null;
      return TextSpan(text: '', style: style);
    }

    // Cache hit: ranges already computed for this exact text.
    if (_rangesForText == text && _ranges != null) {
      return _buildSpan(text, _ranges!, theme, style);
    }

    // Short notes: compute synchronously. The scan is only a few ms and
    // this avoids a double layout pass (plain → highlighted).
    if (text.length <= _syncThreshold) {
      final ranges = _highlighter.highlight(text);
      _rangesForText = text;
      _ranges = ranges;
      _pendingText = null;
      return _buildSpan(text, ranges, theme, style);
    }

    // Long notes: render plain text immediately, schedule a debounced
    // background scan so the UI never blocks on the regex pass.
    _scheduleHighlight(text);
    return TextSpan(text: text, style: style);
  }

  void _scheduleHighlight(String text) {
    if (_pendingText == text) return; // already scheduled/in flight
    _pendingText = text;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 120), () {
      if (_disposed) return;
      _computeHighlight(text);
    });
  }

  void _computeHighlight(String text) {
    if (_pendingText != text) return;
    final ranges = _highlighter.highlight(text);
    _rangesForText = text;
    _ranges = ranges;
    _pendingText = null;
    notifyListeners();
  }

  TextSpan _buildSpan(
    String text,
    List<HighlightRange> ranges,
    ThemeData theme,
    TextStyle? style,
  ) {
    if (ranges.isEmpty) return TextSpan(text: text, style: style);

    final sorted = List<HighlightRange>.from(ranges)
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    int currentPos = 0;

    for (final range in sorted) {
      if (range.start > currentPos) {
        spans.add(
          TextSpan(text: text.substring(currentPos, range.start), style: style),
        );
      }
      if (range.start >= currentPos) {
        final rangeText = text.substring(
          range.start,
          range.end.clamp(0, text.length),
        );
        spans.add(
          TextSpan(
            text: rangeText,
            style: range.style(theme).merge(
              style?.copyWith(
                color: null,
                fontWeight: null,
                fontStyle: null,
                fontSize: null,
                decoration: null,
                backgroundColor: null,
              ),
            ),
          ),
        );
        currentPos = range.end;
      }
    }

    if (currentPos < text.length) {
      spans.add(TextSpan(text: text.substring(currentPos), style: style));
    }

    return TextSpan(style: style, children: spans);
  }
}

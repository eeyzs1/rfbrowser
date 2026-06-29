import 'dart:async';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import '../../core/editor/markdown_highlighter.dart';

/// Runs [MarkdownHighlighter.highlight] in a worker isolate so the UI thread
/// never blocks on long notes (project_rules.md Rule 6.1: >2000 chars must
/// use `compute()`).
///
/// Returns a primitive, isolate-safe representation: each element is
/// `[start, end, typeIndex, language?]`. The main isolate reconstructs
/// [HighlightRange]s from this list (custom classes are not guaranteed to
/// transfer cleanly across isolates on all Flutter versions).
List<List<dynamic>> _highlightInIsolate(String text) {
  final ranges = MarkdownHighlighter().highlight(text);
  return ranges
      .map((r) => <dynamic>[r.start, r.end, r.type.index, r.language])
      .toList();
}

/// A [TextEditingController] that applies markdown syntax highlighting.
///
/// Highlighting strategy (mirrors how VS Code / Obsidian stay responsive):
/// - Short notes (≤ [_syncThreshold] chars): highlighted synchronously in
///   [buildTextSpan]. The 12-regex scan takes only a few ms for small text,
///   so this is imperceptible and avoids a second layout pass.
/// - Long notes (> [_syncThreshold] chars): [buildTextSpan] returns plain
///   text instantly so the note paints immediately, then a debounced
///   (120ms) background scan produces the [HighlightRange]s and triggers a
///   re-render. The scan runs in a worker isolate via [compute] so the UI
///   thread never blocks on the regex pass (Rule 6.1).
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
      _computeHighlightAsync(text);
    });
  }

  Future<void> _computeHighlightAsync(String text) async {
    // Stale check before starting the isolate: text may have changed during
    // the 120ms debounce window.
    if (_pendingText != text) return;
    final serialized = await compute(_highlightInIsolate, text);
    // Stale check after the isolate: text may have changed while the worker
    // was running, or the controller may have been disposed. Either way,
    // discard the result — a newer compute is already in flight.
    if (_disposed || _pendingText != text) return;
    _ranges = serialized
        .map((r) => HighlightRange(
              start: r[0] as int,
              end: r[1] as int,
              type: HighlightType.values[r[2] as int],
              language: r[3] as String?,
            ))
        .toList();
    _rangesForText = text;
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

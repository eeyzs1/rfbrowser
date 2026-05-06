import 'package:flutter/material.dart';

enum HighlightType {
  heading,
  bold,
  italic,
  code,
  codeBlock,
  link,
  wikilink,
  embed,
  list,
  blockquote,
  tag,
  contextRef,
}

class HighlightRange {
  final int start;
  final int end;
  final HighlightType type;
  final String? language;

  HighlightRange({required this.start, required this.end, required this.type, this.language});

  TextStyle style(ThemeData theme) {
    switch (type) {
      case HighlightType.heading:
        return TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        );
      case HighlightType.bold:
        return TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        );
      case HighlightType.italic:
        return TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface);
      case HighlightType.code:
        return TextStyle(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: theme.colorScheme.tertiary,
        );
      case HighlightType.codeBlock:
        return TextStyle(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        );
      case HighlightType.link:
        return TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        );
      case HighlightType.wikilink:
        return TextStyle(
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        );
      case HighlightType.embed:
        return TextStyle(
          color: theme.colorScheme.secondary,
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
        );
      case HighlightType.list:
        return TextStyle(color: theme.colorScheme.primary);
      case HighlightType.blockquote:
        return TextStyle(
          color: theme.hintColor,
          fontStyle: FontStyle.italic,
        );
      case HighlightType.tag:
        return TextStyle(
          color: theme.colorScheme.tertiary,
          fontWeight: FontWeight.w500,
        );
      case HighlightType.contextRef:
        return TextStyle(
          color: theme.colorScheme.tertiary,
          backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.1),
        );
    }
  }
}

class MarkdownHighlighter {
  static final _headingRegex = RegExp(r'^(#{1,6})\s+.+$', multiLine: true);
  static final _boldRegex = RegExp(r'\*\*(.+?)\*\*');
  static final _codeBlockRegex = RegExp(r'```[\s\S]*?```');
  static final _codeBlockLangRegex = RegExp(r'```(\w+)');
  static final _inlineCodeRegex = RegExp(r'`([^`]+)`');
  static final _linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
  static final _wikilinkRegex = RegExp(r'\[\[([^\]]+)\]\]');
  static final _embedRegex = RegExp(r'!\[\[([^\]]+)\]\]');
  static final _listRegex = RegExp(r'^[\s]*[-*+]\s+', multiLine: true);
  static final _blockquoteRegex = RegExp(r'^>\s+.+$', multiLine: true);
  static final _tagRegex = RegExp(r'(?:^|\s)#[a-zA-Z\u4e00-\u9fff][\w\u4e00-\u9fff-]*');
  static final _contextRefRegex = RegExp(r'@(note|web|file|agent|clip)\[([^\]]+)\]');

  List<HighlightRange> highlight(String text) {
    final ranges = <HighlightRange>[];

    for (final match in _embedRegex.allMatches(text)) {
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.embed,
      ));
    }

    for (final match in _wikilinkRegex.allMatches(text)) {
      if (!ranges.any((r) => r.start <= match.start && r.end >= match.end)) {
        ranges.add(HighlightRange(
          start: match.start,
          end: match.end,
          type: HighlightType.wikilink,
        ));
      }
    }

    for (final match in _headingRegex.allMatches(text)) {
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.heading,
      ));
    }

    for (final match in _boldRegex.allMatches(text)) {
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.bold,
      ));
    }

    for (final match in _codeBlockRegex.allMatches(text)) {
      final blockText = match.group(0) ?? '';
      final langMatch = _codeBlockLangRegex.firstMatch(blockText);
      final language = langMatch?.group(1);
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.codeBlock,
        language: language,
      ));
    }

    for (final match in _inlineCodeRegex.allMatches(text)) {
      if (!ranges.any((r) => r.start <= match.start && r.end >= match.end)) {
        ranges.add(HighlightRange(
          start: match.start,
          end: match.end,
          type: HighlightType.code,
        ));
      }
    }

    for (final match in _linkRegex.allMatches(text)) {
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.link,
      ));
    }

    for (final match in _listRegex.allMatches(text)) {
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.list,
      ));
    }

    for (final match in _blockquoteRegex.allMatches(text)) {
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.blockquote,
      ));
    }

    for (final match in _tagRegex.allMatches(text)) {
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.tag,
      ));
    }

    for (final match in _contextRefRegex.allMatches(text)) {
      ranges.add(HighlightRange(
        start: match.start,
        end: match.end,
        type: HighlightType.contextRef,
      ));
    }

    return ranges;
  }
}

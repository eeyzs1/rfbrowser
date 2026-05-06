import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/editor/markdown_highlighter.dart';

void main() {
  group('MarkdownHighlighter', () {
    test('AC-P5-3-1: heading, bold, link produce different highlight types', () {
      final highlighter = MarkdownHighlighter();
      final text = '# Title\n**bold**\n[link](url)';
      final ranges = highlighter.highlight(text);

      final types = ranges.map((r) => r.type).toSet();
      expect(types, containsAll([HighlightType.heading, HighlightType.bold, HighlightType.link]));
    });

    test('AC-P5-3-2: [[wikilink]] produces wikilink highlight type', () {
      final highlighter = MarkdownHighlighter();
      final text = 'See [[量子计算]] for details';
      final ranges = highlighter.highlight(text);

      final wikilinkRanges = ranges.where((r) => r.type == HighlightType.wikilink).toList();
      expect(wikilinkRanges.isNotEmpty, true);
      final range = wikilinkRanges.first;
      expect(text.substring(range.start, range.end), contains('量子计算'));
    });

    test('AC-P5-3-4: code block produces codeBlock highlight with language', () {
      final highlighter = MarkdownHighlighter();
      final text = 'Before\n```dart\nprint("hello")\n```\nAfter';
      final ranges = highlighter.highlight(text);

      final codeRanges = ranges.where((r) => r.type == HighlightType.codeBlock).toList();
      expect(codeRanges.isNotEmpty, true);
      expect(codeRanges.first.language, 'dart');
    });

    test('empty text produces no ranges', () {
      final highlighter = MarkdownHighlighter();
      final ranges = highlighter.highlight('');
      expect(ranges.isEmpty, true);
    });

    test('plain text with no markdown produces no ranges', () {
      final highlighter = MarkdownHighlighter();
      final ranges = highlighter.highlight('Just plain text nothing special');
      expect(ranges.isEmpty, true);
    });

    test('tag highlight works for #project and #important', () {
      final highlighter = MarkdownHighlighter();
      final text = 'This is #project and #important';
      final ranges = highlighter.highlight(text);

      final tagRanges = ranges.where((r) => r.type == HighlightType.tag).toList();
      expect(tagRanges.length, 2);
    });

    test('context ref highlight works for @note[] and @web[]', () {
      final highlighter = MarkdownHighlighter();
      final text = 'See @note[量子计算] and @web[https://example.com]';
      final ranges = highlighter.highlight(text);

      final refRanges = ranges.where((r) => r.type == HighlightType.contextRef).toList();
      expect(refRanges.length, 2);
    });

    test('embed syntax ![[file]] produces embed highlight', () {
      final highlighter = MarkdownHighlighter();
      final text = 'Here is ![[image.png]] embedded';
      final ranges = highlighter.highlight(text);

      final embedRanges = ranges.where((r) => r.type == HighlightType.embed).toList();
      expect(embedRanges.isNotEmpty, true);
    });

    test('blockquote produces blockquote highlight', () {
      final highlighter = MarkdownHighlighter();
      final text = '> This is a quote';
      final ranges = highlighter.highlight(text);

      final quoteRanges = ranges.where((r) => r.type == HighlightType.blockquote).toList();
      expect(quoteRanges.isNotEmpty, true);
    });

    test('list item produces list highlight', () {
      final highlighter = MarkdownHighlighter();
      final text = '- First item\n- Second item';
      final ranges = highlighter.highlight(text);

      final listRanges = ranges.where((r) => r.type == HighlightType.list).toList();
      expect(listRanges.isNotEmpty, true);
    });

    test('AC-P5-3-5: highlight 1000 lines under 50ms', () {
      final highlighter = MarkdownHighlighter();
      final lines = List.generate(
        1000,
        (i) => switch (i % 5) {
          0 => '# Heading $i',
          1 => 'This is **bold** and *italic* text on line $i',
          2 => '- List item $i with [[link-$i]]',
          3 => '```dart\ncode block $i\n```',
          _ => 'Normal text on line $i with `inline code` and #tag$i',
        },
      );
      final text = lines.join('\n');

      final sw = Stopwatch()..start();
      final ranges = highlighter.highlight(text);
      sw.stop();

      expect(ranges, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });
}

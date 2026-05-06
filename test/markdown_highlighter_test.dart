import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/editor/markdown_highlighter.dart';
import 'package:rfbrowser/core/editor/sync_scroll_controller.dart';

void main() {
  group('MarkdownHighlighter', () {
    late MarkdownHighlighter highlighter;

    setUp(() {
      highlighter = MarkdownHighlighter();
    });

    test('AC-P5-3-1: different highlight types for markdown syntax', () {
      final text = '# Title\n**bold**\n[link](url)';
      final ranges = highlighter.highlight(text);

      final types = ranges.map((r) => r.type).toSet();
      expect(types.length, greaterThanOrEqualTo(3));
      expect(types, contains(HighlightType.heading));
      expect(types, contains(HighlightType.bold));
      expect(types, contains(HighlightType.link));
    });

    test('AC-P5-3-2: wikilink highlighted', () {
      final text = 'See [[量子计算]] for details';
      final ranges = highlighter.highlight(text);

      final wikilinks = ranges.where((r) => r.type == HighlightType.wikilink).toList();
      expect(wikilinks.length, 1);
      expect(wikilinks.first.start, lessThan(wikilinks.first.end));
    });

    test('heading highlight', () {
      final text = '# Main Title\nSome text\n## Sub Title';
      final ranges = highlighter.highlight(text);

      final headings = ranges.where((r) => r.type == HighlightType.heading).toList();
      expect(headings.length, 2);
    });

    test('code block highlight', () {
      final text = 'Before\n```dart\nprint("hi");\n```\nAfter';
      final ranges = highlighter.highlight(text);

      final codeBlocks = ranges.where((r) => r.type == HighlightType.codeBlock).toList();
      expect(codeBlocks.length, 1);
    });

    test('AC-P5-3-4: code block with language identifier', () {
      final text = '```dart\nprint("hi");\n```';
      final ranges = highlighter.highlight(text);

      final codeBlocks = ranges.where((r) => r.type == HighlightType.codeBlock).toList();
      expect(codeBlocks.length, 1);
      expect(codeBlocks.first.language, 'dart');
    });

    test('AC-P5-3-4: code block without language returns null language', () {
      final text = '```\nplain code\n```';
      final ranges = highlighter.highlight(text);

      final codeBlocks = ranges.where((r) => r.type == HighlightType.codeBlock).toList();
      expect(codeBlocks.length, 1);
      expect(codeBlocks.first.language, isNull);
    });

    test('AC-P5-3-4: code block with python language', () {
      final text = '```python\nprint("hello")\n```';
      final ranges = highlighter.highlight(text);

      final codeBlocks = ranges.where((r) => r.type == HighlightType.codeBlock).toList();
      expect(codeBlocks.length, 1);
      expect(codeBlocks.first.language, 'python');
    });

    test('inline code highlight', () {
      final text = 'Use `var x = 1` here';
      final ranges = highlighter.highlight(text);

      final codes = ranges.where((r) => r.type == HighlightType.code).toList();
      expect(codes.length, 1);
    });

    test('tag highlight', () {
      final text = 'This is #project work';
      final ranges = highlighter.highlight(text);

      final tags = ranges.where((r) => r.type == HighlightType.tag).toList();
      expect(tags.length, 1);
    });

    test('embed syntax highlighted differently from wikilink', () {
      final text = '[[link]] and ![[embed]]';
      final ranges = highlighter.highlight(text);

      final embeds = ranges.where((r) => r.type == HighlightType.embed).toList();
      final wikilinks = ranges.where((r) => r.type == HighlightType.wikilink).toList();
      expect(embeds.length, 1);
      expect(wikilinks.length, 1);
    });

    test('context reference highlight', () {
      final text = 'Check @note[量子计算] for details';
      final ranges = highlighter.highlight(text);

      final refs = ranges.where((r) => r.type == HighlightType.contextRef).toList();
      expect(refs.length, 1);
    });

    test('empty text returns no ranges', () {
      final ranges = highlighter.highlight('');
      expect(ranges, isEmpty);
    });

    test('plain text returns no ranges', () {
      final ranges = highlighter.highlight('Just plain text without any markdown');
      expect(ranges, isEmpty);
    });

    test('AC-P5-3-5: highlight 1000 lines under 50ms', () {
      final buffer = StringBuffer();
      for (int i = 0; i < 1000; i++) {
        buffer.writeln('Line $i with **bold** and [[link]] and `code`');
      }
      final text = buffer.toString();

      final sw = Stopwatch()..start();
      final ranges = highlighter.highlight(text);
      sw.stop();

      expect(ranges, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });

  group('SyncScrollController', () {
    test('AC-P5-3-3: extractHeadingLineNumbers finds heading lines', () {
      final controller = SyncScrollController(
        editorController: ScrollController(),
        previewController: ScrollController(),
      );

      final text = '# Title\nSome text\n## Section 1\nMore text\n### Section 2';
      final headings = controller.extractHeadingLineNumbers(text);

      expect(headings, [0, 2, 4]);

      controller.detach();
    });

    test('AC-P5-3-3: findPreviewHeadingForLine returns correct heading', () {
      final controller = SyncScrollController(
        editorController: ScrollController(),
        previewController: ScrollController(),
      );

      controller.updateHeadingPositions([0, 5, 10], [0.0, 200.0, 400.0]);

      expect(controller.findPreviewHeadingForLine(0), 0);
      expect(controller.findPreviewHeadingForLine(3), 0);
      expect(controller.findPreviewHeadingForLine(7), 1);
      expect(controller.findPreviewHeadingForLine(15), 2);

      controller.detach();
    });

    test('AC-P5-3-3: findEditorLineForPreviewHeading returns correct line', () {
      final controller = SyncScrollController(
        editorController: ScrollController(),
        previewController: ScrollController(),
      );

      controller.updateHeadingPositions([0, 5, 10], [0.0, 200.0, 400.0]);

      expect(controller.findEditorLineForPreviewHeading(0), 0);
      expect(controller.findEditorLineForPreviewHeading(1), 5);
      expect(controller.findEditorLineForPreviewHeading(2), 10);

      controller.detach();
    });

    test('AC-P5-3-3: empty heading positions return 0', () {
      final controller = SyncScrollController(
        editorController: ScrollController(),
        previewController: ScrollController(),
      );

      expect(controller.findPreviewHeadingForLine(5), 0);
      expect(controller.findEditorLineForPreviewHeading(0), 0);

      controller.detach();
    });
  });
}

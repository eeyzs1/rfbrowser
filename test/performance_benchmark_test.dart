import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/stores/vector_store.dart';
import 'package:rfbrowser/core/editor/markdown_highlighter.dart';
import 'package:rfbrowser/core/graph/layout_engine.dart';

void main() {
  group('VectorStore Performance', () {
    test('AC-P4-5-2: search 1000 vectors under 200ms', () {
      final store = VectorStore();
      final rng = Random(42);
      const dimensions = 128;
      const noteCount = 1000;

      for (var i = 0; i < noteCount; i++) {
        final embedding = List.generate(
          dimensions,
          (_) => rng.nextDouble() * 2 - 1,
        );
        store.insert('note-$i', embedding, metadata: {'title': 'Note $i'});
      }

      final query = List.generate(
        dimensions,
        (_) => rng.nextDouble() * 2 - 1,
      );

      final sw = Stopwatch()..start();
      final results = store.search(query, topK: 20);
      sw.stop();

      expect(results.length, 20);
      expect(sw.elapsedMilliseconds, lessThan(200));
    });
  });

  group('Graph Layout Performance', () {
    test('AC-P4-5-3: 500 node layout iteration under 16ms', () {
      final engine = ForceDirectedLayout();
      final nodes = <LayoutNode>[];
      final edges = <LayoutEdge>[];

      for (var i = 0; i < 500; i++) {
        nodes.add(LayoutNode(
          id: 'n$i',
          x: (i % 25) * 40.0,
          y: (i ~/ 25) * 40.0,
        ));
      }

      for (var i = 0; i < 500; i++) {
        if (i + 1 < 500) {
          edges.add(LayoutEdge(sourceId: 'n$i', targetId: 'n${i + 1}'));
        }
        if (i + 25 < 500) {
          edges.add(LayoutEdge(sourceId: 'n$i', targetId: 'n${i + 25}'));
        }
      }

      final sw = Stopwatch()..start();
      engine.computeIncremental(nodes, edges, 1);
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(16));
    });
  });

  group('Markdown Highlighter Performance', () {
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

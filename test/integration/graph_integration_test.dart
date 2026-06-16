import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';
import 'package:rfbrowser/core/graph/graph_algorithm.dart';
import 'package:rfbrowser/core/graph/filter_engine.dart';
import 'package:rfbrowser/core/graph/layout_engine.dart';

Note makeNote(String id, String title, String content) {
  return Note(
    id: id,
    title: title,
    filePath: '$title.md',
    content: content,
    created: DateTime.now(),
    modified: DateTime.now(),
  );
}

Link makeLink(
  String sourceId,
  String targetId, {
  LinkType type = LinkType.wikilink,
}) {
  return Link(sourceId: sourceId, targetId: targetId, type: type);
}

void main() {
  group('Graph Algorithm Integration', () {
    test('shortestPath finds direct connection', () {
      final notes = [makeNote('a', 'A', ''), makeNote('b', 'B', '')];
      final links = [makeLink('a', 'b')];
      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);

      final path = algo.shortestPath('a', 'b');
      expect(path, equals(['a', 'b']));
    });

    test('shortestPath finds path through intermediate node', () {
      final notes = [
        makeNote('a', 'A', ''),
        makeNote('b', 'B', ''),
        makeNote('c', 'C', ''),
      ];
      final links = [makeLink('a', 'b'), makeLink('b', 'c')];
      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);

      final path = algo.shortestPath('a', 'c');
      expect(path, equals(['a', 'b', 'c']));
    });

    test('shortestPath returns empty when no path exists', () {
      final notes = [
        makeNote('a', 'A', ''),
        makeNote('b', 'B', ''),
        makeNote('c', 'C', ''),
      ];
      final links = [makeLink('a', 'b')];
      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);

      final path = algo.shortestPath('a', 'c');
      expect(path, isEmpty);
    });

    test('shortestPath self-loop returns single node', () {
      final notes = [makeNote('a', 'A', '')];
      final algo = GraphAlgorithm(allNotes: notes, allLinks: []);

      final path = algo.shortestPath('a', 'a');
      expect(path, equals(['a']));
    });

    test('shortestPath unknown node returns empty', () {
      final notes = [makeNote('a', 'A', '')];
      final algo = GraphAlgorithm(allNotes: notes, allLinks: []);

      final path = algo.shortestPath('a', 'unknown');
      expect(path, isEmpty);
    });

    test('connectedComponents groups nodes', () {
      final notes = [
        makeNote('a', 'A', ''),
        makeNote('b', 'B', ''),
        makeNote('c', 'C', ''),
        makeNote('d', 'D', ''),
      ];
      final links = [makeLink('a', 'b'), makeLink('c', 'd')];
      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);

      final components = algo.connectedComponents();
      expect(components.componentCount, 2);
    });

    test('pageRank assigns scores to nodes', () {
      final notes = [
        makeNote('a', 'A', ''),
        makeNote('b', 'B', ''),
        makeNote('c', 'C', ''),
      ];
      final links = [
        makeLink('a', 'b'),
        makeLink('b', 'c'),
        makeLink('c', 'a'),
      ];
      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);

      final pr = algo.pageRank();
      expect(pr, isNotEmpty);
      expect(pr.length, 3);
      for (final score in pr.values) {
        expect(score, greaterThan(0.0));
      }
    });

    test('getGraphStats returns statistics', () {
      final notes = [
        makeNote('a', 'A', ''),
        makeNote('b', 'B', ''),
        makeNote('c', 'C', ''),
      ];
      final links = [makeLink('a', 'b'), makeLink('b', 'c')];
      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);

      final stats = algo.getGraphStats();
      expect(stats.totalNodes, 3);
      expect(stats.totalEdges, 2);
    });
  });

  group('Filter Engine Integration', () {
    test('filterByTag returns notes with matching tag', () {
      final notes = [
        Note(
          id: 'n1',
          title: 'AI',
          filePath: 'ai.md',
          content: '',
          tags: ['ai', 'tech'],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
        Note(
          id: 'n2',
          title: 'Food',
          filePath: 'food.md',
          content: '',
          tags: ['food'],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
        Note(
          id: 'n3',
          title: 'ML',
          filePath: 'ml.md',
          content: '',
          tags: ['ai', 'ml'],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];

      final filter = GraphFilter(allNotes: notes, allLinks: []);
      final filtered = filter.filterByTag('ai');
      expect(filtered.length, 2);
      expect(filtered.any((n) => n.title == 'AI'), isTrue);
      expect(filtered.any((n) => n.title == 'ML'), isTrue);
    });

    test('filterByTag returns empty for unknown tag', () {
      final notes = [
        Note(
          id: 'n1',
          title: 'A',
          filePath: 'a.md',
          content: '',
          tags: ['x'],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];

      final filter = GraphFilter(allNotes: notes, allLinks: []);
      final filtered = filter.filterByTag('unknown');
      expect(filtered, isEmpty);
    });

    test('filterByDateRange filters by date', () {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'n1',
          title: 'Flutter Guide',
          filePath: 'fg.md',
          content: 'A comprehensive guide to Flutter',
          created: now,
          modified: now,
        ),
        Note(
          id: 'n2',
          title: 'Dart Tips',
          filePath: 'dt.md',
          content: 'Dart programming tips and tricks',
          created: now.subtract(const Duration(days: 30)),
          modified: now.subtract(const Duration(days: 30)),
        ),
      ];

      final filter = GraphFilter(allNotes: notes, allLinks: []);
      final filtered = filter.filterByDateRange(
        now.subtract(const Duration(days: 10)),
        now,
      );
      expect(filtered.length, 1);
      expect(filtered.first.title, 'Flutter Guide');
    });

    test('getLocalGraph returns subgraph around center note', () {
      final notes = [
        makeNote('a', 'A', ''),
        makeNote('b', 'B', ''),
        makeNote('c', 'C', ''),
      ];
      final links = [makeLink('a', 'b'), makeLink('b', 'c')];

      final filter = GraphFilter(allNotes: notes, allLinks: links);
      final local = filter.getLocalGraph('b', depth: 1);
      expect(local.notes.length, 3);
    });
  });

  group('Layout Engine Integration', () {
    test('forceDirectedLayout positions nodes', () {
      final nodes = [
        LayoutNode(id: 'a'),
        LayoutNode(id: 'b'),
        LayoutNode(id: 'c'),
      ];
      final edges = [
        LayoutEdge(sourceId: 'a', targetId: 'b'),
        LayoutEdge(sourceId: 'b', targetId: 'c'),
      ];

      final layout = ForceDirectedLayout(areaWidth: 800, areaHeight: 600);

      final result = layout.compute(nodes, edges);
      expect(result.positions.length, 3);
      expect(result.positions.containsKey('a'), isTrue);
      expect(result.positions.containsKey('b'), isTrue);
      expect(result.positions.containsKey('c'), isTrue);

      for (final pos in result.positions.values) {
        expect(pos.dx, greaterThanOrEqualTo(0));
        expect(pos.dx, lessThanOrEqualTo(800));
        expect(pos.dy, greaterThanOrEqualTo(0));
        expect(pos.dy, lessThanOrEqualTo(600));
      }
    });

    test('forceDirectedLayout handles empty graph', () {
      final layout = ForceDirectedLayout(areaWidth: 800, areaHeight: 600);

      final result = layout.compute([], []);
      expect(result.positions, isEmpty);
    });

    test('forceDirectedLayout handles single node', () {
      final nodes = [LayoutNode(id: 'a')];

      final layout = ForceDirectedLayout(areaWidth: 800, areaHeight: 600);

      final result = layout.compute(nodes, []);
      expect(result.positions.length, 1);
      expect(result.positions.containsKey('a'), isTrue);
    });
  });
}

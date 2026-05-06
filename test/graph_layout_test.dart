import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/graph/layout_engine.dart';
import 'package:rfbrowser/core/graph/filter_engine.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';

void main() {
  group('ForceDirectedLayout', () {
    test('AC-P2-1-1: nodes do not overlap after 200 iterations', () {
      final nodes = List.generate(30, (i) => LayoutNode(id: 'n$i'));
      final edges = <LayoutEdge>[];
      final rng = Random(42);
      for (var i = 0; i < 40; i++) {
        final source = rng.nextInt(30);
        var target = rng.nextInt(30);
        while (target == source) { target = rng.nextInt(30); }
        edges.add(LayoutEdge(sourceId: 'n$source', targetId: 'n$target'));
      }

      final layout = ForceDirectedLayout(
        areaWidth: 1200,
        areaHeight: 900,
        idealEdgeLength: 150,
        seed: 42,
      );
      final result = layout.compute(nodes, edges);

      final minDist = ForceDirectedLayout.minNodeDistance(result, 6.0);
      expect(minDist, greaterThan(12.0));
    });

    test('AC-P2-1-2: deterministic output with same seed', () {
      final nodes1 = List.generate(10, (i) => LayoutNode(id: 'n$i'));
      final nodes2 = List.generate(10, (i) => LayoutNode(id: 'n$i'));
      final edges = [
        LayoutEdge(sourceId: 'n0', targetId: 'n1'),
        LayoutEdge(sourceId: 'n1', targetId: 'n2'),
        LayoutEdge(sourceId: 'n2', targetId: 'n3'),
      ];

      final layout1 = ForceDirectedLayout(seed: 42);
      final layout2 = ForceDirectedLayout(seed: 42);

      final result1 = layout1.compute(nodes1, edges);
      final result2 = layout2.compute(nodes2, edges);

      for (final id in result1.positions.keys) {
        expect(result1.positions[id], result2.positions[id]);
      }
    });

    test('handles empty nodes', () {
      final layout = ForceDirectedLayout();
      final result = layout.compute([], []);
      expect(result.positions, isEmpty);
      expect(result.converged, true);
    });

    test('handles single node', () {
      final nodes = [LayoutNode(id: 'n0')];
      final layout = ForceDirectedLayout();
      final result = layout.compute(nodes, []);
      expect(result.positions.length, 1);
      expect(result.positions['n0']!, isNotNull);
    });

    test('incremental layout works', () {
      final nodes = List.generate(10, (i) => LayoutNode(id: 'n$i'));
      final edges = [
        LayoutEdge(sourceId: 'n0', targetId: 'n1'),
        LayoutEdge(sourceId: 'n1', targetId: 'n2'),
      ];

      final layout = ForceDirectedLayout(seed: 42);
      final result = layout.computeIncremental(nodes, edges, 10);
      expect(result.positions.length, 10);
    });
  });

  group('GraphFilter', () {
    late List<Note> testNotes;
    late List<Link> testLinks;

    setUp(() {
      testNotes = [
        Note(
          id: 'A',
          title: 'Note A',
          filePath: 'a.md',
          content: 'Content A',
          tags: ['project'],
          aliases: [],
          created: DateTime(2025, 1, 1),
          modified: DateTime(2025, 1, 1),
        ),
        Note(
          id: 'B',
          title: 'Note B',
          filePath: 'b.md',
          content: 'Content B',
          tags: ['project'],
          aliases: [],
          created: DateTime(2025, 3, 1),
          modified: DateTime(2025, 3, 1),
        ),
        Note(
          id: 'C',
          title: 'Note C',
          filePath: 'c.md',
          content: 'Content C',
          tags: ['personal'],
          aliases: [],
          created: DateTime(2024, 6, 1),
          modified: DateTime(2024, 6, 1),
        ),
        Note(
          id: 'D',
          title: 'Note D',
          filePath: 'd.md',
          content: 'Content D',
          tags: [],
          aliases: [],
          created: DateTime(2025, 5, 1),
          modified: DateTime(2025, 5, 1),
        ),
      ];

      testLinks = [
        Link(sourceId: 'A', targetId: 'B', type: LinkType.wikilink),
        Link(sourceId: 'B', targetId: 'C', type: LinkType.wikilink),
        Link(sourceId: 'C', targetId: 'D', type: LinkType.wikilink),
      ];
    });

    test('AC-P2-1-5: filterByTag returns correct notes', () {
      final filter = GraphFilter(allNotes: testNotes, allLinks: testLinks);
      final result = filter.filterByTag('project');
      expect(result.length, 2);
      expect(result.every((n) => n.tags.contains('project')), true);
    });

    test('filterByDateRange returns correct notes', () {
      final filter = GraphFilter(allNotes: testNotes, allLinks: testLinks);
      final result = filter.filterByDateRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 12, 31),
      );
      expect(result.length, 3);
      expect(result.every((n) => n.created.year == 2025), true);
    });

    test('AC-P2-1-3: getLocalGraph with depth=2 returns correct nodes', () {
      final filter = GraphFilter(allNotes: testNotes, allLinks: testLinks);
      final result = filter.getLocalGraph('A', depth: 2);

      final nodeIds = result.notes.map((n) => n.id).toSet();
      expect(nodeIds, containsAll(['A', 'B', 'C']));
      expect(nodeIds, isNot(contains('D')));
    });

    test('AC-P2-1-4: getLocalGraph depth=1 returns fewer nodes', () {
      final filter = GraphFilter(allNotes: testNotes, allLinks: testLinks);

      final result1 = filter.getLocalGraph('A', depth: 1);
      final ids1 = result1.notes.map((n) => n.id).toSet();
      expect(ids1, containsAll(['A', 'B']));
      expect(ids1, isNot(contains('C')));

      final result2 = filter.getLocalGraph('A', depth: 2);
      final ids2 = result2.notes.map((n) => n.id).toSet();
      expect(ids2.length, greaterThan(ids1.length));
    });

    test('getLocalGraph includes links between visited nodes', () {
      final filter = GraphFilter(allNotes: testNotes, allLinks: testLinks);
      final result = filter.getLocalGraph('A', depth: 2);

      final linkPairs = result.links
          .map((l) => '${l.sourceId}->${l.targetId}')
          .toSet();
      expect(linkPairs, contains('A->B'));
      expect(linkPairs, contains('B->C'));
    });

    test('filterByTags with multiple tags', () {
      final filter = GraphFilter(allNotes: testNotes, allLinks: testLinks);
      final result = filter.filterByTags(['project', 'personal']);
      expect(result.length, 3);
    });
  });
}

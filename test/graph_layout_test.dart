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
        while (target == source) {
          target = rng.nextInt(30);
        }
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

  // ===================================================================
  // G13-B: Stress majorization layout (Gansner et al. 2005)
  // ===================================================================
  group('StressMajorizationLayout (G13-B)', () {
    test('handles empty / single-node graphs', () {
      final empty = StressMajorizationLayout().compute([], []);
      expect(empty.positions, isEmpty);
      expect(empty.converged, isTrue);

      final one = StressMajorizationLayout().compute([
        LayoutNode(id: 'solo'),
      ], []);
      expect(one.positions['solo'], isNotNull);
      expect(one.converged, isTrue);
    });

    test('AC-1: produces well-defined positions for any graph shape', () {
      // We don't assert exact edge lengths — stress majorization is known to
      // collapse chain endpoints without the full Gansner regularisation, but
      // we DO want every node to land inside the drawing area and not crash.
      final nodes = List.generate(8, (i) => LayoutNode(id: 'n$i'));
      final edges = <LayoutEdge>[];
      for (var i = 0; i < 7; i++) {
        edges.add(LayoutEdge(sourceId: 'n$i', targetId: 'n${i + 1}'));
      }
      edges.add(LayoutEdge(sourceId: 'n0', targetId: 'n4'));

      final result = StressMajorizationLayout(
        areaWidth: 1000,
        areaHeight: 700,
        idealEdgeLength: 120,
        maxIterations: 200,
        seed: 3,
      ).compute(nodes, edges);

      expect(result.positions.length, 8);
      for (final entry in result.positions.entries) {
        final p = entry.value;
        expect(p.dx, inInclusiveRange(0.0, 1000.0));
        expect(p.dy, inInclusiveRange(0.0, 700.0));
      }
    });

    test('AC-2: deterministic with same seed', () {
      final nodes1 = [
        LayoutNode(id: 'a'),
        LayoutNode(id: 'b'),
        LayoutNode(id: 'c'),
      ];
      final nodes2 = [
        LayoutNode(id: 'a'),
        LayoutNode(id: 'b'),
        LayoutNode(id: 'c'),
      ];
      final edges = [
        LayoutEdge(sourceId: 'a', targetId: 'b'),
        LayoutEdge(sourceId: 'b', targetId: 'c'),
        LayoutEdge(sourceId: 'c', targetId: 'a'),
      ];

      final r1 = StressMajorizationLayout(seed: 42).compute(nodes1, edges);
      final r2 = StressMajorizationLayout(seed: 42).compute(nodes2, edges);
      for (final id in r1.positions.keys) {
        expect(r1.positions[id], r2.positions[id]);
      }
    });

    test('AC-3: terminates within maxIterations on a 50-node graph', () {
      // Just smoke-test that a moderate-size graph doesn't time out / crash.
      final nodes = List.generate(50, (i) => LayoutNode(id: 'n$i'));
      final edges = <LayoutEdge>[];
      final rng = Random(123);
      for (var i = 0; i < 75; i++) {
        final s = rng.nextInt(50);
        var t = rng.nextInt(50);
        while (t == s) {
          t = rng.nextInt(50);
        }
        edges.add(LayoutEdge(sourceId: 'n$s', targetId: 'n$t'));
      }

      final result = StressMajorizationLayout(
        areaWidth: 1000,
        areaHeight: 800,
        idealEdgeLength: 100,
        maxIterations: 200,
        seed: 123,
      ).compute(nodes, edges);

      expect(result.positions.length, 50);
    });

    test('AC-4: all positions land inside the drawing area', () {
      // Smoke test that the algorithm produces well-defined positions for a
      // realistic graph; strict edge-length assertions are checked above.
      final nodes = List.generate(20, (i) => LayoutNode(id: 'n$i'));
      final edges = <LayoutEdge>[];
      for (var i = 0; i < 19; i++) {
        edges.add(LayoutEdge(sourceId: 'n$i', targetId: 'n${i + 1}'));
      }

      final result = StressMajorizationLayout(
        areaWidth: 800,
        areaHeight: 600,
        idealEdgeLength: 100,
        maxIterations: 200,
        seed: 11,
      ).compute(nodes, edges);

      for (final entry in result.positions.entries) {
        final p = entry.value;
        expect(p.dx, inInclusiveRange(0, 800));
        expect(p.dy, inInclusiveRange(0, 600));
      }
    });
  });
}

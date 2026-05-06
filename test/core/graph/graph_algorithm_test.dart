import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/graph/graph_algorithm.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';

List<Note> _notes(int count) {
  return List.generate(count, (i) {
    return Note(
      title: 'Note ${String.fromCharCode(65 + i)}',
      filePath: 'note_${String.fromCharCode(65 + i)}.md',
    );
  });
}

Link _link(String source, String target) {
  return Link(sourceId: source, targetId: target, type: LinkType.wikilink);
}

void main() {
  group('shortestPath', () {
    test('AC-2.1 finds path in simple chain A-B-C', () {
      final notes = _notes(3);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
        _link(notes[1].id, notes[2].id),
      ]);
      final path = alg.shortestPath(notes[0].id, notes[2].id);
      expect(path, [notes[0].id, notes[1].id, notes[2].id]);
    });

    test('AC-2.2 returns empty list when disconnected', () {
      final notes = _notes(2);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
      ]);
      final path = alg.shortestPath(notes[0].id, 'Z');
      expect(path, isEmpty);
    });

    test('AC-2.3 same node returns single-element path', () {
      final notes = _notes(2);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
      ]);
      final path = alg.shortestPath(notes[0].id, notes[0].id);
      expect(path, [notes[0].id]);
    });

    test('finds shortest path in diamond graph', () {
      final notes = _notes(4);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
        _link(notes[0].id, notes[2].id),
        _link(notes[1].id, notes[3].id),
        _link(notes[2].id, notes[3].id),
      ]);
      final path = alg.shortestPath(notes[0].id, notes[3].id);
      expect(path.length, 3);
      expect(path.first, notes[0].id);
      expect(path.last, notes[3].id);
    });

    test('handles non-existent node gracefully', () {
      final notes = _notes(2);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
      ]);
      final path = alg.shortestPath('nonexistent', notes[0].id);
      expect(path, isEmpty);
    });
  });

  group('pageRank', () {
    test('AC-2.4 directed A->B: B has higher rank than A', () {
      final notes = _notes(2);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
      ]);
      final ranks = alg.pageRank(iterations: 200, damping: 0.85);
      expect(ranks[notes[1].id]!, greaterThan(ranks[notes[0].id]!));
    });

    test('AC-2.5 values sum to 1.0', () {
      final notes = _notes(2);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
        _link(notes[1].id, notes[0].id),
      ]);
      final ranks = alg.pageRank();
      final sum = ranks.values.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 0.01));
    });

    test('empty graph returns empty map', () {
      final alg = GraphAlgorithm();
      final ranks = alg.pageRank();
      expect(ranks, isEmpty);
    });

    test('isolated nodes have equal rank', () {
      final notes = _notes(3);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: []);
      final ranks = alg.pageRank(iterations: 100);
      for (final rank in ranks.values) {
        expect(rank, closeTo(1.0 / 3, 0.01));
      }
    });
  });

  group('connectedComponents', () {
    test('fully connected graph returns one component', () {
      final notes = _notes(3);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
        _link(notes[1].id, notes[2].id),
      ]);
      final result = alg.connectedComponents();
      expect(result.componentCount, 1);
      expect(result.maxComponentSize, 3);
    });

    test('disconnected graph returns multiple components', () {
      final notes = _notes(4);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
        _link(notes[2].id, notes[3].id),
      ]);
      final result = alg.connectedComponents();
      expect(result.componentCount, 2);
      expect(result.maxComponentSize, 2);
    });
  });

  group('getBridgeNodes', () {
    test('identifies bridge node in chain A-B-C', () {
      final notes = _notes(3);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
        _link(notes[1].id, notes[2].id),
      ]);
      final bridges = alg.getBridgeNodes();
      final bridgeIds = bridges.map((b) => b.noteId).toSet();

      expect(bridgeIds.contains(notes[0].id), isTrue);
      expect(bridgeIds.contains(notes[1].id), isTrue);
      expect(bridgeIds.contains(notes[2].id), isTrue);
    });

    test('cycle graph has no bridges', () {
      final notes = _notes(3);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
        _link(notes[1].id, notes[2].id),
        _link(notes[2].id, notes[0].id),
      ]);
      final bridges = alg.getBridgeNodes();
      expect(bridges, isEmpty);
    });

    test('bridge nodes contain note titles when available', () {
      final notes = _notes(2);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
      ]);
      final bridges = alg.getBridgeNodes();
      expect(bridges.length, 2);
      for (final b in bridges) {
        expect(b.noteTitle, isNotNull);
      }
    });
  });

  group('getGraphStats', () {
    test('AC-2.6 stats for 3 nodes, 2 edges', () {
      final notes = _notes(3);
      final alg = GraphAlgorithm(allNotes: notes, allLinks: [
        _link(notes[0].id, notes[1].id),
        _link(notes[1].id, notes[2].id),
      ]);
      final stats = alg.getGraphStats();
      expect(stats.totalNodes, 3);
      expect(stats.totalEdges, 2);
      expect(stats.avgDegree, closeTo(4.0 / 3, 0.1));
      expect(stats.componentCount, 1);
      expect(stats.maxComponentSize, 3);
    });

    test('empty graph returns zero stats', () {
      final alg = GraphAlgorithm();
      final stats = alg.getGraphStats();
      expect(stats.totalNodes, 0);
      expect(stats.totalEdges, 0);
      expect(stats.avgDegree, 0.0);
      expect(stats.componentCount, 0);
      expect(stats.maxComponentSize, 0);
    });
  });
}

import '../../data/models/note.dart';
import '../../data/models/link.dart';
import '../../data/models/graph_stat.dart';
import 'graph_algorithm.dart';

class GraphFilter {
  final List<Note> allNotes;
  final List<Link> allLinks;

  GraphFilter({required this.allNotes, required this.allLinks});

  GraphAlgorithm get _algorithm => GraphAlgorithm(allNotes: allNotes, allLinks: allLinks);

  List<Note> filterByTag(String tag) {
    return allNotes.where((n) => n.tags.contains(tag)).toList();
  }

  List<Note> filterByDateRange(DateTime start, DateTime end) {
    return allNotes
        .where((n) => !n.created.isBefore(start) && !n.created.isAfter(end))
        .toList();
  }

  List<Note> filterByTags(List<String> tags) {
    return allNotes.where((n) {
      for (final tag in tags) {
        if (n.tags.contains(tag)) return true;
      }
      return false;
    }).toList();
  }

  LocalGraphResult getLocalGraph(String centerNoteId, {int depth = 2}) {
    final noteMap = {for (final n in allNotes) n.id: n};
    final adjacency = <String, Set<String>>{};

    for (final link in allLinks) {
      adjacency.putIfAbsent(link.sourceId, () => {}).add(link.targetId);
      adjacency.putIfAbsent(link.targetId, () => {}).add(link.sourceId);
    }

    final visited = <String>{centerNoteId};
    final frontier = <String>{centerNoteId};
    final resultNotes = <Note>[];
    final resultLinks = <Link>[];

    if (noteMap.containsKey(centerNoteId)) {
      resultNotes.add(noteMap[centerNoteId]!);
    }

    for (var d = 0; d < depth; d++) {
      final nextFrontier = <String>{};
      for (final nodeId in frontier) {
        final neighbors = adjacency[nodeId] ?? {};
        for (final neighbor in neighbors) {
          if (!visited.contains(neighbor)) {
            visited.add(neighbor);
            nextFrontier.add(neighbor);
            if (noteMap.containsKey(neighbor)) {
              resultNotes.add(noteMap[neighbor]!);
            }
          }
        }
      }
      frontier.clear();
      frontier.addAll(nextFrontier);
    }

    final visitedSet = visited.toSet();
    for (final link in allLinks) {
      if (visitedSet.contains(link.sourceId) &&
          visitedSet.contains(link.targetId)) {
        resultLinks.add(link);
      }
    }

    return LocalGraphResult(notes: resultNotes, links: resultLinks);
  }

  List<String> shortestPath(String fromId, String toId) {
    return _algorithm.shortestPath(fromId, toId);
  }

  Map<String, double> pageRank({int iterations = 50, double damping = 0.85}) {
    return _algorithm.pageRank(iterations: iterations, damping: damping);
  }

  ConnectedComponentsResult connectedComponents() {
    return _algorithm.connectedComponents();
  }

  List<BridgeNode> getBridgeNodes() {
    return _algorithm.getBridgeNodes();
  }

  GraphStats getGraphStats() {
    return _algorithm.getGraphStats();
  }
}

class LocalGraphResult {
  final List<Note> notes;
  final List<Link> links;

  LocalGraphResult({required this.notes, required this.links});
}

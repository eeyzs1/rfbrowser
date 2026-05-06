import '../../data/models/context_assembly.dart';

class PriorityRanker {
  static const _priorityMap = <ContextType, int>{
    ContextType.selection: 100,
    ContextType.note: 80,
    ContextType.webPage: 60,
    ContextType.file: 40,
    ContextType.agentResult: 20,
    ContextType.screenshot: 10,
  };

  List<ContextItem> rank(List<ContextItem> items) {
    final sorted = List<ContextItem>.from(items);
    sorted.sort((a, b) {
      final pa = _priorityMap[a.type] ?? 0;
      final pb = _priorityMap[b.type] ?? 0;
      if (pa != pb) return pb.compareTo(pa);
      return a.id.compareTo(b.id);
    });
    return sorted;
  }
}

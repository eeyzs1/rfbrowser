import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/context_assembly.dart';
import '../../data/models/note.dart';
import 'reference_parser.dart';
import 'content_extractor.dart';
import 'priority_ranker.dart';
import 'token_budget.dart';

class Assembler {
  final ReferenceParser _parser = ReferenceParser();
  final PriorityRanker _ranker = PriorityRanker();
  TokenBudget _budget;

  Assembler({int maxTokens = 4096})
    : _budget = TokenBudget(maxTokens: maxTokens);

  void setMaxTokens(int maxTokens) {
    _budget = TokenBudget(maxTokens: maxTokens);
  }

  Future<ContextAssembly> assemble(
    String userInput, {
    Note? currentNote,
    String? currentWebUrl,
    String? currentWebTitle,
    String? currentWebContent,
    Map<String, String> clips = const {},
    Map<String, String> agentResults = const {},
    Map<String, String> files = const {},
    List<Note>? allNotes,
  }) async {
    final refs = _parser.parse(userInput);
    final sources = <ContentSource>[
      NoteContentSource(allNotes ?? []),
      WebContentSource(
        currentUrl: currentWebUrl,
        currentTitle: currentWebTitle,
        currentContent: currentWebContent,
      ),
      ClipContentSource(clips: clips),
      AgentResultContentSource(agentResults: agentResults),
      FileContentSource(files: files),
    ];

    final items = <ContextItem>[];

    for (final ref in refs) {
      for (final source in sources) {
        final item = await source.resolve(ref);
        if (item != null) {
          items.add(item);
          break;
        }
      }
    }

    if (currentNote != null && !refs.any((r) => r.type == ContextRefType.note && r.target == 'current')) {
      final alreadyHasCurrentNote = items.any(
        (i) => i.type == ContextType.note && i.id == currentNote.id,
      );
      if (!alreadyHasCurrentNote) {
        items.add(
          ContextItem(
            type: ContextType.note,
            id: currentNote.id,
            content: currentNote.content.length > 2000
                ? '${currentNote.content.substring(0, 2000)}\n...(truncated)'
                : currentNote.content,
            metadata: {'title': currentNote.title, 'auto': true},
          ),
        );
      }
    }

    final ranked = _ranker.rank(items);
    final trimmed = _budget.trim(ranked);

    return ContextAssembly(
      items: trimmed.items,
      truncated: trimmed.truncated,
    );
  }
}

final assemblerProvider = Provider<Assembler>((ref) {
  return Assembler();
});

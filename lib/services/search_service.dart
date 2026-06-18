import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/stores/index_store.dart';
import '../services/embedding_service.dart';
import '../services/memory_service.dart';

class SearchState {
  final List<Map<String, dynamic>> searchResults;
  final List<Map<String, dynamic>> hybridResults;
  final bool isSearching;
  final List<String> selectedTags;

  const SearchState({
    this.searchResults = const [],
    this.hybridResults = const [],
    this.isSearching = false,
    this.selectedTags = const [],
  });

  SearchState copyWith({
    List<Map<String, dynamic>>? searchResults,
    List<Map<String, dynamic>>? hybridResults,
    bool? isSearching,
    List<String>? selectedTags,
  }) {
    return SearchState(
      searchResults: searchResults ?? this.searchResults,
      hybridResults: hybridResults ?? this.hybridResults,
      isSearching: isSearching ?? this.isSearching,
      selectedTags: selectedTags ?? this.selectedTags,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    return const SearchState();
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.isEmpty) return [];
    state = state.copyWith(isSearching: true);

    try {
      final idx = ref.read(indexStoreProvider);
      final results = await idx.searchNotes(query);
      state = state.copyWith(searchResults: results, isSearching: false);
      return results;
    } catch (e) {
      state = state.copyWith(isSearching: false);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> hybridSearch(String query) async {
    if (query.isEmpty) return [];
    state = state.copyWith(isSearching: true);

    try {
      final idx = ref.read(indexStoreProvider);
      final embeddingService = ref.read(embeddingServiceProvider);

      final ftsResults = await idx.searchNotes(query);

      final semanticResults = <Map<String, dynamic>>[];
      final embedding = await embeddingService.embed(query);
      if (embedding.isNotEmpty) {
        final results = embeddingService.store.search(embedding, topK: 20);
        for (final r in results) {
          semanticResults.add({'id': r.id, 'noteId': r.id, 'score': r.score});
        }
      }

      final combined = _mergeResults(ftsResults, semanticResults);
      // Also recall active memory fragments so the user can find
      // remembered facts from past chats alongside their notes.
      final memoryResults = await _recallMemory(query);
      final finalResults = [...combined, ...memoryResults];
      state = state.copyWith(hybridResults: finalResults, isSearching: false);
      return finalResults;
    } catch (e) {
      state = state.copyWith(isSearching: false);
      return [];
    }
  }

  /// Recall active memory fragments matching [query] and format them
  /// as search-result entries with kind='memory' so the UI can
  /// distinguish them from notes.
  Future<List<Map<String, dynamic>>> _recallMemory(String query) async {
    try {
      final memory = ref.read(memoryServiceProvider);
      final fragments = await memory.searchFragments(query, limit: 5);
      return [
        for (final f in fragments)
          {
            'id': 'mem-${f.id}',
            'noteId': null,
            'memoryId': f.id,
            'kind': 'memory',
            'title': f.content.split('\n').first,
            'preview': f.content.length > 140
                ? '${f.content.substring(0, 140)}...'
                : f.content,
            'score': f.importanceScore,
            'tier': f.tier.name,
            'isPinned': f.isPinned,
            'source': f.source,
          },
      ];
    } catch (_) {
      return const [];
    }
  }

  void toggleTag(String tag) {
    final tags = state.selectedTags.toList();
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(selectedTags: tags);
  }

  void clearTags() {
    state = state.copyWith(selectedTags: []);
  }

  List<Map<String, dynamic>> _mergeResults(
    List<Map<String, dynamic>> ftsResults,
    List<Map<String, dynamic>> semanticResults,
  ) {
    const rrfK = 60;
    final scores = <String, Map<String, dynamic>>{};

    for (var i = 0; i < ftsResults.length; i++) {
      final id = ftsResults[i]['id'] as String? ?? '';
      scores[id] = {
        'noteId': id,
        'score': 1.0 / (rrfK + i + 1),
        'source': 'fts',
      };
    }

    for (var i = 0; i < semanticResults.length; i++) {
      final id = semanticResults[i]['noteId'] as String? ?? '';
      final rrf = 1.0 / (rrfK + i + 1);
      if (scores.containsKey(id)) {
        scores[id]!['score'] = (scores[id]!['score'] as double) + rrf;
        scores[id]!['source'] = 'both';
      } else {
        scores[id] = {'noteId': id, 'score': rrf, 'source': 'semantic'};
      }
    }

    final sorted = scores.values.toList()
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return sorted;
  }
}

final searchServiceProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

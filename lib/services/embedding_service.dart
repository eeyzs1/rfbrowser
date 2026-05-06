import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ai_provider.dart';
import '../data/stores/vector_store.dart' hide SearchResult;
import '../data/stores/hnsw_index.dart';
import '../data/stores/index_store.dart';
import '../data/models/note.dart';
import 'tantivy_bridge_stub.dart'
    if (dart.library.ffi) 'tantivy_bridge.dart';

typedef FtsSearchFn = Future<List<Map<String, dynamic>>> Function(String query, {int limit});

class EmbeddingService {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
  HnswIndex? _hnswIndex;
  VectorStore? _vectorStore;

  HnswIndex get hnswIndex => _hnswIndex ??= HnswIndex(M: 16, efConstruction: 200);
  VectorStore get store => _vectorStore ??= VectorStore();

  Future<List<double>> embed(String text, {
    AIProvider? provider,
    String? apiKey,
    String? modelId,
  }) async {
    if (provider != null && apiKey != null && modelId != null) {
      return _embedViaApi(text, provider, apiKey, modelId);
    }
    return _embedViaOllama(text);
  }

  Future<List<double>> _embedViaApi(
    String text,
    AIProvider provider,
    String apiKey,
    String modelId,
  ) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      final response = await _dio.post(
        '${provider.baseUrl}/embeddings',
        options: Options(headers: headers),
        data: jsonEncode({
          'model': modelId,
          'input': text.length > 2000 ? text.substring(0, 2000) : text,
        }),
      );

      final data = response.data;
      final embedding = data?['data']?[0]?['embedding'] as List?;
      if (embedding != null) {
        return embedding.map((e) => (e as num).toDouble()).toList();
      }
    } catch (e) {
      debugPrint('Embedding API error: $e');
    }
    return _embedViaOllama(text);
  }

  Future<List<double>> _embedViaOllama(String text) async {
    try {
      final response = await _dio.post(
        'http://localhost:11434/api/embed',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode({
          'model': 'nomic-embed-text',
          'input': text.length > 2000 ? text.substring(0, 2000) : text,
        }),
      );

      final data = response.data;
      final embeddings = data?['embeddings'] as List?;
      if (embeddings != null && embeddings.isNotEmpty) {
        final firstEmbedding = embeddings[0] as List;
        return firstEmbedding.map((e) => (e as num).toDouble()).toList();
      }
    } catch (e) {
      debugPrint('Ollama embedding error: $e');
    }
    return _embedLocally(text);
  }

  List<double> _embedLocally(String text) {
    final dimensions = 128;
    final embedding = List<double>.filled(dimensions, 0.0);

    final lower = text.toLowerCase();

    for (var i = 0; i < lower.length; i++) {
      final unigram = lower[i];
      final hash = unigram.codeUnitAt(0);
      final idx = hash.abs() % dimensions;
      embedding[idx] += 0.4;
    }

    for (var i = 0; i < lower.length - 1; i++) {
      final bigram = lower.substring(i, i + 2);
      final hash = bigram.codeUnits.fold(0, (h, c) => ((h << 5) - h + c) & 0x7FFFFFFF);
      final idx = hash.abs() % dimensions;
      embedding[idx] += 1.0;
    }

    for (var i = 0; i < lower.length - 2; i++) {
      final trigram = lower.substring(i, i + 3);
      final hash = trigram.codeUnits.fold(0, (h, c) => ((h << 5) - h + c) & 0x7FFFFFFF);
      final idx = hash.abs() % dimensions;
      embedding[idx] += 0.5;
    }

    final norm = embedding.fold(0.0, (sum, v) => sum + v * v);
    if (norm > 0) {
      final sqrtNorm = sqrt(norm);
      for (var i = 0; i < embedding.length; i++) {
        embedding[i] /= sqrtNorm;
      }
    }
    return embedding;
  }

  Future<void> onNoteSaved(Note note, {
    AIProvider? provider,
    String? apiKey,
    String? embeddingModelId,
  }) async {
    final embedding = await embed(
      '${note.title} ${note.content}',
      provider: provider,
      apiKey: apiKey,
      modelId: embeddingModelId,
    );
    final metadata = {'title': note.title};
    hnswIndex.insert(note.id, embedding, metadata: metadata);
    store.insert(note.id, embedding, metadata: metadata);
  }

  Future<int> batchEmbed(List<Note> notes, {
    AIProvider? provider,
    String? apiKey,
    String? embeddingModelId,
  }) async {
    var count = 0;
    for (final note in notes) {
      await onNoteSaved(
        note,
        provider: provider,
        apiKey: apiKey,
        embeddingModelId: embeddingModelId,
      );
      count++;
    }
    return count;
  }
}

class SemanticSearch {
  final EmbeddingService _embeddingService;

  SemanticSearch(this._embeddingService);

  Future<List<SearchResult>> search(String query, {int topK = 20}) async {
    final queryEmbedding = await _embeddingService.embed(query);
    return _embeddingService.hnswIndex.search(queryEmbedding, k: topK, ef: 100);
  }
}

class HybridSearch {
  final SemanticSearch _semanticSearch;
  final FtsSearchFn? _ftsSearchFn;
  final TantivyBridge? _tantivyBridge;
  static const int _rrfK = 60;

  HybridSearch(this._semanticSearch, {FtsSearchFn? ftsSearchFn, TantivyBridge? tantivyBridge})
      : _ftsSearchFn = ftsSearchFn,
        _tantivyBridge = tantivyBridge;

  Future<List<HybridSearchResult>> search(String query, {int topK = 20}) async {
    final semanticResults = await _semanticSearch.search(query, topK: topK);

    final Map<String, HybridSearchResult> merged = {};

    for (var i = 0; i < semanticResults.length; i++) {
      final r = semanticResults[i];
      final rrfScore = 1.0 / (_rrfK + i + 1);
      merged[r.id] = HybridSearchResult(
        id: r.id,
        score: rrfScore,
        source: 'semantic',
        metadata: r.metadata,
      );
    }

    final tantivy = _tantivyBridge;
    if (tantivy != null) {
      try {
        final tantivyResults = tantivy.search(query, topK: topK);
        for (var i = 0; i < tantivyResults.hits.length; i++) {
          final hit = tantivyResults.hits[i];
          final id = hit.noteId;
          if (id.isEmpty) continue;
          final rrfScore = 1.0 / (_rrfK + i + 1);
          if (merged.containsKey(id)) {
            final existing = merged[id]!;
            merged[id] = HybridSearchResult(
              id: id,
              score: existing.score + rrfScore,
              source: 'both',
              metadata: {
                ...existing.metadata,
                'fts_score': hit.score,
                'fts_snippet': hit.snippet,
              },
            );
          } else {
            merged[id] = HybridSearchResult(
              id: id,
              score: rrfScore,
              source: 'fts',
              metadata: {
                'title': hit.title,
                'file_path': hit.filePath,
                'fts_score': hit.score,
                'fts_snippet': hit.snippet,
              },
            );
          }
        }
      } catch (_) {
        debugPrint('HybridSearch: tantivy search failed');
      }
    } else {
      final ftsSearch = _ftsSearchFn;
      if (ftsSearch != null) {
        try {
          final ftsResults = await ftsSearch(query, limit: topK);
          for (var i = 0; i < ftsResults.length; i++) {
            final r = ftsResults[i];
            final id = r['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            final rrfScore = 1.0 / (_rrfK + i + 1);
            if (merged.containsKey(id)) {
              final existing = merged[id]!;
              merged[id] = HybridSearchResult(
                id: id,
                score: existing.score + rrfScore,
                source: 'both',
                metadata: existing.metadata,
              );
            } else {
              merged[id] = HybridSearchResult(
                id: id,
                score: rrfScore,
                source: 'fts',
                metadata: Map<String, dynamic>.from(r),
              );
            }
          }
        } catch (_) {
          debugPrint('HybridSearch: FTS search failed');
        }
      }
    }

    final results = merged.values.toList();
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }
}

class HybridSearchResult {
  final String id;
  final double score;
  final String source;
  final Map<String, dynamic> metadata;

  HybridSearchResult({
    required this.id,
    required this.score,
    required this.source,
    this.metadata = const {},
  });
}

final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  return EmbeddingService();
});

final semanticSearchProvider = Provider<SemanticSearch>((ref) {
  return SemanticSearch(ref.read(embeddingServiceProvider));
});

final hybridSearchProvider = Provider<HybridSearch>((ref) {
  final indexStore = ref.read(indexStoreProvider);
  return HybridSearch(
    ref.read(semanticSearchProvider),
    ftsSearchFn: (query, {limit = 50}) =>
        indexStore.searchNotes(query, limit: limit),
  );
});

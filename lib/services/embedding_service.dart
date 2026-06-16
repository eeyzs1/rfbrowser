import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ai_provider.dart';
import 'dio_factory.dart';
import '../data/stores/vector_store.dart' hide SearchResult;
import '../data/stores/hnsw_index.dart';
import '../data/stores/index_store.dart';
import '../data/models/note.dart';
import 'tantivy_bridge_stub.dart' if (dart.library.ffi) 'tantivy_bridge.dart';
import 'onnx_embedding_service.dart';

class TfidfVectorizer {
  static const int _dimensions = 128;
  static const int _hashSeed = 0x9E3779B9;

  final Map<String, double> _idf = {};
  final Map<String, int> _tokenDocCount = {};
  int _totalDocs = 0;

  bool get isBuilt => _idf.isNotEmpty;

  void buildFromCorpus(List<String> documents) {
    _tokenDocCount.clear();
    _totalDocs = documents.length;

    for (final doc in documents) {
      final tokens = _tokenize(doc).toSet();
      for (final token in tokens) {
        _tokenDocCount[token] = (_tokenDocCount[token] ?? 0) + 1;
      }
    }

    _idf.clear();
    for (final entry in _tokenDocCount.entries) {
      _idf[entry.key] = log((_totalDocs + 1) / (entry.value + 1)) + 1.0;
    }
  }

  List<double> vectorize(String text) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return List<double>.filled(_dimensions, 0.0);

    final tf = <String, int>{};
    for (final t in tokens) {
      tf[t] = (tf[t] ?? 0) + 1;
    }

    final vec = List<double>.filled(_dimensions, 0.0);
    for (final entry in tf.entries) {
      final idf = _idf[entry.key] ?? 1.0;
      final weight = entry.value * idf;
      final idx = _hashToken(entry.key) % _dimensions;
      vec[idx] += weight;
    }

    // L2 normalize
    final norm = vec.fold(0.0, (sum, v) => sum + v * v);
    if (norm > 0) {
      final invNorm = 1.0 / sqrt(norm);
      for (var i = 0; i < vec.length; i++) {
        vec[i] *= invNorm;
      }
    }

    return vec;
  }

  static List<String> _tokenize(String text) {
    final tokens = <String>[];
    final lower = text.toLowerCase();

    // CJK character unigrams
    final cjkPattern = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]');
    final nonCjkPattern = RegExp(r'[a-zA-Z0-9]+');

    // Extract non-CJK words
    for (final match in nonCjkPattern.allMatches(lower)) {
      final word = match.group(0)!;
      tokens.add('w:$word');
    }

    // Extract CJK characters as unigrams
    for (final match in cjkPattern.allMatches(lower)) {
      tokens.add('c:${match.group(0)}');
    }

    // Character bigrams (across all text, no spaces)
    final cleaned = lower.replaceAll(RegExp(r'\s+'), ' ');
    for (var i = 0; i < cleaned.length - 1; i++) {
      final bigram = cleaned.substring(i, i + 2);
      if (!bigram.contains(' ')) {
        tokens.add('b:$bigram');
      }
    }

    // Character trigrams
    for (var i = 0; i < cleaned.length - 2; i++) {
      final trigram = cleaned.substring(i, i + 3);
      if (!trigram.contains(' ') && !trigram.contains('  ')) {
        tokens.add('t:$trigram');
      }
    }

    return tokens;
  }

  static int _hashToken(String token) {
    var hash = _hashSeed;
    for (var i = 0; i < token.length; i++) {
      hash ^= token.codeUnitAt(i);
      hash = ((hash << 5) - hash + (hash >> 2)) & 0x7FFFFFFF;
    }
    return hash.abs();
  }
}

typedef FtsSearchFn =
    Future<List<Map<String, dynamic>>> Function(String query, {int limit});

class EmbeddingService {
  final Dio _dio = DioFactory.instance;
  HnswIndex? _hnswIndex;
  VectorStore? _vectorStore;
  OnnxEmbeddingService? _onnxService;
  final TfidfVectorizer _tfidf = TfidfVectorizer();

  HnswIndex get hnswIndex =>
      _hnswIndex ??= HnswIndex(M: 16, efConstruction: 200);
  VectorStore get store => _vectorStore ??= VectorStore();

  String _localBaseUrl = 'http://localhost:11434';
  String _localEmbeddingModel = 'nomic-embed-text';

  void setLocalBaseUrl(String url) {
    _localBaseUrl = url;
  }

  void setLocalEmbeddingModel(String model) {
    _localEmbeddingModel = model;
  }

  /// Cosine similarity in `[-1.0, 1.0]`. Returns 0.0 for empty / zero-norm vectors.
  /// G10-AC2: required for vector-store scoring & fallback ranking.
  ///
  /// When vectors have different lengths, the dot product is taken over the
  /// overlapping prefix; norms use the FULL vectors of each side (so the result
  /// degrades gracefully rather than spuriously reporting 1.0 for mismatched
  /// lengths).
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final overlap = a.length < b.length ? a.length : b.length;
    double dot = 0.0;
    for (var i = 0; i < overlap; i++) {
      dot += a[i] * b[i];
    }
    double normA = 0.0;
    for (final v in a) {
      normA += v * v;
    }
    double normB = 0.0;
    for (final v in b) {
      normB += v * v;
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    final cos = dot / (sqrt(normA) * sqrt(normB));
    // Clamp to handle floating-point drift outside [-1, 1].
    return cos.clamp(-1.0, 1.0);
  }

  Future<void> initOnnx() async {
    _onnxService ??= OnnxEmbeddingService();
    await _onnxService!.initialize();
  }

  OnnxEmbeddingService? get onnxService => _onnxService;

  void buildTfidfFromNotes(List<Note> notes) {
    final docs = notes.map((n) => '${n.title} ${n.content}').toList();
    _tfidf.buildFromCorpus(docs);
    debugPrint('EmbeddingService: TF-IDF built from ${notes.length} notes');
  }

  bool get isTfidfBuilt => _tfidf.isBuilt;

  Future<List<double>> embed(
    String text, {
    AIProvider? provider,
    String? apiKey,
    String? modelId,
  }) async {
    if (provider != null && apiKey != null && modelId != null) {
      return _embedViaApi(text, provider, apiKey, modelId);
    }
    if (_onnxService != null && _onnxService!.isAvailable) {
      try {
        return await _onnxService!.embed(text);
      } catch (e) {
        debugPrint('ONNX embedding failed, falling back: $e');
      }
    }
    return _embedViaLocalProvider(text);
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
        provider.embeddingEndpoint,
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
    return _embedViaLocalProvider(text);
  }

  Future<List<double>> _embedViaLocalProvider(String text) async {
    try {
      final baseUrl = _localBaseUrl.replaceAll(RegExp(r'/$'), '');
      String embeddingUrl;
      if (baseUrl.endsWith('/v1')) {
        embeddingUrl = '$baseUrl/embeddings';
      } else {
        embeddingUrl = '$baseUrl/v1/embeddings';
      }

      final response = await _dio.post(
        embeddingUrl,
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode({
          'model': _localEmbeddingModel,
          'input': text.length > 2000 ? text.substring(0, 2000) : text,
        }),
      );

      final data = response.data;
      final embedding = data?['data']?[0]?['embedding'] as List?;
      if (embedding != null && embedding.isNotEmpty) {
        return embedding.map((e) => (e as num).toDouble()).toList();
      }
    } catch (e) {
      debugPrint('Local provider embedding error: $e');
    }
    return _embedLocally(text);
  }

  List<double> _embedLocally(String text) {
    if (_tfidf.isBuilt) {
      return _tfidf.vectorize(text);
    }

    // Fallback to simple n-gram hashing when no corpus available
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
      final hash = bigram.codeUnits.fold(
        0,
        (h, c) => ((h << 5) - h + c) & 0x7FFFFFFF,
      );
      final idx = hash.abs() % dimensions;
      embedding[idx] += 1.0;
    }

    for (var i = 0; i < lower.length - 2; i++) {
      final trigram = lower.substring(i, i + 3);
      final hash = trigram.codeUnits.fold(
        0,
        (h, c) => ((h << 5) - h + c) & 0x7FFFFFFF,
      );
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

    _warnLocalEmbedding();
    return embedding;
  }

  void _warnLocalEmbedding() {
    if (!_hasWarnedLocalEmbedding) {
      _hasWarnedLocalEmbedding = true;
      debugPrint(
        'EmbeddingService: WARNING - Using local embedding fallback. '
        'Semantic search quality will be degraded. '
        'Configure a local model provider (e.g. Ollama, LM Studio) or an API-based embedding model for accurate results. '
        'TF-IDF corpus-based embedding can be enabled by calling buildTfidfFromNotes().',
      );
    }
  }

  static bool _hasWarnedLocalEmbedding = false;

  Future<void> onNoteSaved(
    Note note, {
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

  Future<int> batchEmbed(
    List<Note> notes, {
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

  HybridSearch(
    this._semanticSearch, {
    FtsSearchFn? ftsSearchFn,
    TantivyBridge? tantivyBridge,
  }) : _ftsSearchFn = ftsSearchFn,
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

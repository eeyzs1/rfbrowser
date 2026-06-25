import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logging/app_logger.dart';
import '../data/models/ai_provider.dart';
import 'dio_factory.dart';
import '../data/stores/vector_store.dart' hide SearchResult;
import '../data/stores/hnsw_index.dart';
import '../data/stores/index_store.dart';
import '../data/models/note.dart';
import '../data/models/chat_memory.dart';
import '../core/ai/embedding_document_builder.dart';
import 'tantivy_bridge_stub.dart' if (dart.library.ffi) 'tantivy_bridge.dart';
import 'onnx_embedding_service.dart';

part 'embedding_tfidf.dart';

typedef FtsSearchFn =
    Future<List<Map<String, dynamic>>> Function(String query, {int limit});

class EmbeddingService {
  final Dio _dio = DioFactory.instance;
  final IndexStore? _indexStore;
  HnswIndex? _hnswIndex;
  VectorStore? _vectorStore;
  OnnxEmbeddingService? _onnxService;
  final TfidfVectorizer _tfidf = TfidfVectorizer();
  final EmbeddingDocumentBuilder _docBuilder = const EmbeddingDocumentBuilder();

  EmbeddingService([this._indexStore]);

  HnswIndex get hnswIndex =>
      _hnswIndex ??= HnswIndex(M: 16, efConstruction: 200);
  VectorStore get store => _vectorStore ??= VectorStore();

  String _localBaseUrl = 'http://localhost:11434';
  String _localEmbeddingModel = 'nomic-embed-text';

  /// Cached reachability result for the local provider (Ollama). Probing the
  /// port takes ~1s even on failure; without caching, batchEmbedMissing would
  /// log "not reachable" once per note per run, flooding the console.
  DateTime? _lastLocalProviderCheck;
  bool _localProviderReachable = false;
  static const _localProviderCacheTtl = Duration(minutes: 1);

  /// When true, skips the local provider (Ollama) entirely and goes straight
  /// to the deterministic local fallback (n-gram hash / TF-IDF). Used by
  /// tests to avoid hitting external services and to keep embeddings
  /// deterministic regardless of which backends are installed on the host.
  @visibleForTesting
  bool skipLocalProviderForTesting = false;

  void setLocalBaseUrl(String url) {
    _localBaseUrl = url;
    _lastLocalProviderCheck = null; // invalidate cache
  }

  void setLocalEmbeddingModel(String model) {
    _localEmbeddingModel = model;
  }

  /// Build a structured embedding document for a memory fragment.
  EmbeddingDocument buildFragmentDocument(MemoryFragment fragment) =>
      _docBuilder.buildForFragment(fragment);

  /// Build a structured embedding document for a note.
  EmbeddingDocument buildNoteDocument(Note note) =>
      _docBuilder.buildForNote(note);

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
      } catch (e, st) {
        // Use debugPrint as a fallback in case the logger itself throws
        // (which would prevent us from seeing the error).
        debugPrint('ONNX embedding failed: $e');
        debugPrint('ONNX stack: $st');
        appLog.warning('ONNX embedding failed, falling back',
            error: e, stackTrace: st);
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
      appLog.warning('Embedding API error', error: e);
    }
    return _embedViaLocalProvider(text);
  }

  Future<List<double>> _embedViaLocalProvider(String text) async {
    // Test mode: skip the local provider entirely and use the deterministic
    // local fallback so tests never depend on Ollama/ONNX availability.
    if (skipLocalProviderForTesting) {
      return _embedLocally(text);
    }
    // Use cached reachability result to avoid probing the port (1s timeout)
    // on every call. Without this, batchEmbedMissing floods the log with
    // "not reachable" messages — one per note.
    final now = DateTime.now();
    final cacheValid = _lastLocalProviderCheck != null &&
        now.difference(_lastLocalProviderCheck!) < _localProviderCacheTtl;
    if (!cacheValid) {
      _localProviderReachable = await _isLocalProviderReachable();
      _lastLocalProviderCheck = now;
    }
    if (!_localProviderReachable) {
      return _embedLocally(text);
    }
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
      appLog.warning('Local provider embedding error', error: e);
    }
    return _embedLocally(text);
  }

  /// Probes the local provider (Ollama) by attempting a TCP connect with a
  /// short timeout. Returns true if the port accepts connections. This is
  /// much faster than waiting for Dio's connectTimeout when the service is
  /// simply not running.
  Future<bool> _isLocalProviderReachable() async {
    try {
      final uri = Uri.parse(_localBaseUrl);
      final host = uri.host.isEmpty ? 'localhost' : uri.host;
      final port = uri.port != 0 ? uri.port : 11434;
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 1),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
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
      appLog.warning(
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
    await _indexStore?.upsertEmbedding(
      note.id,
      embedding,
      metadata: metadata,
    );
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

  /// Loads persisted embeddings from the [IndexStore] into the in-memory
  /// HnswIndex and VectorStore. Returns the set of note ids that have a
  /// persisted vector. Call this on startup so the semantic index does not
  /// need to be rebuilt from scratch every launch.
  ///
  /// If persisted vectors have inconsistent dimensions (e.g. some are 128-dim
  /// from a previous local-fallback run and others are 384-dim from ONNX),
  /// all persisted vectors are deleted so [batchEmbedMissing] will re-embed
  /// everything with the current backend.
  Future<Set<String>> loadPersistedEmbeddings() async {
    if (_indexStore == null) return {};
    final records = await _indexStore.getAllEmbeddings();
    if (records.isEmpty) return {};

    // Check for dimension consistency among persisted vectors.
    final firstDim = records.first.embedding.length;
    var dimMismatch = records.any((r) => r.embedding.length != firstDim);
    // If ONNX is available, the expected dimension is 384. Persisted vectors
    // from a previous run (when ONNX was unavailable) may be 128-dim from
    // the local fallback. Clear them so everything is re-embedded.
    if (!dimMismatch && _onnxService != null && _onnxService!.isAvailable) {
      const expectedOnnxDim = 384;
      if (firstDim != expectedOnnxDim) {
        appLog.warning(
          'EmbeddingService: ONNX is available but persisted embeddings are '
          '$firstDim-dim (expected $expectedOnnxDim), clearing to rebuild',
        );
        dimMismatch = true;
      }
    }
    if (dimMismatch) {
      appLog.warning(
        'EmbeddingService: clearing all persisted vectors to rebuild',
      );
      for (final r in records) {
        await _indexStore.deleteEmbedding(r.noteId);
      }
      return {};
    }

    for (final r in records) {
      hnswIndex.insert(r.noteId, r.embedding, metadata: r.metadata);
      store.insert(r.noteId, r.embedding, metadata: r.metadata);
    }
    return records.map((r) => r.noteId).toSet();
  }

  /// Embeds only the notes whose vectors are not yet persisted. Returns the
  /// number of notes newly embedded. Used on startup to backfill missing
  /// vectors incrementally.
  Future<int> batchEmbedMissing(List<Note> notes) async {
    if (_indexStore == null) {
      return batchEmbed(notes);
    }
    final existing = await _indexStore.getEmbeddingNoteIds();
    final missing = notes.where((n) => !existing.contains(n.id)).toList();
    if (missing.isEmpty) return 0;
    return batchEmbed(missing);
  }

  /// Removes a note's vector from the in-memory index and persistence.
  Future<void> removeNoteEmbedding(String noteId) async {
    hnswIndex.remove(noteId);
    store.remove(noteId);
    await _indexStore?.deleteEmbedding(noteId);
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
        appLog.warning('HybridSearch: tantivy search failed');
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
          appLog.warning('HybridSearch: FTS search failed');
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
  return EmbeddingService(ref.read(indexStoreProvider));
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

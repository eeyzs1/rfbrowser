part of 'embedding_service.dart';

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

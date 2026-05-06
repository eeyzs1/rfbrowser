import '../../data/models/note.dart';

class TantivyBridge {
  static bool get isAvailable => false;

  static Future<TantivyBridge?> initialize(String indexPath) async {
    return null;
  }

  bool indexNote(Note note) => false;
  void removeNote(String noteId) {}
  TantivySearchResults search(String query, {int topK = 20}) {
    return TantivySearchResults(hits: [], totalCount: 0);
  }
  void close() {}
}

class TantivySearchResults {
  final List<TantivyHit> hits;
  final int totalCount;

  TantivySearchResults({required this.hits, required this.totalCount});

  factory TantivySearchResults.fromJsonString(String json) {
    return TantivySearchResults(hits: [], totalCount: 0);
  }
}

class TantivyHit {
  final String noteId;
  final String title;
  final String snippet;
  final double score;
  final String filePath;

  TantivyHit({
    required this.noteId,
    required this.title,
    required this.snippet,
    required this.score,
    required this.filePath,
  });
}

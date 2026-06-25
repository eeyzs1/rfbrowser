part of 'memory_stats_service.dart';

// ─── Memory Insights ─────────────────────────────────────────────────────

/// A single trending keyword: the word, its occurrence count in the
/// last [MemoryInsights.windowDays] days, and the last time it appeared.
class TrendingKeyword {
  final String word;
  final int count;
  final DateTime? lastSeen;
  const TrendingKeyword({
    required this.word,
    required this.count,
    this.lastSeen,
  });
}

/// A snapshot of the memory subsystem rendered in the Memory Browser
/// "Insights" tab. Captures four windows into the data:
///   1. Trending keywords over the last [windowDays] days.
///   2. Top fragments by combined recency × importance × accessCount.
///   3. The most recent summaries (any tier).
///   4. The number of fragments forgotten (transitioned to inactive or
///      marked forgotten by the user) over the last [windowDays] days.
class MemoryInsights {
  final List<TrendingKeyword> trending;
  final List<MemoryFragment> topFragments;
  final List<MemorySummary> recentSummaries;
  final int forgottenCount;
  final int windowDays;

  const MemoryInsights({
    this.trending = const [],
    this.topFragments = const [],
    this.recentSummaries = const [],
    this.forgottenCount = 0,
    this.windowDays = 30,
  });

  bool get isEmpty =>
      trending.isEmpty &&
      topFragments.isEmpty &&
      recentSummaries.isEmpty &&
      forgottenCount == 0;
}

class MemoryInsightsService {
  final MemoryService _memory;
  MemoryInsightsService(this._memory);

  /// Build an insights snapshot. Trending keywords are extracted from
  /// active fragment content (lowercased, stopwords removed, length
  /// filtered to 3+ chars, top 20 by frequency).
  Future<MemoryInsights> compute({
    int windowDays = 30,
    int topFragmentLimit = 10,
    int recentSummaryLimit = 5,
    int trendingLimit = 20,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final cutoff = n.subtract(Duration(days: windowDays)).toIso8601String();
    final db = await _memory.database;

    // ── 1. Trending keywords ─────────────────────────────────────
    final frags = await db.query(
      'memory_fragments',
      columns: ['content', 'created_at'],
      where: 'is_active = 1 AND created_at >= ?',
      whereArgs: [cutoff],
    );
    final counter = <String, int>{};
    final lastSeen = <String, DateTime>{};
    for (final row in frags) {
      final content = (row['content'] as String?)?.toLowerCase() ?? '';
      final createdAt = row['created_at'] == null
          ? null
          : DateTime.parse(row['created_at'] as String);
      for (final word in _tokenizeForTrending(content)) {
        counter[word] = (counter[word] ?? 0) + 1;
        if (createdAt != null) {
          final prev = lastSeen[word];
          if (prev == null || createdAt.isAfter(prev)) {
            lastSeen[word] = createdAt;
          }
        }
      }
    }
    final trendingEntries = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final trending = trendingEntries
        .take(trendingLimit)
        .map(
          (e) => TrendingKeyword(
            word: e.key,
            count: e.value,
            lastSeen: lastSeen[e.key],
          ),
        )
        .toList();

    // ── 2. Top fragments by importance × recency ─────────────────
    final topRows = await db.rawQuery(
      '''
      SELECT *, (importance_score * 0.6 + access_count / 10.0 * 0.4) AS rank
      FROM memory_fragments
      WHERE is_active = 1
      ORDER BY rank DESC, last_access_at DESC, created_at DESC
      LIMIT ?
    ''',
      [topFragmentLimit],
    );
    final topFragments = topRows.map(MemoryFragment.fromRow).toList();

    // ── 3. Recent summaries ───────────────────────────────────────
    final summaryRows = await db.rawQuery(
      '''
      SELECT * FROM memory_summaries
      ORDER BY updated_at DESC
      LIMIT ?
    ''',
      [recentSummaryLimit],
    );
    final recentSummaries = summaryRows.map(_summaryFromRow).toList();

    // ── 4. Forgotten / archived count in window ──────────────────
    final forgottenRow = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt FROM memory_fragments
      WHERE (is_active = 0 OR source = 'forgotten')
        AND updated_at >= ?
    ''',
      [cutoff],
    );
    final forgottenCount = (forgottenRow.first['cnt'] as int?) ?? 0;

    return MemoryInsights(
      trending: trending,
      topFragments: topFragments,
      recentSummaries: recentSummaries,
      forgottenCount: forgottenCount,
      windowDays: windowDays,
    );
  }

  static MemorySummary _summaryFromRow(Map<String, dynamic> row) {
    return MemorySummary(
      summaryId: row['summary_id'] as String,
      userId: (row['user_id'] as String?) ?? '',
      summaryTier: MemorySummaryTier.values.firstWhere(
        (t) => t.name == (row['summary_tier'] as String? ?? 'none'),
        orElse: () => MemorySummaryTier.none,
      ),
      sourceTier: MemoryTier.values.firstWhere(
        (t) => t.name == (row['source_tier'] as String? ?? 'short'),
        orElse: () => MemoryTier.short,
      ),
      startTimestamp: DateTime.parse(row['start_timestamp'] as String),
      endTimestamp: DateTime.parse(row['end_timestamp'] as String),
      messageCount: (row['message_count'] as int?) ?? 0,
      sourceRecordIds: ((row['source_record_ids'] as String?) ?? '')
          .split('|')
          .where((s) => s.isNotEmpty)
          .toList(),
      keyPoints: ((row['key_points'] as String?) ?? '')
          .split('|')
          .where((s) => s.isNotEmpty)
          .toList(),
      keywords: ((row['keywords'] as String?) ?? '')
          .split('|')
          .where((s) => s.isNotEmpty)
          .toList(),
      summaryText: (row['summary_text'] as String?) ?? '',
      qualityScore: (row['quality_score'] as num?)?.toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  /// Tokenize content for trending keyword extraction. English-ish
  /// splitting: lowercased, alphabetic, length ≥ 3, with a small
  /// built-in stopword list. Not a real stemmer — for ranking that's
  /// good enough.
  static final Set<String> _stopwords = {
    'the',
    'and',
    'that',
    'this',
    'with',
    'from',
    'have',
    'has',
    'are',
    'was',
    'were',
    'been',
    'will',
    'would',
    'could',
    'should',
    'into',
    'over',
    'also',
    'than',
    'then',
    'they',
    'them',
    'their',
    'there',
    'these',
    'those',
    'what',
    'when',
    'where',
    'which',
    'while',
    'your',
    'you',
    'but',
    'not',
    'for',
    'all',
    'any',
    'can',
    'its',
    'may',
    'his',
    'her',
    'she',
    'him',
    'who',
    'how',
    'our',
    'out',
    'one',
    'two',
    'get',
    'got',
    'use',
    'used',
    'using',
    'make',
    'made',
    'know',
    'just',
    'some',
    'such',
    'only',
    'very',
    'more',
    'most',
    'other',
  };

  static List<String> _tokenizeForTrending(String content) {
    if (content.isEmpty) return const [];
    final words = content
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_stopwords.contains(w))
        .toList();
    return words;
  }
}

final memoryInsightsProvider = FutureProvider<MemoryInsights>((ref) async {
  final memory = ref.watch(memoryServiceProvider);
  return MemoryInsightsService(memory).compute();
});

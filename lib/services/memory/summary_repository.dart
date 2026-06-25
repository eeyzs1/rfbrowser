import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../data/models/chat_memory.dart';
import '../../data/stores/index_store.dart';
import 'memory_database.dart';

/// Repository for the `memory_summaries` table (Layer 1.5 of the memory
/// pyramid). Stores L1/L2/L3 consolidated summaries produced by the
/// dreaming engine.
class SummaryRepository {
  final MemoryDatabase _db;
  SummaryRepository(this._db);

  Future<Database> get _database => _db.database;

  /// Persist a synthesized memory summary. Stored in its own table so it can
  /// be queried independently of fragments.
  Future<void> saveSummary(MemorySummary summary) async {
    final db = await _database;
    await db.insert('memory_summaries', _summaryToRow(summary));
  }

  Future<void> saveSummaries(List<MemorySummary> summaries) async {
    if (summaries.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      for (final s in summaries) {
        await txn.insert('memory_summaries', _summaryToRow(s));
      }
    });
  }

  /// Find summaries whose keywords or text match the given query.
  Future<List<MemorySummary>> searchSummaries(
    String query, {
    int limit = 5,
    List<MemorySummaryTier>? tiers,
  }) async {
    final db = await _database;
    final tokenized = IndexStore.tokenizeForFts(query);
    if (tokenized.isEmpty) return [];
    final tierFilter = tiers == null || tiers.isEmpty
        ? null
        : tiers.map((t) => "'${t.name}'").join(',');
    final whereTier = tierFilter != null
        ? 'AND summary_tier IN ($tierFilter)'
        : '';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM memory_summaries
      WHERE (keywords LIKE ? OR summary_text LIKE ?) $whereTier
      ORDER BY end_timestamp DESC
      LIMIT ?
      ''',
      ['%$tokenized%', '%$tokenized%', limit],
    );
    return rows.map(_summaryFromRow).toList();
  }

  Map<String, Object?> _summaryToRow(MemorySummary s) => {
    'summary_id': s.summaryId,
    'user_id': s.userId,
    'summary_tier': s.summaryTier.name,
    'source_tier': s.sourceTier.name,
    'start_timestamp': s.startTimestamp.toIso8601String(),
    'end_timestamp': s.endTimestamp.toIso8601String(),
    'message_count': s.messageCount,
    'source_record_ids': s.sourceRecordIds.join('|'),
    'key_points': s.keyPoints.join('|'),
    'keywords': s.keywords.join('|'),
    'summary_text': s.summaryText,
    'quality_score': s.qualityScore,
    'created_at': s.createdAt.toIso8601String(),
    'updated_at': s.updatedAt.toIso8601String(),
  };

  MemorySummary _summaryFromRow(Map<String, Object?> r) {
    List<String> splitList(Object? raw) {
      final s = (raw as String?) ?? '';
      if (s.isEmpty) return const [];
      return s.split('|').where((e) => e.isNotEmpty).toList(growable: false);
    }

    return MemorySummary(
      summaryId: r['summary_id']! as String,
      userId: r['user_id']! as String,
      summaryTier: MemorySummaryTier.values.firstWhere(
        (t) => t.name == r['summary_tier'],
        orElse: () => MemorySummaryTier.l1,
      ),
      sourceTier: MemoryTier.values.firstWhere(
        (t) => t.name == r['source_tier'],
        orElse: () => MemoryTier.short,
      ),
      startTimestamp: DateTime.parse(r['start_timestamp']! as String),
      endTimestamp: DateTime.parse(r['end_timestamp']! as String),
      messageCount: r['message_count']! as int,
      sourceRecordIds: splitList(r['source_record_ids']),
      keyPoints: splitList(r['key_points']),
      keywords: splitList(r['keywords']),
      summaryText: r['summary_text']! as String,
      qualityScore: (r['quality_score'] as num?)?.toDouble(),
      createdAt: DateTime.parse(r['created_at']! as String),
      updatedAt: DateTime.parse(r['updated_at']! as String),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/memory_service.dart';
import 'package:sqflite/sqflite.dart';

import 'memory_summarizer.dart';

/// Builds L2 (per-week) and L3 (per-month) summaries on top of existing
/// L1 / L2 summaries. The output rows go into `memory_summaries` with
/// `parent_summary_id` pointing at the rollup ancestor (L2 → set of L1s,
/// L3 → set of L2s).
///
/// Heuristics (rule-based, no LLM):
///   - L2: every 7-day window of L1 summaries that share ≥2 keywords
///   - L3: every 30-day window of L2 summaries that share ≥3 keywords
///   - Source records: the union of the child summaries' source_record_ids
///   - Key points: top 8 from children's key_points
///   - Keywords: top 24 from children's keywords
///   - Window: child's start → child's end (rolled up)
///   - Quality: 0.65 base + 0.05 per child capped at 0.95
///
/// [runDaily] is the public hook called by the dreaming cycle.
class SummaryRollup {
  final MemoryService _memory;

  SummaryRollup(this._memory);

  static const Duration l2Window = Duration(days: 7);
  static const Duration l3Window = Duration(days: 30);
  static const int l2KeywordOverlapMin = 2;
  static const int l3KeywordOverlapMin = 3;

  /// Run one pass of the rollup. Returns the counts of new L2 and L3
  /// rows created. Safe to call repeatedly — if no children are due
  /// for a rollup the call is a no-op.
  Future<({int l2Created, int l3Created})> runDaily({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final l2Created = await _rollupTier(
      sourceTier: MemorySummaryTier.l1,
      targetTier: MemorySummaryTier.l2,
      window: l2Window,
      minKeywordOverlap: l2KeywordOverlapMin,
      now: n,
    );
    final l3Created = await _rollupTier(
      sourceTier: MemorySummaryTier.l2,
      targetTier: MemorySummaryTier.l3,
      window: l3Window,
      minKeywordOverlap: l3KeywordOverlapMin,
      now: n,
    );
    return (l2Created: l2Created, l3Created: l3Created);
  }

  Future<int> _rollupTier({
    required MemorySummaryTier sourceTier,
    required MemorySummaryTier targetTier,
    required Duration window,
    required int minKeywordOverlap,
    required DateTime now,
  }) async {
    final db = await _memory.database;
    // Find child summaries that ended at least `window` ago and have no
    // parent_summary_id pointing at this tier.
    final cutoff = now.subtract(window).toIso8601String();
    final rows = await db.query(
      'memory_summaries',
      where:
          'summary_tier = ? AND end_timestamp <= ? '
          'AND (parent_summary_id IS NULL OR '
          '       parent_summary_id NOT IN (SELECT summary_id FROM memory_summaries '
          '                                WHERE summary_tier = ?))',
      whereArgs: [sourceTier.name, cutoff, targetTier.name],
    );
    if (rows.isEmpty) return 0;

    final children = rows.map(_summaryFromRow).toList();
    final clusters = _clusterByKeywordOverlap(
      children,
      minOverlap: minKeywordOverlap,
    );

    var created = 0;
    for (final cluster in clusters) {
      if (cluster.length < 2) continue;
      final rollup = _buildRollupSummary(
        cluster: cluster,
        targetTier: targetTier,
        sourceTier: sourceTier,
        now: now,
        window: window,
      );
      await db.transaction((txn) async {
        await txn.insert(
          'memory_summaries',
          _summaryToRow(rollup),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        // Link each child to the new rollup.
        for (final c in cluster) {
          await txn.update(
            'memory_summaries',
            {
              'parent_summary_id': rollup.summaryId,
              'updated_at': now.toIso8601String(),
            },
            where: 'summary_id = ?',
            whereArgs: [c.summaryId],
          );
        }
      });
      created++;
    }
    if (created > 0) {
      debugPrint(
        'SummaryRollup: created $created $targetTier summaries from '
        '${children.length} $sourceTier children',
      );
    }
    return created;
  }

  // ── clustering ─────────────────────────────────────────────────

  /// Group summaries into clusters by keyword-set overlap. Two summaries
  /// are linked if they share at least [minOverlap] keywords. Clusters
  /// are computed by union-find: any two summaries transitively
  /// connected form a single cluster.
  List<List<MemorySummary>> _clusterByKeywordOverlap(
    List<MemorySummary> summaries, {
    required int minOverlap,
  }) {
    final parent = <String, String>{};
    for (final s in summaries) {
      parent[s.summaryId] = s.summaryId;
    }
    String find(String x) {
      var r = x;
      while (parent[r] != r) {
        parent[r] = parent[parent[r]]!;
        r = parent[r]!;
      }
      return r;
    }

    void union(String a, String b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    for (var i = 0; i < summaries.length; i++) {
      for (var j = i + 1; j < summaries.length; j++) {
        final a = summaries[i];
        final b = summaries[j];
        final overlap = a.keywords.toSet().intersection(b.keywords.toSet());
        if (overlap.length >= minOverlap) {
          union(a.summaryId, b.summaryId);
        }
      }
    }
    final groups = <String, List<MemorySummary>>{};
    for (final s in summaries) {
      final r = find(s.summaryId);
      groups.putIfAbsent(r, () => []).add(s);
    }
    return groups.values.toList();
  }

  MemorySummary _buildRollupSummary({
    required List<MemorySummary> cluster,
    required MemorySummaryTier targetTier,
    required MemorySummaryTier sourceTier,
    required DateTime now,
    required Duration window,
  }) {
    final sorted = [...cluster]
      ..sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
    final startTs = sorted.first.startTimestamp;
    final endTs = sorted.last.endTimestamp;

    // Union of all source record ids.
    final allRecords = <String>{};
    for (final c in cluster) {
      allRecords.addAll(c.sourceRecordIds);
    }
    // Union + ranking of keyPoints and keywords.
    final keyPointsRanked = <String, int>{};
    for (final c in cluster) {
      for (final p in c.keyPoints) {
        keyPointsRanked[p] = (keyPointsRanked[p] ?? 0) + 1;
      }
    }
    final keywordsRanked = <String, int>{};
    for (final c in cluster) {
      for (final k in c.keywords) {
        keywordsRanked[k] = (keywordsRanked[k] ?? 0) + 1;
      }
    }
    final keyPoints =
        (keyPointsRanked.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(8)
            .map((e) => e.key)
            .toList();
    final keywords =
        (keywordsRanked.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(24)
            .map((e) => e.key)
            .toList();
    final groupId = 'rollup-${sorted.first.summaryId}-${sorted.last.summaryId}';
    final quality = (0.65 + 0.05 * cluster.length).clamp(0.65, 0.95);
    final summaryText = [
      'Window: ${_formatDate(startTs)} -> ${_formatDate(endTs)}',
      'Rollup tier: $sourceTier -> $targetTier',
      'Children: ${cluster.length}',
      'Records covered: ${allRecords.length}',
      if (keyPoints.isNotEmpty) 'Highlights: ${keyPoints.take(3).join(' | ')}',
    ].join('\n');
    return MemorySummary(
      summaryId: buildSummaryId(
        userId: cluster.first.userId,
        summaryTier: targetTier,
        groupId: groupId,
        endTimestamp: endTs,
      ),
      userId: cluster.first.userId,
      summaryTier: targetTier,
      sourceTier: MemoryTier.mid,
      startTimestamp: startTs,
      endTimestamp: endTs,
      messageCount: cluster.length,
      sourceRecordIds: allRecords.toList(),
      keyPoints: keyPoints,
      keywords: keywords,
      summaryText: summaryText,
      qualityScore: quality,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _formatDate(DateTime t) {
    final d = t.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // ── row mapping ────────────────────────────────────────────────

  static MemorySummary _summaryFromRow(Map<String, dynamic> row) {
    return MemorySummary(
      summaryId: row['summary_id'] as String,
      userId: (row['user_id'] as String?) ?? '',
      summaryTier: MemorySummaryTier.values.firstWhere(
        (t) => t.name == (row['summary_tier'] as String? ?? 'l1'),
        orElse: () => MemorySummaryTier.l1,
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

  static Map<String, Object?> _summaryToRow(MemorySummary s) {
    return {
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
      'parent_summary_id': null,
    };
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_memory.dart';
import 'memory_service.dart';

part 'memory_insights_service.dart';

/// Aggregate statistics about the memory subsystem.
///
/// Pulled together from [MemoryService] in a single sweep so the UI can
/// render one "Stats" card without needing to subscribe to multiple
/// streams. Computed lazily; if the underlying data changes, callers
/// should invalidate via `ref.invalidate(memoryStatsProvider)`.
class MemoryStats {
  final int totalFragments;
  final int activeFragments;
  final int pinnedFragments;
  final Map<MemoryTier, int> fragmentsByTier;
  final int totalSummaries;
  final Map<MemorySummaryTier, int> summariesByTier;
  final int totalHebbianEdges;
  final int totalChatMessages;
  final double averageImportance;
  final double averageAccessCount;
  final DateTime? oldestFragment;
  final DateTime? newestFragment;
  final DateTime? lastSummary;
  final DateTime? lastChatMessage;
  final int archivedFragments;

  const MemoryStats({
    this.totalFragments = 0,
    this.activeFragments = 0,
    this.pinnedFragments = 0,
    this.fragmentsByTier = const {},
    this.totalSummaries = 0,
    this.summariesByTier = const {},
    this.totalHebbianEdges = 0,
    this.totalChatMessages = 0,
    this.averageImportance = 0.0,
    this.averageAccessCount = 0.0,
    this.oldestFragment,
    this.newestFragment,
    this.lastSummary,
    this.lastChatMessage,
    this.archivedFragments = 0,
  });

  bool get isEmpty => totalFragments == 0 && totalSummaries == 0;

  /// Human-readable "memory age" for the deepest tier a fragment exists in.
  /// Returns null when there are no fragments.
  String? get memoryHealthLabel {
    if (totalFragments == 0) return null;
    if (activeFragments == 0) return 'no active fragments';
    final inLong = fragmentsByTier[MemoryTier.long] ?? 0;
    final inMid = fragmentsByTier[MemoryTier.mid] ?? 0;
    final inShort = fragmentsByTier[MemoryTier.short] ?? 0;
    if (inLong > 0 && inMid > 0 && inShort > 0) return 'balanced';
    if (inLong > inMid && inLong > inShort) return 'long-tier heavy';
    if (inShort > inMid) return 'fresh';
    return 'mid-heavy';
  }
}

/// Computes [MemoryStats] for the current vault. Reads happen against
/// [MemoryService] so callers can keep this provider scoped to a vault
/// lifecycle (it automatically tracks the active memory service).
class MemoryStatsService {
  final MemoryService _memory;
  MemoryStatsService(this._memory);

  Future<MemoryStats> compute({DateTime? now}) async {
    final db = await _memory.database;

    // ── Fragments: counts and per-tier breakdown ────────────────────
    final fragRows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) AS active,
        SUM(CASE WHEN is_pinned  = 1 THEN 1 ELSE 0 END) AS pinned,
        SUM(CASE WHEN archived_at IS NOT NULL THEN 1 ELSE 0 END) AS archived,
        AVG(importance_score) AS avg_importance,
        AVG(access_count) AS avg_access
      FROM memory_fragments
    ''');
    final fragRow = fragRows.first;
    final totalFragments = (fragRow['total'] as int?) ?? 0;
    final activeFragments = (fragRow['active'] as int?) ?? 0;
    final pinnedFragments = (fragRow['pinned'] as int?) ?? 0;
    final archivedFragments = (fragRow['archived'] as int?) ?? 0;
    final averageImportance =
        ((fragRow['avg_importance'] as num?)?.toDouble() ?? 0.0).clamp(
          0.0,
          1.0,
        );
    final averageAccessCount =
        ((fragRow['avg_access'] as num?)?.toDouble() ?? 0.0).clamp(
          0.0,
          double.infinity,
        );

    final tierRows = await db.rawQuery('''
      SELECT tier, COUNT(*) AS cnt
      FROM memory_fragments
      WHERE is_active = 1
      GROUP BY tier
    ''');
    final fragmentsByTier = <MemoryTier, int>{
      for (final t in MemoryTier.values) t: 0,
    };
    for (final row in tierRows) {
      final t = (row['tier'] as String?) ?? 'short';
      final cnt = (row['cnt'] as int?) ?? 0;
      final tier = MemoryTier.values.firstWhere(
        (e) => e.name == t,
        orElse: () => MemoryTier.short,
      );
      fragmentsByTier[tier] = cnt;
    }

    DateTime? oldestFragment;
    DateTime? newestFragment;
    if (totalFragments > 0) {
      final rangeRow = await db.rawQuery('''
        SELECT MIN(created_at) AS oldest, MAX(created_at) AS newest
        FROM memory_fragments
      ''');
      final r = rangeRow.first;
      oldestFragment = _parseDate(r['oldest']);
      newestFragment = _parseDate(r['newest']);
    }

    // ── Summaries: counts per tier ──────────────────────────────────
    final summaryRows = await db.rawQuery('''
      SELECT summary_tier, COUNT(*) AS cnt
      FROM memory_summaries
      GROUP BY summary_tier
    ''');
    final summariesByTier = <MemorySummaryTier, int>{
      for (final t in MemorySummaryTier.values) t: 0,
    };
    var totalSummaries = 0;
    for (final row in summaryRows) {
      final t = (row['summary_tier'] as String?) ?? 'none';
      final cnt = (row['cnt'] as int?) ?? 0;
      final tier = MemorySummaryTier.values.firstWhere(
        (e) => e.name == t,
        orElse: () => MemorySummaryTier.none,
      );
      summariesByTier[tier] = cnt;
      totalSummaries += cnt;
    }

    DateTime? lastSummary;
    if (totalSummaries > 0) {
      final r = await db.rawQuery(
        'SELECT MAX(updated_at) AS last FROM memory_summaries',
      );
      lastSummary = _parseDate(r.first['last']);
    }

    // ── Hebbian edges ──────────────────────────────────────────────
    final edgeRow = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM memory_hebbian_links',
    );
    final totalHebbianEdges = (edgeRow.first['cnt'] as int?) ?? 0;

    // ── Chat messages ──────────────────────────────────────────────
    final msgRow = await db.rawQuery(
      'SELECT COUNT(*) AS cnt, MAX(timestamp) AS last FROM chat_messages',
    );
    final totalChatMessages = (msgRow.first['cnt'] as int?) ?? 0;
    final lastChatMessage = _parseDate(msgRow.first['last']);

    return MemoryStats(
      totalFragments: totalFragments,
      activeFragments: activeFragments,
      pinnedFragments: pinnedFragments,
      fragmentsByTier: fragmentsByTier,
      totalSummaries: totalSummaries,
      summariesByTier: summariesByTier,
      totalHebbianEdges: totalHebbianEdges,
      totalChatMessages: totalChatMessages,
      averageImportance: averageImportance,
      averageAccessCount: averageAccessCount,
      oldestFragment: oldestFragment,
      newestFragment: newestFragment,
      lastSummary: lastSummary,
      lastChatMessage: lastChatMessage,
      archivedFragments: archivedFragments,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is String && raw.isEmpty) return null;
    try {
      return DateTime.parse(raw as String);
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for [MemoryStats]. The UI calls
/// `ref.invalidate(memoryStatsProvider)` after operations that mutate the
/// underlying fragments/summaries so the next read recomputes.
final memoryStatsProvider = FutureProvider<MemoryStats>((ref) async {
  final memory = ref.watch(memoryServiceProvider);
  return MemoryStatsService(memory).compute();
});

import 'dart:async';

import '../../core/logging/app_logger.dart';
import '../../data/models/chat_memory.dart';
import '../active_memory_buffer.dart';
import '../hebbian_service.dart';
import '../memory_service.dart';
import 'ai_models.dart';

/// Builds the memory-context portion of the AI system prompt.
///
/// Pipeline:
///   1. FTS5 search → top-k fragments
///   2. Hebbian expansion → related fragments that didn't match the query
///   3. Record the union as a co-access group (so the next call sees
///      stronger edges between them)
///   4. Fall back to summary search when fragment results are sparse
///   5. Trim to the user-configured token budget
class MemoryContextBuilder {
  final MemoryService _memory;
  final HebbianService _hebbian;
  final ActiveMemoryBuffer _activeBuffer;

  MemoryContextBuilder({
    required MemoryService memory,
    required HebbianService hebbian,
    required ActiveMemoryBuffer activeBuffer,
  })  : _memory = memory,
        _hebbian = hebbian,
        _activeBuffer = activeBuffer;

  /// Query relevant memory fragments and format them for the system prompt.
  /// Returns a [MemoryContextBundle] containing the formatted context
  /// string, source fragment/summary ids, and token usage.
  Future<MemoryContextBundle> buildContext(
    String userMessage, {
    String? sessionId,
    required int budget,
  }) async {
    try {
      final fragments = await _memory.searchFragments(userMessage, limit: 5);
      final neighbors = fragments.isEmpty
          ? const <HebbianNeighbor>[]
          : await _hebbian.expandByHebbianLinks(
              fragments.map((f) => f.id),
              limit: 3,
            );

      // Record co-access for the union of primary + neighbors. Failures are
      // logged but never block the response.
      final coAccessIds = <String>[
        ...fragments.map((f) => f.id),
        ...neighbors.map((n) => n.fragment.id),
      ];
      if (coAccessIds.length > 1) {
        unawaited(
          _hebbian.recordCoAccess(coAccessIds).catchError((Object e) {
            appLog.error('AI: hebbian recordCoAccess error', error: e);
          }),
        );
      }
      // On-retrieval Hebbian reinforcement: the network "votes" for the
      // user's current focus. Strengthens the primary → neighbor edges.
      if (fragments.isNotEmpty) {
        unawaited(
          _hebbian.recordSearchAccess(fragments.map((f) => f.id)).catchError((
            Object e,
          ) {
            appLog.error('AI: hebbian recordSearchAccess error', error: e);
          }),
        );
      }

      // Active working memory: per-session pinned fragments that bypass
      // the budget cap and are always included. Resolved via the buffer
      // which is RAM-only.
      final activeIds = sessionId == null
          ? const <String>[]
          : _activeBuffer.activeIds(sessionId);
      final activeFragments = sessionId == null || activeIds.isEmpty
          ? const <MemoryFragment>[]
          : await _activeBuffer.getActive(sessionId);

      final allFragments = <MemoryFragment>[
        ...activeFragments, // active first; will sort later
        ...fragments,
        ...neighbors.map((n) => n.fragment),
      ];

      // Token budget cap: drop low-score fragments until the formatted
      // context fits within `budget` (approx 4 chars per token).
      // Active fragments are pinned to the front and skip the cap.
      final activeSet = activeIds.toSet();
      final pinned = allFragments
          .where((f) => activeSet.contains(f.id))
          .toList();
      final ordered =
          allFragments.where((f) => !activeSet.contains(f.id)).toList()
            ..sort((a, b) {
              // Higher importance first, then higher recency.
              final s = b.importanceScore.compareTo(a.importanceScore);
              if (s != 0) return s;
              return (b.lastAccessAt ?? b.createdAt).compareTo(
                a.lastAccessAt ?? a.createdAt,
              );
            });
      var picked = <MemoryFragment>[...pinned];
      var used = pinned.fold<int>(
        0,
        (acc, f) => acc + (f.content.length / 4).ceil() + 20,
      );
      for (final f in ordered) {
        // Approximate the formatted cost as 4× content length.
        final cost = (f.content.length / 4).ceil() + 20;
        if (used + cost > budget) continue;
        picked.add(f);
        used += cost;
      }

      String? ctx = picked.isEmpty
          ? null
          : MemoryService.formatFragmentsForContext(picked);

      var summaryIds = const <String>[];
      // Fallback: if nothing fit, look at summaries.
      if (picked.isEmpty) {
        final summaries = await _memory.searchSummaries(userMessage, limit: 3);
        if (summaries.isNotEmpty) {
          ctx = _formatSummariesForContext(summaries);
          summaryIds = summaries.map((s) => s.summaryId).toList();
        }
      }
      return MemoryContextBundle(
        context: ctx,
        fragmentIds: picked.map((f) => f.id).toList(),
        summaryIds: summaryIds,
        tokensUsed: used,
        budget: budget,
      );
    } catch (e) {
      appLog.error('AI: memory context query failed', error: e);
      return const MemoryContextBundle.empty();
    }
  }

  static String _formatSummariesForContext(List<MemorySummary> summaries) {
    final buffer = StringBuffer();
    buffer.writeln('[Past conversation summaries — distilled knowledge:]');
    for (final s in summaries) {
      buffer.writeln(
        '- [${s.summaryTier.name.toUpperCase()}] ${s.summaryText}',
      );
    }
    return buffer.toString();
  }
}

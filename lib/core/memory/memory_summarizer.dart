import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../data/models/chat_memory.dart';
import 'memory_scorer.dart';

const _uuid = Uuid();

/// A group of fragments that can be consolidated into a single L1 summary.
///
/// Mirrors the in-memory `MemoryGroup` shape used in OpenLoomi's
/// `engine.ts`. The forgetting engine constructs these from the eligible
/// fragments returned by [MemoryScorer].
class MemoryGroup {
  final String groupId;
  final String userId;
  final MemoryTier sourceTier;
  final MemoryTier targetTier;
  final MemorySummaryTier summaryTier;
  final List<ScoredMemoryFragment> records;
  final DateTime startTimestamp;
  final DateTime endTimestamp;

  const MemoryGroup({
    required this.groupId,
    required this.userId,
    required this.sourceTier,
    required this.targetTier,
    required this.summaryTier,
    required this.records,
    required this.startTimestamp,
    required this.endTimestamp,
  });
}

/// Stable hash for ids derived from a string. Mirrors the OpenLoomi
/// `hashString` helper. Returns an unsigned 32-bit hex string.
String _stableHash(String input) {
  var hash = 5381;
  for (var i = 0; i < input.length; i++) {
    hash = (hash * 33) ^ input.codeUnitAt(i);
  }
  return (hash & 0xFFFFFFFF).toRadixString(16);
}

/// Build a stable, deterministic summary id from the group identity. The
/// same group will always produce the same id, which makes summarization
/// idempotent across cycles.
String buildSummaryId({
  required String userId,
  required MemorySummaryTier summaryTier,
  required String groupId,
  required DateTime endTimestamp,
}) {
  final raw = '$userId|${summaryTier.name}|$groupId|${endTimestamp.millisecondsSinceEpoch}';
  return 'ms_${_stableHash(raw)}';
}

/// Build a stable group id from a time window and dimensions. Used so that
/// multiple calls in the same window collapse to the same group.
String buildGroupId({
  required MemoryTier sourceTier,
  required DateTime bucketStart,
  required Map<String, String> dimensionKey,
}) {
  final dimPart = dimensionKey.entries
      .map((e) => '${e.key}=${e.value}')
      .join('|');
  return '${sourceTier.name}|${bucketStart.millisecondsSinceEpoch}|$dimPart';
}

/// Round a timestamp down to the start of its containing window.
///
/// Operates in the timestamp's *local* timezone so that callers that
/// bucket by "1 day" or "1 hour" see buckets that align with their
/// local calendar — important for human-readable summary windows.
DateTime bucketStart(DateTime timestamp, Duration window) {
  final local = timestamp.isUtc ? timestamp.toLocal() : timestamp;
  final windowMs = window.inMilliseconds;
  if (windowMs <= 0) return local;
  if (window.inDays >= 1 && window.inDays * Duration.millisecondsPerDay == windowMs) {
    // For day-aligned windows, anchor on local midnight so that
    // "1 day" windows line up with the local calendar.
    return DateTime(local.year, local.month, local.day);
  }
  if (window.inHours >= 1 && window.inHours * Duration.millisecondsPerHour == windowMs) {
    return DateTime(local.year, local.month, local.day, local.hour);
  }
  if (window.inMinutes >= 1 &&
      window.inMinutes * Duration.millisecondsPerMinute == windowMs) {
    return DateTime(
      local.year, local.month, local.day, local.hour, local.minute,
    );
  }
  // Fall back to ms-based bucketing for arbitrary durations.
  final ms = local.millisecondsSinceEpoch;
  final floored = (ms ~/ windowMs) * windowMs;
  return DateTime.fromMillisecondsSinceEpoch(floored, isUtc: false);
}

/// Default summary-tier mapping for transitions.
MemorySummaryTier summaryTierForTransition(MemoryTier from) {
  switch (from) {
    case MemoryTier.short:
      return MemorySummaryTier.l1;
    case MemoryTier.mid:
      return MemorySummaryTier.l2;
    case MemoryTier.long:
      return MemorySummaryTier.l3;
  }
}

/// Target tier for a transition.
MemoryTier transitionTargetTier(MemoryTier from) {
  switch (from) {
    case MemoryTier.short:
      return MemoryTier.mid;
    case MemoryTier.mid:
      return MemoryTier.long;
    case MemoryTier.long:
      return MemoryTier.long;
  }
}

/// Builds an L1/L2/L3 summary from a group of memory fragments.
///
/// The default implementation is rule-based (no LLM call required):
///   - keyPoints: first 5 non-empty content strings, sliced to 180 chars
///   - keywords:  top 12 most frequent non-stop-word tokens
///   - summaryText: window + transition header + highlights
///
/// A custom summarizer can be supplied to plug in an LLM later.
abstract class MemorySummarizer {
  MemorySummary buildSummary(MemoryGroup group, {DateTime? now});
}

class RuleBasedMemorySummarizer implements MemorySummarizer {
  final MemorySummaryLexicon lexicon;
  final int keyPointMaxLength;
  final int keyPointLimit;
  final int keywordLimit;

  const RuleBasedMemorySummarizer({
    this.lexicon = const MemorySummaryLexicon(),
    this.keyPointMaxLength = 180,
    this.keyPointLimit = 5,
    this.keywordLimit = 12,
  });

  @override
  MemorySummary buildSummary(MemoryGroup group, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final sorted = [...group.records]
      ..sort((a, b) => a.fragment.createdAt.compareTo(b.fragment.createdAt));

    final texts = sorted
        .map((r) => r.fragment.content)
        .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final seen = <String>{};
    final keyPoints = <String>[];
    for (final t in texts) {
      if (keyPoints.length >= keyPointLimit) break;
      if (seen.add(t)) {
        keyPoints.add(_slice(t, keyPointMaxLength));
      }
    }

    final keywords = lexicon.topKeywords(texts, maxCount: keywordLimit);

    final start = _formatDate(group.startTimestamp);
    final end = _formatDate(group.endTimestamp);

    final highlights = keyPoints.isEmpty
        ? 'Highlights: (no text content, likely attachment-driven records)'
        : 'Highlights: ${keyPoints.join(' | ')}';

    final summaryText = [
      'Window: $start -> $end',
      'Tier transition: ${group.sourceTier.name} -> ${group.targetTier.name} '
          '(${group.summaryTier.name})',
      'Records: ${group.records.length}',
      highlights,
    ].join('\n');

    return MemorySummary(
      summaryId: buildSummaryId(
        userId: group.userId,
        summaryTier: group.summaryTier,
        groupId: group.groupId,
        endTimestamp: group.endTimestamp,
      ),
      userId: group.userId,
      summaryTier: group.summaryTier,
      sourceTier: group.sourceTier,
      startTimestamp: group.startTimestamp,
      endTimestamp: group.endTimestamp,
      messageCount: group.records.length,
      sourceRecordIds: group.records.map((r) => r.fragment.id).toList(),
      keyPoints: keyPoints,
      keywords: keywords,
      summaryText: summaryText,
      qualityScore: keyPoints.isNotEmpty ? 0.75 : 0.45,
      createdAt: n,
      updatedAt: n,
    );
  }

  static String _slice(String s, int maxLength) {
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength - 3)}...';
  }

  static String _formatDate(DateTime t) {
    final d = t.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

/// Convenience constructor used by tests and callers that need a one-shot
/// summary without going through the full engine.
String debugSummaryToJson(MemorySummary s) => jsonEncode({
      'summary_id': s.summaryId,
      'summary_tier': s.summaryTier.name,
      'source_tier': s.sourceTier.name,
      'message_count': s.messageCount,
      'key_points': s.keyPoints,
      'keywords': s.keywords,
      'summary_text': s.summaryText,
    });

/// Build a fresh, unique id (UUID v4) when callers need one that isn't
/// deterministically derived from a group. Exposed so [DreamingService] can
/// mint fragment ids for new entries.
String generateFragmentId() => _uuid.v4();

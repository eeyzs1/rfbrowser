import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/memory/memory_scorer.dart';
import 'package:rfbrowser/core/memory/memory_summarizer.dart';
import 'package:rfbrowser/data/models/chat_memory.dart';

MemoryFragment _frag({
  required String id,
  required String content,
  DateTime? createdAt,
  MemoryTier tier = MemoryTier.short,
  double importance = 0.0,
}) {
  final now = DateTime.now();
  final ts = createdAt ?? now;
  return MemoryFragment(
    id: id,
    sessionId: 's',
    content: content,
    tier: tier,
    importanceScore: importance,
    createdAt: ts,
    updatedAt: ts,
  );
}

MemoryGroup _group(List<MemoryFragment> fragments, {MemoryTier from = MemoryTier.short}) {
  final sorted = [...fragments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return MemoryGroup(
    groupId: 'g1',
    userId: 'u1',
    sourceTier: from,
    targetTier: transitionTargetTier(from),
    summaryTier: summaryTierForTransition(from),
    records: sorted
        .map((f) => ScoredMemoryFragment(
              fragment: f,
              valueScore: 0.0,
              recencyScore: 0.0,
              accessScore: 0.0,
              importanceScore: 0.0,
              mediaScore: 0.0,
            ))
        .toList(),
    startTimestamp: sorted.first.createdAt,
    endTimestamp: sorted.last.createdAt,
  );
}

void main() {
  group('buildSummaryId', () {
    test('is deterministic for the same inputs', () {
      final ts = DateTime.utc(2026, 1, 1, 12);
      final a = buildSummaryId(
        userId: 'u1',
        summaryTier: MemorySummaryTier.l1,
        groupId: 'g1',
        endTimestamp: ts,
      );
      final b = buildSummaryId(
        userId: 'u1',
        summaryTier: MemorySummaryTier.l1,
        groupId: 'g1',
        endTimestamp: ts,
      );
      expect(a, equals(b));
    });

    test('differs when summary tier differs', () {
      final ts = DateTime.utc(2026, 1, 1, 12);
      final a = buildSummaryId(
        userId: 'u1',
        summaryTier: MemorySummaryTier.l1,
        groupId: 'g1',
        endTimestamp: ts,
      );
      final b = buildSummaryId(
        userId: 'u1',
        summaryTier: MemorySummaryTier.l2,
        groupId: 'g1',
        endTimestamp: ts,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('bucketStart', () {
    test('rounds down to window boundary', () {
      // Use a local DateTime so we don't have to worry about TZ; the
      // algorithm operates on millis-since-epoch and produces a local
      // DateTime back, so we compare local-to-local.
      final t = DateTime(2026, 1, 15, 13, 42, 17);
      final window = const Duration(days: 1);
      final b = bucketStart(t, window);
      expect(b, DateTime(2026, 1, 15));
    });
  });

  group('transition helpers', () {
    test('short -> mid / l1', () {
      expect(transitionTargetTier(MemoryTier.short), MemoryTier.mid);
      expect(
        summaryTierForTransition(MemoryTier.short),
        MemorySummaryTier.l1,
      );
    });

    test('mid -> long / l2', () {
      expect(transitionTargetTier(MemoryTier.mid), MemoryTier.long);
      expect(
        summaryTierForTransition(MemoryTier.mid),
        MemorySummaryTier.l2,
      );
    });
  });

  group('RuleBasedMemorySummarizer', () {
    const summarizer = RuleBasedMemorySummarizer();

    test('produces key points and keywords from a group', () {
      final group = _group([
        _frag(
          id: 'a',
          content: 'The user is working on a Flutter desktop app.',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        _frag(
          id: 'b',
          content: 'They prefer Riverpod for state management.',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      ]);
      final summary = summarizer.buildSummary(group, now: DateTime.utc(2026, 1, 2));

      expect(summary.sourceRecordIds, containsAll(['a', 'b']));
      expect(summary.keyPoints, isNotEmpty);
      expect(summary.keywords, contains('flutter'));
      expect(summary.summaryText, contains('Window:'));
      expect(summary.summaryText, contains('Tier transition: short -> mid (l1)'));
    });

    test('degrades gracefully for groups with no text', () {
      final group = _group([
        _frag(id: 'a', content: '', createdAt: DateTime.utc(2026, 1, 1)),
      ]);
      final summary = summarizer.buildSummary(group, now: DateTime.utc(2026, 1, 1));
      expect(summary.keyPoints, isEmpty);
      expect(summary.qualityScore, lessThan(0.5));
    });

    test('slices overly long key points', () {
      final long = 'a' * 500;
      final group = _group([
        _frag(id: 'a', content: long, createdAt: DateTime.utc(2026, 1, 1)),
      ]);
      final summary = summarizer.buildSummary(group, now: DateTime.utc(2026, 1, 1));
      expect(summary.keyPoints.first.length, lessThanOrEqualTo(180));
    });
  });
}

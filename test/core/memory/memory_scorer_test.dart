import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/memory/memory_scorer.dart';
import 'package:rfbrowser/data/models/chat_memory.dart';

MemoryFragment _fragment({
  MemoryTier tier = MemoryTier.short,
  double importance = 0.0,
  int accessCount = 0,
  bool isPinned = false,
  List<String> mediaRefs = const [],
  Duration? age,
  String content = '',
  DateTime? createdAt,
  DateTime? lastAccessAt,
  DateTime? archivedAt,
}) {
  final now = DateTime.now();
  final ts = createdAt ?? now.subtract(age ?? Duration.zero);
  return MemoryFragment(
    id: 'f-${ts.millisecondsSinceEpoch}-${tier.name}',
    sessionId: 's',
    content: content,
    tier: tier,
    importanceScore: importance,
    accessCount: accessCount,
    isPinned: isPinned,
    mediaRefs: mediaRefs,
    lastAccessAt: lastAccessAt,
    archivedAt: archivedAt,
    createdAt: ts,
    updatedAt: ts,
  );
}

void main() {
  group('MemoryScorer', () {
    const scorer = MemoryScorer();

    test('recent fragment scores higher than an old one with same shape', () {
      final fresh = _fragment(age: const Duration(hours: 1));
      final old = _fragment(age: const Duration(days: 90));
      expect(scorer.score(fresh), greaterThan(scorer.score(old)));
      // And a brand-new fragment with importance / access should be near
      // the top of the 0..1 range.
      final hot = _fragment(
        age: const Duration(hours: 1),
        importance: 0.9,
        accessCount: 100,
        isPinned: true,
      );
      expect(scorer.score(hot), greaterThan(0.9));
    });

    test('old fragment scores lower than recent one', () {
      final fresh = _fragment(age: const Duration(hours: 1));
      final old = _fragment(age: const Duration(days: 90));
      expect(scorer.score(fresh), greaterThan(scorer.score(old)));
    });

    test('access count boosts score', () {
      final noAccess = _fragment(age: const Duration(days: 1));
      final heavyAccess = _fragment(
        age: const Duration(days: 1),
        accessCount: 50,
      );
      expect(scorer.score(heavyAccess), greaterThan(scorer.score(noAccess)));
    });

    test('pinned fragments are never eligible for transition', () {
      final pinned = _fragment(
        tier: MemoryTier.short,
        age: const Duration(days: 30),
        isPinned: true,
      );
      final scored = scorer.scoreWithBreakdown(pinned);
      expect(
        scorer.isEligibleForTransition(scored),
        isFalse,
        reason: 'pinned fragments should be exempt from forgetting',
      );
    });

    test('unpinned old short-tier low-score fragment is eligible', () {
      final f = _fragment(
        tier: MemoryTier.short,
        age: const Duration(days: 14),
        importance: 0.0,
        accessCount: 0,
        content: 'boring trivia',
      );
      final scored = scorer.scoreWithBreakdown(f);
      expect(
        scorer.isEligibleForTransition(scored),
        isTrue,
        reason:
            'a 14-day-old, never-accessed, low-importance fragment should be forgotten',
      );
    });

    test('importance keywords are detected from text', () {
      final important = _fragment(
        content: 'critical: deadline tomorrow, urgent action item',
      );
      final boring = _fragment(content: 'hello there');
      final imp = scorer.scoreWithBreakdown(important);
      final bor = scorer.scoreWithBreakdown(boring);
      expect(imp.importanceScore, greaterThan(bor.importanceScore));
    });

    test('breakdown is internally consistent', () {
      final f = _fragment(
        age: const Duration(days: 30),
        accessCount: 5,
        importance: 0.3,
        mediaRefs: const ['img1'],
      );
      final breakdown = scorer.scoreWithBreakdown(f);
      // The combined score should sit between 0 and 1 inclusive.
      expect(breakdown.valueScore, inInclusiveRange(0.0, 1.0));
      // Components should also be in [0, 1].
      for (final s in [
        breakdown.recencyScore,
        breakdown.accessScore,
        breakdown.importanceScore,
        breakdown.mediaScore,
      ]) {
        expect(s, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('MemoryScorer — dual time signal', () {
    test('recent access lifts score even when fragment is long-standing', () {
      // 100-day-old fragment, no importance/access, no media.
      // Without the access signal it would decay to ~0.45.
      final old = _fragment(age: const Duration(days: 100));
      // Same fragment but accessed yesterday.
      final oldButRecentAccess = _fragment(
        age: const Duration(days: 100),
        lastAccessAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      const scorer = MemoryScorer();
      expect(
        scorer.score(oldButRecentAccess),
        greaterThan(scorer.score(old)),
        reason: 'recent access should lift the value score',
      );
    });

    test('never-accessed fragment behaves like the old algorithm', () {
      const scorer = MemoryScorer();
      final neverAccessed = _fragment(age: const Duration(days: 60));
      final breakdown = scorer.scoreWithBreakdown(neverAccessed);
      // Without lastAccessAt the effective recency equals the
      // created recency. Use a reasonable lower bound: 60/180 = 0.667
      // (linear decay); the breakdown should match that within rounding.
      const tolerance = 0.02;
      expect(
        breakdown.recencyScore,
        closeTo(1.0 - 60 / 180, tolerance),
        reason: 'no lastAccessAt → recency equals created decay',
      );
    });

    test('useLastAccessForRecency=false reverts to created-only scoring', () {
      final withAccess = _fragment(
        age: const Duration(days: 100),
        lastAccessAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final noAccess = _fragment(age: const Duration(days: 100));
      // With the flag on (default), the access signal should dominate
      // and lift the recency score.
      const scorerOn = MemoryScorer();
      // With the flag off, both fragments should score identically.
      const scorerOff = MemoryScorer(useLastAccessForRecency: false);
      expect(
        scorerOn.scoreWithBreakdown(withAccess).recencyScore,
        greaterThan(0.5),
        reason:
            'with the access signal on, recent access should keep '
            'recency high',
      );
      expect(
        scorerOff.scoreWithBreakdown(withAccess).recencyScore,
        lessThan(0.5),
        reason:
            'disabling useLastAccess should drop recency to '
            'the created-decay level',
      );
      expect(
        scorerOff.score(withAccess),
        closeTo(scorerOff.score(noAccess), 0.001),
        reason:
            'with the signal disabled, the two fragments should '
            'score identically',
      );
    });

    test('different half-lives produce different recency curves', () {
      // 15-day-old access with a 30-day half-life → ~0.5
      final accessed15d = _fragment(
        age: const Duration(days: 60),
        lastAccessAt: DateTime.now().subtract(const Duration(days: 15)),
      );
      // Using a longer half-life keeps the access signal stronger.
      const shortHL = MemoryScorer(
        createdRecencyHalfLife: Duration(days: 180),
        accessRecencyHalfLife: Duration(days: 30),
      );
      const longHL = MemoryScorer(
        createdRecencyHalfLife: Duration(days: 180),
        accessRecencyHalfLife: Duration(days: 90),
      );
      expect(
        longHL.scoreWithBreakdown(accessed15d).recencyScore,
        greaterThan(shortHL.scoreWithBreakdown(accessed15d).recencyScore),
        reason: 'a longer access half-life preserves recency more',
      );
    });

    test('effectiveAge = min(age_from_created, age_from_lastAccess)', () {
      const scorer = MemoryScorer();
      final now = DateTime.now();
      final f = _fragment(
        createdAt: now.subtract(const Duration(days: 90)),
        lastAccessAt: now.subtract(const Duration(days: 1)),
      );
      final age = scorer.effectiveAge(f, now: now);
      expect(age, const Duration(days: 1));
    });

    test('effectiveAge = createdAt age when lastAccessAt is null', () {
      const scorer = MemoryScorer();
      final now = DateTime.now();
      final f = _fragment(createdAt: now.subtract(const Duration(days: 42)));
      final age = scorer.effectiveAge(f, now: now);
      expect(age, const Duration(days: 42));
    });

    test('archived fragments are never eligible for transition', () {
      const scorer = MemoryScorer();
      // 60 days old, low score, with archivedAt set.
      final archived = _fragment(
        tier: MemoryTier.mid,
        age: const Duration(days: 60),
        archivedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final scored = scorer.scoreWithBreakdown(archived);
      expect(scorer.isEligibleForTransition(scored), isFalse);
    });

    test('recently accessed short-tier fragment skips grace period', () {
      const scorer = MemoryScorer();
      // Fragment created 30 days ago, accessed 1 day ago.
      // Without the effectiveAge fix, age=30d would be past the
      // 7-day short-tier grace period and the fragment would be
      // eligible for transition. With the fix, effectiveAge=1d so
      // it should NOT be eligible.
      final frag = _fragment(
        tier: MemoryTier.short,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastAccessAt: DateTime.now().subtract(const Duration(days: 1)),
        content: 'boring trivia',
      );
      final scored = scorer.scoreWithBreakdown(frag);
      expect(scorer.isEligibleForTransition(scored), isFalse);
    });
  });

  group('MemorySummaryLexicon', () {
    const lex = MemorySummaryLexicon();

    test('extracts top keywords while dropping stop words', () {
      final texts = [
        'The meeting about the project deadline is critical.',
        'Decision: meeting tomorrow, urgent follow up.',
        'Project meeting recap and follow up items.',
      ];
      final kws = lex.topKeywords(texts, maxCount: 5);
      // Stop words ("the", "and") should not appear.
      expect(kws, isNot(contains('the')));
      expect(kws, isNot(contains('and')));
      // Frequent content words should be near the top.
      expect(kws.first, anyOf('meeting', 'project', 'follow'));
    });

    test('respects maxCount', () {
      final kws = lex.topKeywords(List.generate(20, (i) => 'w$i'), maxCount: 3);
      expect(kws.length, lessThanOrEqualTo(3));
    });

    test('CJK unigrams are preserved as tokens', () {
      final toks = lex.tokenize('项目 会议 重要');
      expect(toks, contains('项目'));
      expect(toks, contains('会议'));
    });
  });
}

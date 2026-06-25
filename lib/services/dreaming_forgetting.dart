part of 'dreaming_service.dart';

/// Progressive-forgetting engine. Scores active fragments per tier,
/// groups the ones that have decayed below the transition threshold,
/// builds L1/L2 summaries, and applies the tier transition + archive
/// side effects.
mixin _DreamingForgettingMixin on _DreamingServiceBase {
  /// Score all active fragments in a tier, mark the ones that fall below the
  /// transition threshold, group them, build summaries, and apply the
  /// transition + archive side effects.
  Future<_ForgettingRunResult> _runForgettingCycle() async {
    final now = DateTime.now();
    var scanned = 0;
    var eligible = 0;
    var createdSummaries = 0;
    var transitioned = 0;
    var archived = 0;

    final phases = <_ForgettingPhase>[
      _ForgettingPhase(
        fromTier: MemoryTier.short,
        olderThan: now.subtract(_scorer.policy.shortMaxAge),
        threshold: _scorer.policy.shortToMidThreshold,
        windowMs: const Duration(days: 1).inMilliseconds,
      ),
      _ForgettingPhase(
        fromTier: MemoryTier.mid,
        olderThan: now.subtract(_scorer.policy.midMaxAge),
        threshold: _scorer.policy.midToLongThreshold,
        windowMs: const Duration(days: 7).inMilliseconds,
      ),
    ];

    for (final phase in phases) {
      final candidates = await _memory.getFragmentsInTier(
        phase.fromTier,
        limit: _scorer.policy.maxCandidatesPerCycle,
      );
      scanned += candidates.length;

      final scored = candidates
          .map((c) => _scorer.scoreWithBreakdown(c, now: now))
          .toList();

      final eligibleNow = scored
          .where((s) => _scorer.isEligibleForTransition(s, now: now))
          .toList();
      eligible += eligibleNow.length;

      if (eligibleNow.isEmpty) continue;

      final groups = _groupEligible(
        userId: _memory.currentSessionId,
        records: eligibleNow,
        fromTier: phase.fromTier,
        windowMs: phase.windowMs,
        now: now,
      );

      for (final group in groups) {
        final summary = _summarizer.buildSummary(group, now: now);
        await _memory.saveSummary(summary);
        createdSummaries += 1;
        transitioned += group.records.length;

        final shouldArchive = group.targetTier == MemoryTier.long;
        for (final r in group.records) {
          await _memory.transitionFragmentTier(
            r.fragment.id,
            newTier: group.targetTier,
            transitionedAt: now,
            summaryId: summary.summaryId,
            archive: shouldArchive,
          );
        }
        if (shouldArchive) archived += group.records.length;
      }
    }

    return _ForgettingRunResult(
      scannedRecords: scanned,
      eligibleRecords: eligible,
      createdSummaries: createdSummaries,
      transitionedRecords: transitioned,
      archivedDetailRecords: archived,
    );
  }

  /// Group eligible fragments by tier + time window. OpenLoomi's
  /// `groupRecordsForTransition` is the template.
  List<MemoryGroup> _groupEligible({
    required String userId,
    required List<ScoredMemoryFragment> records,
    required MemoryTier fromTier,
    required int windowMs,
    required DateTime now,
  }) {
    final groups = <String, List<ScoredMemoryFragment>>{};
    for (final r in records) {
      final bucket = bucketStart(
        r.fragment.createdAt,
        Duration(milliseconds: windowMs),
      );
      final key = '${fromTier.name}|${bucket.millisecondsSinceEpoch}';
      (groups[key] ??= <ScoredMemoryFragment>[]).add(r);
    }
    final result = <MemoryGroup>[];
    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      entry.value.sort(
        (a, b) => a.fragment.createdAt.compareTo(b.fragment.createdAt),
      );
      final start = entry.value.first.fragment.createdAt;
      final end = entry.value.last.fragment.createdAt;
      result.add(
        MemoryGroup(
          groupId: entry.key,
          userId: userId,
          sourceTier: fromTier,
          targetTier: transitionTargetTier(fromTier),
          summaryTier: summaryTierForTransition(fromTier),
          records: entry.value,
          startTimestamp: start,
          endTimestamp: end,
        ),
      );
    }
    // Newest windows first so the more relevant summaries win.
    result.sort((a, b) => b.endTimestamp.compareTo(a.endTimestamp));
    return result;
  }
}

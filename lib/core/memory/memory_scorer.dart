import 'dart:math';
import '../../data/models/chat_memory.dart';

/// Default weights for the progressive-forgetting scorer.
///
/// The combined value score is a weighted sum of:
///   - recency   (0.35)  — newer fragments score higher
///   - access    (0.30)  — frequently surfaced fragments stick
///   - importance(0.25)  — explicit + keyword-inferred importance
///   - media     (0.10)  — fragments with attachments are slightly preferred
///   - pinned    (boost) — +0.30 to keep explicit pins out of mid/long
class MemoryScoringWeights {
  final double recency;
  final double access;
  final double importance;
  final double media;
  final double pinnedBoost;

  const MemoryScoringWeights({
    this.recency = 0.35,
    this.access = 0.30,
    this.importance = 0.25,
    this.media = 0.10,
    this.pinnedBoost = 0.30,
  });
}

/// Thresholds for tier transitions.
///
/// `valueScore` is in [0, 1]. Lower scores are easier to forget.
class MemoryForgettingPolicy {
  final MemoryScoringWeights weights;
  final double shortToMidThreshold;
  final double midToLongThreshold;

  /// How old a short-tier fragment must be (in milliseconds) before it is
  /// even considered for transition to mid. Recent fragments get a grace
  /// period regardless of score.
  final Duration shortMaxAge;

  /// How old a mid-tier fragment must be before it can move to long.
  final Duration midMaxAge;

  /// Maximum number of fragments considered per tier in a single cycle.
  final int maxCandidatesPerCycle;

  const MemoryForgettingPolicy({
    this.weights = const MemoryScoringWeights(),
    this.shortToMidThreshold = 0.65,
    this.midToLongThreshold = 0.45,
    this.shortMaxAge = const Duration(days: 7),
    this.midMaxAge = const Duration(days: 30),
    this.maxCandidatesPerCycle = 500,
  });

  /// OpenLoomi-aligned default policy. Same numbers as
  /// `DEFAULT_MEMORY_FORGETTING_POLICY` in `policy.ts`.
  static const MemoryForgettingPolicy defaultPolicy = MemoryForgettingPolicy();
}

/// A scored memory record: a fragment plus the derived metadata used by the
/// forgetting engine to decide whether to transition / archive it.
class ScoredMemoryFragment {
  final MemoryFragment fragment;
  final double valueScore;
  final double recencyScore;
  final double accessScore;
  final double importanceScore;
  final double mediaScore;

  ScoredMemoryFragment({
    required this.fragment,
    required this.valueScore,
    required this.recencyScore,
    required this.accessScore,
    required this.importanceScore,
    required this.mediaScore,
  });
}

/// Default importance keyword set. Mirrors `IMPORTANCE_KEYWORDS` in
/// `scorer.ts`. These are matched case-insensitively against the fragment
/// text. Hits are capped at 4 so a single fragment with many keywords does
/// not dominate the score.
const Set<String> defaultImportanceKeywords = {
  'deadline',
  'todo',
  'urgent',
  'risk',
  'decision',
  'blocker',
  'meeting',
  'action item',
  'milestone',
  'bug',
  'incident',
  'follow up',
};

/// Default stop words for keyword extraction in summaries. Mirrors
/// `STOP_WORDS` in `summarizer.ts`.
const Set<String> defaultSummaryStopWords = {
  // English
  'the', 'and', 'for', 'with', 'that', 'this', 'from', 'have', 'has',
  'was', 'were', 'you', 'your', 'our', 'are', 'not', 'but', 'about',
  'into', 'then', 'than', 'when', 'where', 'what', 'which', 'would',
  'could', 'should', 'will', 'can', 'just', 'been', 'also',
};

/// Default CJK character pattern for keyword extraction. Same range as in
/// the existing CJK tokenizer in `index_store.dart`.
final RegExp cjkCharPattern = RegExp(
  r'[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]',
);

/// Default tokenization regex for keyword extraction. Splits on anything
/// that isn't a letter, digit, underscore, hyphen, or CJK character.
final RegExp wordSplitter = RegExp(r'[^a-zA-Z0-9_\-\u4e00-\u9fff]+');

/// Computes a 0..1 value score for a memory fragment, based on recency,
/// access frequency, importance (explicit + keyword-inferred), media
/// presence, and a pinned boost.
///
/// Higher score = stronger retention priority. The forgetting engine
/// transitions fragments whose score drops below the configured threshold.
///
/// The recency signal uses two timestamps in parallel:
///   - [createdAt]     : when the fact was extracted from a conversation
///   - [lastAccessAt]  : when the user most recently saw it via search
/// The combined "effective recency" is the max of the two individually
/// decayed scores. This means a fact that the user keeps referring to
/// in searches is preserved even if it was extracted long ago; conversely
/// an extracted-but-never-accessed fact decays as before.
class MemoryScorer {
  final MemoryForgettingPolicy policy;
  final Set<String> importanceKeywords;

  /// Half-life of the [MemoryFragment.createdAt] signal. Longer =
  /// knowledge stays "fresh" for longer. Default 180 days.
  final Duration createdRecencyHalfLife;

  /// Half-life of the [MemoryFragment.lastAccessAt] signal. Should be
  /// shorter than [createdRecencyHalfLife] so "actively used" is a
  /// sharper signal. Default 30 days.
  final Duration accessRecencyHalfLife;

  /// Master switch: when `false` the scorer falls back to the
  /// [createdRecencyHalfLife]-only behavior, ignoring `lastAccessAt`.
  final bool useLastAccessForRecency;

  const MemoryScorer({
    this.policy = MemoryForgettingPolicy.defaultPolicy,
    this.importanceKeywords = defaultImportanceKeywords,
    this.createdRecencyHalfLife = const Duration(days: 180),
    this.accessRecencyHalfLife = const Duration(days: 30),
    this.useLastAccessForRecency = true,
  });

  /// Compute the 0..1 value score for a fragment at the given moment.
  double score(MemoryFragment fragment, {DateTime? now}) {
    final scored = scoreWithBreakdown(fragment, now: now);
    return scored.valueScore;
  }

  /// Like [score] but exposes the component values, useful for debugging
  /// and for the consolidation engine's decision-making.
  ScoredMemoryFragment scoreWithBreakdown(
    MemoryFragment fragment, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();

    final createdRecency = _createdRecencyScore(fragment.createdAt, n);
    final accessRecency = _accessRecencyScore(fragment.lastAccessAt, n);
    final recency = useLastAccessForRecency
        ? max(createdRecency, accessRecency)
        : createdRecency;

    final access = _accessScore(fragment.accessCount);
    final importance = _importanceScore(fragment);
    final media = _mediaScore(fragment);
    final pinnedBonus = fragment.isPinned ? policy.weights.pinnedBoost : 0.0;

    final w = policy.weights;
    final combined =
        (w.recency * recency +
                w.access * access +
                w.importance * importance +
                w.media * media +
                pinnedBonus)
            .clamp(0.0, 1.0)
            .toDouble();

    return ScoredMemoryFragment(
      fragment: fragment,
      valueScore: combined,
      recencyScore: recency,
      accessScore: access,
      importanceScore: importance,
      mediaScore: media,
    );
  }

  /// Whether the fragment is eligible to transition from its current tier.
  /// Pinned fragments and already-archived fragments are exempt.
  ///
  /// The "grace period" before transition is gated on [effectiveAge] —
  /// the smaller of (age from [createdAt], age from [lastAccessAt]).
  /// A fragment that the user keeps seeing won't hit the grace period
  /// even if it was extracted long ago.
  bool isEligibleForTransition(ScoredMemoryFragment scored, {DateTime? now}) {
    final f = scored.fragment;
    if (f.isPinned) return false;
    if (f.archivedAt != null) return false;
    final n = now ?? DateTime.now();
    final age = effectiveAge(f, now: n);

    switch (f.tier) {
      case MemoryTier.short:
        if (age < policy.shortMaxAge) return false;
        return scored.valueScore <= policy.shortToMidThreshold;
      case MemoryTier.mid:
        if (age < policy.midMaxAge) return false;
        return scored.valueScore <= policy.midToLongThreshold;
      case MemoryTier.long:
        return false;
    }
  }

  /// The "effective age" of a fragment: the time since the more recent
  /// of (created, last accessed). Bounded below by 0.
  Duration effectiveAge(MemoryFragment fragment, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final createdAge = n.difference(fragment.createdAt);
    if (fragment.lastAccessAt == null) return createdAge;
    final accessAge = n.difference(fragment.lastAccessAt!);
    return createdAge < accessAge ? createdAge : accessAge;
  }

  // ── Component scores ─────────────────────────────────────────────

  /// Linear decay from [createdAt] using the created half-life.
  double _createdRecencyScore(DateTime created, DateTime now) {
    return _decay(now.difference(created), createdRecencyHalfLife);
  }

  /// Linear decay from [lastAccessAt] (or 0 when never accessed) using
  /// the access half-life. A null `lastAccessAt` means "never used",
  /// so we return 0 to avoid spuriously keeping untouched fragments
  /// alive (the [useLastAccessForRecency] flag then makes the overall
  /// recency equal to the created score alone).
  double _accessRecencyScore(DateTime? lastAccess, DateTime now) {
    if (lastAccess == null) return 0.0;
    return _decay(now.difference(lastAccess), accessRecencyHalfLife);
  }

  /// Generic linear-decay helper: 1.0 at age 0, 0.0 at age >= halfLife.
  double _decay(Duration age, Duration halfLife) {
    final ms = age.inMilliseconds;
    if (ms <= 0) return 1.0;
    final ratio = ms / halfLife.inMilliseconds;
    return (1.0 - ratio).clamp(0.0, 1.0).toDouble();
  }

  double _accessScore(int accessCount) {
    if (accessCount <= 0) return 0.0;
    // log(1 + n) / log(10)  — same curve as the OpenLoomi scorer.
    return (log(accessCount + 1) / log(10)).clamp(0.0, 1.0).toDouble();
  }

  double _importanceScore(MemoryFragment fragment) {
    final provided = fragment.importanceScore;
    final inferred = _inferImportanceFromText(fragment.content);
    return max(provided, inferred).clamp(0.0, 1.0).toDouble();
  }

  double _inferImportanceFromText(String? text) {
    if (text == null || text.trim().isEmpty) return 0.0;
    final lower = text.toLowerCase();
    final hits = importanceKeywords.where(lower.contains).length;
    // Cap noise at 4 hits.
    return (hits / 4).clamp(0.0, 1.0).toDouble();
  }

  double _mediaScore(MemoryFragment fragment) {
    return fragment.mediaRefs.isNotEmpty ? 0.7 : 0.25;
  }
}

/// Pure helpers for the rule-based summary builder (see
/// [L1SummaryBuilder] in `memory_summarizer.dart`).
class MemorySummaryLexicon {
  final Set<String> stopWords;

  const MemorySummaryLexicon({this.stopWords = defaultSummaryStopWords});

  /// Tokenize a chunk of text into lowercase word tokens, preserving
  /// CJK characters as unigrams and skipping stop words.
  List<String> tokenize(String text) {
    if (text.isEmpty) return const [];
    final lower = text.toLowerCase();
    return lower
        .split(wordSplitter)
        .map((w) => w.trim())
        .where((w) => _isValidToken(w) && !stopWords.contains(w))
        .toList(growable: false);
  }

  /// CJK unigrams (e.g. "项目", "会议") are valid tokens even when their
  /// character count is < 3. Latin words must still be at least 3 chars.
  static bool _isValidToken(String w) {
    if (w.isEmpty) return false;
    if (w.runes.length >= 3) return true;
    // Accept any CJK unigram of 1+ characters.
    return cjkCharPattern.hasMatch(w);
  }

  /// Top-N keywords by frequency across the given texts.
  List<String> topKeywords(Iterable<String> texts, {int maxCount = 12}) {
    final scores = <String, int>{};
    for (final t in texts) {
      for (final w in tokenize(t)) {
        scores[w] = (scores[w] ?? 0) + 1;
      }
    }
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(maxCount).map((e) => e.key).toList(growable: false);
  }
}

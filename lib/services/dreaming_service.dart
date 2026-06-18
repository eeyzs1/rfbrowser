import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/ai_provider.dart';
import '../data/models/chat_memory.dart';
import '../core/memory/memory_scorer.dart';
import '../core/memory/memory_summarizer.dart';
import '../core/memory/summary_rollup.dart';
import 'chat_history_exporter.dart';
import 'memory_service.dart';
import 'dio_factory.dart';
import 'settings_service.dart';
import 'hebbian_service.dart';

const _uuid = Uuid();

/// Background service that consolidates raw chat messages into memory
/// fragments and runs the progressive-forgetting engine.
///
/// Pipeline (run during each consolidation):
///   1. Materialize the current message window into candidate fragments.
///   2. Score every active fragment with [MemoryScorer].
///   3. For fragments whose score has dropped below the policy threshold:
///      - group them by tier + time window + dimension
///      - call [MemorySummarizer] to build an L1/L2 summary
///      - transition the source fragments' tier
///      - archive the raw body when moving short → mid if the summary is good
///
/// The trigger condition is unchanged from the original implementation:
///   - N new messages accumulate since last consolidation (default: 8)
///   - App idle timer fires (default: 30s after last message)
class DreamingService {
  final MemoryService _memory;
  final MemoryScorer _scorer;
  final MemorySummarizer _summarizer;
  final SummaryRollup _rollup;
  final HebbianService? _hebbian;
  final ChatHistoryExporter? _exporter;
  final Dio _dio = DioFactory.instance;
  int _lastConsolidatedCount = 0;
  Timer? _idleTimer;
  bool _isConsolidating = false;
  int _lastExportedMessageCount = 0;
  // ── Last-run status snapshot. Updated by [_consolidate] and read by
  //    the `dreamingStatusProvider` so the UI can show "last dream
  //    was N minutes ago, extracted K fragments".
  DateTime? _lastConsolidationAt;
  int _lastNewFragments = 0;
  int _lastSummariesCreated = 0;
  int _lastRecordsTransitioned = 0;
  int _lastStaleEdgesPruned = 0;
  DateTime? _lastExportAt;
  String? _lastExportPath;
  int _lastL2Rollups = 0;
  int _lastL3Rollups = 0;
  int _lastCrossSessionEdges = 0;

  // ── Public accessors for the status provider ──────────────────────
  DateTime? get lastConsolidationAt => _lastConsolidationAt;
  int get lastNewFragments => _lastNewFragments;
  int get lastSummariesCreated => _lastSummariesCreated;
  int get lastRecordsTransitioned => _lastRecordsTransitioned;
  int get lastStaleEdgesPruned => _lastStaleEdgesPruned;
  DateTime? get lastExportAt => _lastExportAt;
  String? get lastExportPath => _lastExportPath;
  bool get isConsolidating => _isConsolidating;
  int get lastL2Rollups => _lastL2Rollups;
  int get lastL3Rollups => _lastL3Rollups;
  int get lastCrossSessionEdges => _lastCrossSessionEdges;

  /// Threshold: trigger consolidation after this many new messages.
  static const int messageThreshold = 8;

  /// Idle time before triggering consolidation (when app is quiet).
  static const Duration idleDuration = Duration(seconds: 30);

  /// After this many new messages since the last Markdown export, the
  /// dreaming service will write a fresh `.rfbrowser/chats/...md` file.
  /// 0 disables auto-export; callers can also use
  /// [ChatHistoryExporter.exportSession] directly.
  static const int exportEveryNMessages = 16;

  DreamingService(
    this._memory, {
    MemoryScorer? scorer,
    MemorySummarizer? summarizer,
    SummaryRollup? rollup,
    HebbianService? hebbian,
    ChatHistoryExporter? exporter,
  }) : _scorer = scorer ?? const MemoryScorer(),
       _summarizer = summarizer ?? const RuleBasedMemorySummarizer(),
       _rollup = rollup ?? SummaryRollup(_memory),
       _hebbian = hebbian,
       _exporter = exporter;

  // ─── Public API ────────────────────────────────────────────────────

  /// Call after each message persistence. Checks threshold and idle timer.
  /// Becomes a no-op when the user has disabled dreaming in settings.
  void onMessageSaved() {
    if (_dreamingEnabled == false) return;
    _resetIdleTimer();
    _checkThreshold();
  }

  /// Call when the user is done chatting (panel collapses, etc.).
  void onUserInactive() {
    if (_dreamingEnabled == false) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDuration, _consolidateIfNeeded);
  }

  /// Force immediate consolidation (for testing or manual trigger).
  Future<void> consolidateNow() async {
    _idleTimer?.cancel();
    await _consolidate();
  }

  /// Clean up timers.
  void dispose() {
    _idleTimer?.cancel();
  }

  /// Whether dreaming is currently enabled. Public for diagnostics.
  bool get isDreamingEnabled => _dreamingEnabled ?? true;

  // ─── Internal triggers ─────────────────────────────────────────────

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDuration, _consolidateIfNeeded);
  }

  void _checkThreshold() {
    // Schedule a microtask to get accurate count after DB write
    Future.microtask(() async {
      try {
        final count = await _memory.getUnconsolidatedCount();
        if (count - _lastConsolidatedCount >= messageThreshold) {
          await _consolidate();
        }
      } catch (e) {
        debugPrint('DreamingService threshold check error: $e');
      }
    });
  }

  Future<void> _consolidateIfNeeded() async {
    try {
      final count = await _memory.getUnconsolidatedCount();
      if (count > _lastConsolidatedCount) {
        await _consolidate();
      }
    } catch (e) {
      debugPrint('DreamingService idle consolidate error: $e');
    }
  }

  // ─── Core consolidation ────────────────────────────────────────────

  Future<void> _consolidate() async {
    if (_isConsolidating) return;
    _isConsolidating = true;

    // Process-wide single-flight lock (defense in depth — also checked in
    // ai_service / callers). Released in `finally`.
    final lock = await _memory.tryAcquireConsolidationLock();
    if (lock == null) {
      _isConsolidating = false;
      return;
    }

    try {
      final messages = await _memory.getRecentMessages(limit: 30);
      if (messages.isEmpty) {
        _lastConsolidatedCount = 0;
        return;
      }

      // 1. Extract fragments from messages (LLM-assisted, with rule-based
      //    fallback to ensure the system never blocks on a missing provider).
      final existingFragments = await _memory.getAllActiveFragments();
      final extractResult = await _extractFragments(
        messages,
        existingFragments,
      );
      if (extractResult == null) return;

      await _applyExtractionResult(extractResult);

      // 2. Run the forgetting engine over the now-updated fragment set.
      final forgettingStats = await _runForgettingCycle();
      if (forgettingStats.transitionedRecords > 0 ||
          forgettingStats.createdSummaries > 0) {
        debugPrint(
          'DreamingService forgetting: '
          '${forgettingStats.createdSummaries} summaries, '
          '${forgettingStats.transitionedRecords} records transitioned, '
          '${forgettingStats.archivedDetailRecords} details archived',
        );
      }

      // 2.5. Reap Hebbian edges that have decayed and never been
      //      reinforced — keeps the edge table from growing forever.
      final staleEdges = await _memory.deleteStaleHebbianEdges();
      _lastStaleEdgesPruned = staleEdges;
      if (staleEdges > 0) {
        debugPrint('DreamingService: pruned $staleEdges stale Hebbian edges');
      }

      _lastConsolidatedCount = await _memory.getUnconsolidatedCount();
      // Capture last-run status for the dreamingStatusProvider.
      _lastConsolidationAt = DateTime.now();
      _lastNewFragments = extractResult.newFragments.length;
      _lastSummariesCreated = forgettingStats.createdSummaries;
      _lastRecordsTransitioned = forgettingStats.transitionedRecords;
      debugPrint(
        'DreamingService: extracted ${extractResult.newFragments.length} new, '
        '${extractResult.supersededIds.length} superseded, '
        '${extractResult.updatedFragments.length} updated',
      );

      // 3. L2/L3 rollup: take the L1 / L2 summaries that have aged out
      //    of their window and roll them up. This is the "weekly" /
      //    "monthly" compression that makes the tier pyramid real.
      final rollup = await _rollup.runDaily();
      _lastL2Rollups = rollup.l2Created;
      _lastL3Rollups = rollup.l3Created;
      if (rollup.l2Created > 0 || rollup.l3Created > 0) {
        debugPrint(
          'DreamingService: rollup created ${rollup.l2Created} L2 + '
          '${rollup.l3Created} L3 summaries',
        );
      }

      // 3.5. Cross-session association: link fragments that share
      //      keywords across sessions. Soft (delta × 0.25) so the
      //      edges are reinforced gradually as patterns repeat.
      if (_hebbian != null) {
        _lastCrossSessionEdges = await _hebbian.runCrossSessionAssociation();
        if (_lastCrossSessionEdges > 0) {
          debugPrint(
            'DreamingService: cross-session added '
            '$_lastCrossSessionEdges edges',
          );
        }
      }

      // 4. Auto-export the session as Markdown if enough new messages have
      //    accumulated. Failures are logged but never block the cycle.
      await _maybeAutoExport();
    } catch (e) {
      debugPrint('DreamingService consolidation error: $e');
    } finally {
      _memory.releaseConsolidationLock(lock);
      _isConsolidating = false;
    }
  }

  Future<void> _maybeAutoExport() async {
    final exporter = _exporter;
    if (exporter == null) return;
    if (exportEveryNMessages <= 0) return;
    final total = _lastConsolidatedCount;
    if (total - _lastExportedMessageCount < exportEveryNMessages) return;
    try {
      final path = await exporter.exportSession();
      if (path != null) {
        _lastExportedMessageCount = total;
        _lastExportAt = DateTime.now();
        _lastExportPath = path;
        debugPrint('DreamingService: exported chat to $path');
      }
    } catch (e) {
      debugPrint('DreamingService auto-export error: $e');
    }
  }

  /// Force an export of the current session. Public hook for the settings
  /// UI "Export chat" button.
  Future<String?> exportCurrentSession() async {
    final exporter = _exporter;
    if (exporter == null) {
      debugPrint('DreamingService.exportCurrentSession: no exporter wired');
      return null;
    }
    final path = await exporter.exportSession();
    if (path != null) {
      _lastExportedMessageCount = _lastConsolidatedCount;
      _lastExportAt = DateTime.now();
      _lastExportPath = path;
    }
    return path;
  }

  // ─── LLM extraction (preserves the original behaviour) ────────────

  Future<_ExtractionResult?> _extractFragments(
    List<ChatRecord> messages,
    List<MemoryFragment> existingFragments,
  ) async {
    final provider = _provider;
    final model = _model;
    if (provider == null || model == null) {
      // Without a provider we can't extract facts. Run the forgetting
      // engine anyway so the user still gets tier migration.
      return _ExtractionResult(
        newFragments: const [],
        supersededIds: const [],
        updatedFragments: const [],
      );
    }

    final prompt = _buildExtractionPrompt(messages, existingFragments);
    try {
      final response = await _dio.post(
        provider.chatEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ...provider.authHeaders(),
          },
        ),
        data: jsonEncode({
          'model': model.id,
          'messages': [
            {'role': 'system', 'content': _extractionSystemPrompt},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 1024,
        }),
      );
      final content = _extractContent(response.data, provider.protocol);
      if (content == null) {
        debugPrint('DreamingService: empty extraction response from LLM');
        return null;
      }
      return _parseExtractionResponse(content);
    } on DioException catch (e) {
      debugPrint('DreamingService LLM error: ${e.message}');
      return null;
    }
  }

  String _buildExtractionPrompt(
    List<ChatRecord> messages,
    List<MemoryFragment> existingFragments,
  ) {
    final recent = messages.map((m) => '${m.role}: ${m.content}').join('\n');
    final existing = existingFragments.isNotEmpty
        ? '\nExisting memories about the user:\n${existingFragments.map((f) => '- [${f.category}] ${f.content} (id: ${f.id})').join('\n')}'
        : '\nNo existing memories.';
    return '''
Recent conversation:
$recent

$existing

Extract new facts about the user from the recent conversation. Output JSON only, no explanation.
''';
  }

  _ExtractionResult? _parseExtractionResponse(String content) {
    try {
      var jsonStr = content.trim();
      if (jsonStr.startsWith('```')) {
        final start = jsonStr.indexOf('\n');
        final end = jsonStr.lastIndexOf('```');
        if (start > 0 && end > start) {
          jsonStr = jsonStr.substring(start, end).trim();
        }
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final newFragments = <_FragmentData>[];
      final fragments = json['new_fragments'] as List<dynamic>? ?? [];
      for (final f in fragments) {
        final fMap = f as Map<String, dynamic>;
        newFragments.add(
          _FragmentData(
            content: fMap['content'] as String? ?? '',
            category: fMap['category'] as String? ?? 'fact',
            importance: (fMap['importance'] as num?)?.toDouble() ?? 0.0,
            mediaRefs: _stringList(fMap['media_refs']),
          ),
        );
      }

      final superseded = <String>[];
      final supersededList = json['superseded_ids'] as List<dynamic>? ?? [];
      for (final s in supersededList) {
        superseded.add(s.toString());
      }

      final updated = <_FragmentData>[];
      final updatedList = json['updated_fragments'] as List<dynamic>? ?? [];
      for (final u in updatedList) {
        final uMap = u as Map<String, dynamic>;
        updated.add(
          _FragmentData(
            content: uMap['content'] as String? ?? '',
            category: uMap['category'] as String? ?? 'fact',
            importance: (uMap['importance'] as num?)?.toDouble() ?? 0.0,
            mediaRefs: _stringList(uMap['media_refs']),
            supersedesId: uMap['supersedes_id'] as String?,
          ),
        );
      }

      return _ExtractionResult(
        newFragments: newFragments,
        supersededIds: superseded,
        updatedFragments: updated,
      );
    } catch (e) {
      debugPrint('DreamingService parse error: $e\nContent: $content');
      return null;
    }
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _applyExtractionResult(_ExtractionResult result) async {
    final now = DateTime.now();

    for (final id in result.supersededIds) {
      await _memory.deactivateFragment(id);
    }
    for (final u in result.updatedFragments) {
      if (u.supersedesId != null) {
        await _memory.deactivateFragment(u.supersedesId!);
      }
      final fragment = MemoryFragment(
        id: _uuid.v4(),
        sessionId: _memory.currentSessionId,
        content: u.content,
        category: u.category,
        isActive: true,
        tier: MemoryTier.short,
        importanceScore: u.importance,
        mediaRefs: u.mediaRefs,
        createdAt: now,
        updatedAt: now,
      );
      await _memory.upsertFragment(fragment);
    }
    for (final n in result.newFragments) {
      if (n.content.isEmpty) continue;
      final fragment = MemoryFragment(
        id: _uuid.v4(),
        sessionId: _memory.currentSessionId,
        content: n.content,
        category: n.category,
        isActive: true,
        tier: MemoryTier.short,
        importanceScore: n.importance,
        mediaRefs: n.mediaRefs,
        createdAt: now,
        updatedAt: now,
      );
      await _memory.upsertFragment(fragment);
    }
  }

  // ─── Progressive-forgetting engine ────────────────────────────────

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

  // ─── Response parsing helpers ──────────────────────────────────────

  String? _extractContent(dynamic data, ApiProtocol protocol) {
    try {
      switch (protocol) {
        case ApiProtocol.openaiCompatible:
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            return choices[0]['message']?['content'] as String?;
          }
          return null;
        case ApiProtocol.anthropic:
          final content = data['content'] as List<dynamic>?;
          if (content != null && content.isNotEmpty) {
            return content[0]?['text'] as String?;
          }
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  // Will be set by the Provider to give access to AI config.
  AIProvider? _provider;
  AIModel? _model;

  /// Whether the user has enabled background dreaming in settings.
  /// `null` means "default on" so the service is permissive in tests.
  bool? _dreamingEnabled;

  void configureAI({AIProvider? provider, AIModel? model}) {
    _provider = provider;
    _model = model;
  }

  void setDreamingEnabled(bool enabled) {
    _dreamingEnabled = enabled;
    if (!enabled) {
      _idleTimer?.cancel();
    }
  }

  static const String _extractionSystemPrompt = '''
You are a memory extraction assistant. Identify facts about the user from the conversation
and return them as compact JSON fragments. Use short, declarative sentences.
If the conversation adds no new facts, return an empty list.
''';
}

/// Riverpod provider for [DreamingService].
///
/// Single instance per process; tied to the [memoryServiceProvider] lifetime.
/// The policy + Hebbian config + dual-time-signal scorer are derived from
/// the active [AppSettings] so user-tunable values in the settings page
/// immediately affect the forgetting engine.
final dreamingServiceProvider = Provider<DreamingService>((ref) {
  final memory = ref.watch(memoryServiceProvider);
  final exporter = ref.watch(chatHistoryExporterProvider);
  final settings = ref.watch(settingsProvider);
  final policy = MemoryForgettingPolicy(
    weights: const MemoryScoringWeights(),
    shortToMidThreshold: settings.memoryShortToMidThreshold,
    midToLongThreshold: settings.memoryMidToLongThreshold,
    shortMaxAge: Duration(days: settings.memoryShortMaxAgeDays),
    midMaxAge: Duration(days: settings.memoryMidMaxAgeDays),
  );
  final scorer = MemoryScorer(
    policy: policy,
    createdRecencyHalfLife: Duration(
      days: settings.memoryCreatedRecencyHalfLifeDays,
    ),
    accessRecencyHalfLife: Duration(
      days: settings.memoryAccessRecencyHalfLifeDays,
    ),
    useLastAccessForRecency: settings.memoryUseLastAccessForRecency,
  );
  final hebbian = ref.watch(hebbianServiceProvider);
  final service = DreamingService(
    memory,
    exporter: exporter,
    scorer: scorer,
    hebbian: hebbian,
  );
  service.setDreamingEnabled(settings.memoryDreamingEnabled);
  ref.onDispose(service.dispose);
  return service;
});

// ─── Data classes ────────────────────────────────────────────────────

class _FragmentData {
  final String content;
  final String category;
  final double importance;
  final List<String> mediaRefs;
  final String? supersedesId;

  _FragmentData({
    required this.content,
    this.category = 'fact',
    this.importance = 0.0,
    this.mediaRefs = const [],
    this.supersedesId,
  });
}

class _ExtractionResult {
  final List<_FragmentData> newFragments;
  final List<String> supersededIds;
  final List<_FragmentData> updatedFragments;

  _ExtractionResult({
    required this.newFragments,
    required this.supersededIds,
    required this.updatedFragments,
  });
}

class _ForgettingPhase {
  final MemoryTier fromTier;
  final DateTime olderThan;
  final double threshold;
  final int windowMs;

  _ForgettingPhase({
    required this.fromTier,
    required this.olderThan,
    required this.threshold,
    required this.windowMs,
  });
}

class _ForgettingRunResult {
  final int scannedRecords;
  final int eligibleRecords;
  final int createdSummaries;
  final int transitionedRecords;
  final int archivedDetailRecords;

  _ForgettingRunResult({
    required this.scannedRecords,
    required this.eligibleRecords,
    required this.createdSummaries,
    required this.transitionedRecords,
    required this.archivedDetailRecords,
  });
}

/// A snapshot of the [DreamingService]'s last-run stats and current state.
/// Rendered by the Memory Settings "Dreaming activity" card so the user
/// can see "when did the system last dream" without having to dig through
/// logs.
class DreamingStatus {
  final DateTime? lastConsolidationAt;
  final int lastNewFragments;
  final int lastSummariesCreated;
  final int lastRecordsTransitioned;
  final int lastStaleEdgesPruned;
  final DateTime? lastExportAt;
  final String? lastExportPath;
  final bool isConsolidating;
  final int pendingMessages;
  final int lastL2Rollups;
  final int lastL3Rollups;
  final int lastCrossSessionEdges;
  const DreamingStatus({
    this.lastConsolidationAt,
    this.lastNewFragments = 0,
    this.lastSummariesCreated = 0,
    this.lastRecordsTransitioned = 0,
    this.lastStaleEdgesPruned = 0,
    this.lastExportAt,
    this.lastExportPath,
    this.isConsolidating = false,
    this.pendingMessages = 0,
    this.lastL2Rollups = 0,
    this.lastL3Rollups = 0,
    this.lastCrossSessionEdges = 0,
  });

  DreamingStatus copyWith({
    DateTime? lastConsolidationAt,
    int? lastNewFragments,
    int? lastSummariesCreated,
    int? lastRecordsTransitioned,
    int? lastStaleEdgesPruned,
    DateTime? lastExportAt,
    String? lastExportPath,
    bool? isConsolidating,
    int? pendingMessages,
    int? lastL2Rollups,
    int? lastL3Rollups,
    int? lastCrossSessionEdges,
  }) {
    return DreamingStatus(
      lastConsolidationAt: lastConsolidationAt ?? this.lastConsolidationAt,
      lastNewFragments: lastNewFragments ?? this.lastNewFragments,
      lastSummariesCreated: lastSummariesCreated ?? this.lastSummariesCreated,
      lastRecordsTransitioned:
          lastRecordsTransitioned ?? this.lastRecordsTransitioned,
      lastStaleEdgesPruned: lastStaleEdgesPruned ?? this.lastStaleEdgesPruned,
      lastExportAt: lastExportAt ?? this.lastExportAt,
      lastExportPath: lastExportPath ?? this.lastExportPath,
      isConsolidating: isConsolidating ?? this.isConsolidating,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      lastL2Rollups: lastL2Rollups ?? this.lastL2Rollups,
      lastL3Rollups: lastL3Rollups ?? this.lastL3Rollups,
      lastCrossSessionEdges:
          lastCrossSessionEdges ?? this.lastCrossSessionEdges,
    );
  }
}

/// Riverpod provider for the dreaming activity snapshot. Auto-refreshes
/// every 30 seconds so the settings card stays current without requiring
/// the user to tap a refresh button.
final dreamingStatusProvider = StreamProvider<DreamingStatus>((ref) async* {
  // Emit immediately with the current snapshot, then on a timer.
  final svc = ref.watch(dreamingServiceProvider);
  yield _snapshot(svc, ref);
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 30))) {
    yield _snapshot(svc, ref);
  }
});

DreamingStatus _snapshot(DreamingService svc, Ref ref) {
  return DreamingStatus(
    lastConsolidationAt: svc.lastConsolidationAt,
    lastNewFragments: svc.lastNewFragments,
    lastSummariesCreated: svc.lastSummariesCreated,
    lastRecordsTransitioned: svc.lastRecordsTransitioned,
    lastStaleEdgesPruned: svc.lastStaleEdgesPruned,
    lastExportAt: svc.lastExportAt,
    lastExportPath: svc.lastExportPath,
    isConsolidating: svc.isConsolidating,
    lastL2Rollups: svc.lastL2Rollups,
    lastL3Rollups: svc.lastL3Rollups,
    lastCrossSessionEdges: svc.lastCrossSessionEdges,
  );
}

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/logging/app_logger.dart';
import '../data/models/ai_provider.dart';
import '../data/models/chat_memory.dart';
import '../data/models/sampling_settings.dart';
import '../core/memory/memory_scorer.dart';
import '../core/memory/memory_summarizer.dart';
import '../core/memory/summary_rollup.dart';
import 'chat_history_exporter.dart';
import 'memory_service.dart';
import 'dio_factory.dart';
import 'settings_service.dart';
import 'hebbian_service.dart';

part 'dreaming_extraction.dart';
part 'dreaming_forgetting.dart';
part 'dreaming_status.dart';

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
abstract class _DreamingServiceBase {
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

  _DreamingServiceBase(
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

  /// Force an export of the current session. Public hook for the settings
  /// UI "Export chat" button.
  Future<String?> exportCurrentSession() async {
    final exporter = _exporter;
    if (exporter == null) {
      appLog.debug('DreamingService.exportCurrentSession: no exporter wired');
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
        appLog.error('DreamingService threshold check error', error: e);
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
      appLog.error('DreamingService idle consolidate error', error: e);
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
        appLog.debug('DreamingService: exported chat to $path');
      }
    } catch (e) {
      appLog.error('DreamingService auto-export error', error: e);
    }
  }

  // ─── Configuration ─────────────────────────────────────────────────

  // Will be set by the Provider to give access to AI config.
  AIProvider? _provider;
  AIModel? _model;

  /// Sampling parameters for dreaming extraction (temperature / max_tokens).
  /// Defaults to a conservative 0.3 / 1024 when not configured.
  SamplingSettings _sampling = const SamplingSettings();

  /// Whether the user has enabled background dreaming in settings.
  /// `null` means "default on" so the service is permissive in tests.
  bool? _dreamingEnabled;

  void configureAI({AIProvider? provider, AIModel? model}) {
    _provider = provider;
    _model = model;
  }

  /// Update sampling parameters. Called by the provider when settings change.
  void configureSampling(SamplingSettings sampling) {
    _sampling = sampling;
  }

  void setDreamingEnabled(bool enabled) {
    _dreamingEnabled = enabled;
    if (!enabled) {
      _idleTimer?.cancel();
    }
  }

  // Implemented by [DreamingService] using mixin methods.
  Future<void> _consolidate();
}

/// Concrete dreaming service. Combines the extraction and forgetting
/// mixins and provides the [_consolidate] orchestration that ties them
/// together.
class DreamingService extends _DreamingServiceBase
    with _DreamingExtractionMixin, _DreamingForgettingMixin {
  DreamingService(
    super.memory, {
    super.scorer,
    super.summarizer,
    super.rollup,
    super.hebbian,
    super.exporter,
  });

  // ─── Core consolidation ────────────────────────────────────────────

  @override
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
        appLog.debug(
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
        appLog.debug('DreamingService: pruned $staleEdges stale Hebbian edges');
      }

      _lastConsolidatedCount = await _memory.getUnconsolidatedCount();
      // Capture last-run status for the dreamingStatusProvider.
      _lastConsolidationAt = DateTime.now();
      _lastNewFragments = extractResult.newFragments.length;
      _lastSummariesCreated = forgettingStats.createdSummaries;
      _lastRecordsTransitioned = forgettingStats.transitionedRecords;
      appLog.debug(
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
        appLog.debug(
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
          appLog.debug(
            'DreamingService: cross-session added '
            '$_lastCrossSessionEdges edges',
          );
        }
      }

      // 4. Auto-export the session as Markdown if enough new messages have
      //    accumulated. Failures are logged but never block the cycle.
      await _maybeAutoExport();
    } catch (e) {
      appLog.error('DreamingService consolidation error', error: e);
    } finally {
      _memory.releaseConsolidationLock(lock);
      _isConsolidating = false;
    }
  }
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
    shortToMidThreshold: settings.memory.shortToMidThreshold,
    midToLongThreshold: settings.memory.midToLongThreshold,
    shortMaxAge: Duration(days: settings.memory.shortMaxAgeDays),
    midMaxAge: Duration(days: settings.memory.midMaxAgeDays),
  );
  final scorer = MemoryScorer(
    policy: policy,
    createdRecencyHalfLife: Duration(
      days: settings.memory.createdRecencyHalfLifeDays,
    ),
    accessRecencyHalfLife: Duration(
      days: settings.memory.accessRecencyHalfLifeDays,
    ),
    useLastAccessForRecency: settings.memory.useLastAccessForRecency,
  );
  final hebbian = ref.watch(hebbianServiceProvider);
  final service = DreamingService(
    memory,
    exporter: exporter,
    scorer: scorer,
    hebbian: hebbian,
  );
  service.setDreamingEnabled(settings.memory.dreamingEnabled);
  service.configureSampling(settings.sampling);
  ref.onDispose(service.dispose);
  return service;
});

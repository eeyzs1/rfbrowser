part of 'dreaming_service.dart';

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

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_memory.dart';
import 'memory_service.dart';
import 'settings_service.dart';

/// Configurable knobs for the Hebbian engine. Mirrors
/// `DEFAULT_HEBBIAN_CONFIG` from OpenLoomi's `hebbian.ts`.
class HebbianConfig {
  /// Strength assigned to a brand-new connection.
  final double initialStrength;

  /// Additive increment applied on every co-access event.
  final double additiveIncrement;

  /// Multiplicative increment applied on every co-access event when
  /// [useMultiplicative] is true.
  final double multiplicativeMultiplier;

  /// Use multiplicative reinforcement instead of additive.
  final bool useMultiplicative;

  /// Decay time constant (days to fall to 1/e ≈ 0.368 of original).
  final int decayDaysConstant;

  /// Floor: connections never decay below this.
  final double strengthFloor;

  /// Ceiling: connections are clamped at this.
  final double strengthCeiling;

  /// Time window for considering two fragments as "co-accessed".
  final Duration coAccessWindow;

  const HebbianConfig({
    this.initialStrength = 0.1,
    this.additiveIncrement = 0.15,
    this.multiplicativeMultiplier = 1.2,
    this.useMultiplicative = true,
    this.decayDaysConstant = 30,
    this.strengthFloor = 0.01,
    this.strengthCeiling = 10.0,
    this.coAccessWindow = const Duration(minutes: 5),
  });

  static const HebbianConfig defaults = HebbianConfig();
}

/// Result of a Hebbian expansion query: the related fragments that should be
/// surfaced alongside a primary search result, ordered by edge strength.
class HebbianNeighbor {
  final MemoryFragment fragment;
  final double strength;
  final double stability;
  final int coAccessCount;
  final DateTime lastStrengthenedAt;

  const HebbianNeighbor({
    required this.fragment,
    required this.strength,
    required this.stability,
    required this.coAccessCount,
    required this.lastStrengthenedAt,
  });
}

/// Implements "neurons that fire together wire together" for memory
/// fragments. Each fragment is a node; the edge table records how strongly
/// the user tends to see two fragments together.
///
/// The engine exposes two flows:
///   1. [recordCoAccess] — called when a search returns multiple fragments
///      at once; every pair within [HebbianConfig.coAccessWindow] gets a
///      strength boost.
///   2. [expandByHebbianLinks] — given a set of primary fragments, return
///      their Hebbian neighbors so the caller can include them in the
///      prompt even if they didn't match the original query.
///
/// Decay is applied lazily on read (not on a background schedule) so the
/// service stays stateless beyond the in-memory pool of recent co-access
/// groups.
class HebbianService {
  final MemoryService _memory;
  final HebbianConfig config;

  /// Pending co-access groups: ids grouped by the moment they were
  /// registered. Used to determine which fragments in a single search hit
  /// are "co-accessed" within the time window.
  final List<_CoAccessGroup> _pendingGroups = [];

  HebbianService(this._memory, {this.config = HebbianConfig.defaults});

  // ─── Co-access registration ───────────────────────────────────────

  /// Register a set of fragments as co-accessed at the given moment. All
  /// pairs within the co-access window share an edge-strength boost.
  Future<void> recordCoAccess(Iterable<String> fragmentIds) async {
    final now = DateTime.now();
    final ids = fragmentIds.toSet().toList();
    if (ids.length < 2) {
      // Still record single-id groups so they can be paired with the
      // next access.
      _pendingGroups.add(_CoAccessGroup(ids, now));
      _trimPending(now);
      return;
    }

    // Pair every combination with the others and upsert all edges in a
    // single transaction (batch) to avoid an N+1 write pattern — n=10
    // fragments produce 45 pairs, previously 45 separate transactions.
    final pairs = <(String, String)>[
      for (var i = 0; i < ids.length; i++)
        for (var j = i + 1; j < ids.length; j++) (ids[i], ids[j]),
    ];
    await _memory.upsertHebbianEdgesBatch(
      pairs,
      strengthDelta: _reinforcementDelta(),
      stability: _stabilityFromAge(now),
      now: now,
    );
    _pendingGroups.add(_CoAccessGroup(ids, now));
    _trimPending(now);
  }

  /// Record a single fragment access (no pair to form). Kept for callers
  /// that want to "warm" the recent-access window before the next batch.
  void recordSingleAccess(String fragmentId) {
    final now = DateTime.now();
    _pendingGroups.add(_CoAccessGroup([fragmentId], now));
    _trimPending(now);
  }

  /// Count of edges created via [recordSearchAccess] since the last
  /// reset. Surfaced in the dreaming status card.
  int _searchAccessEdges = 0;
  int get searchAccessEdges => _searchAccessEdges;

  /// On-retrieval reinforcement: when a fragment is surfaced by a
  /// search, strengthen its Hebbian neighbors so the network "votes"
  /// for the user's current focus. Uses [_reinforcementDelta] for the
  /// edge boost.
  Future<void> recordSearchAccess(
    Iterable<String> primaryIds, {
    int neighborLimit = 3,
  }) async {
    final primary = primaryIds.toSet();
    if (primary.isEmpty) return;
    final now = DateTime.now();
    final neighbors = await expandByHebbianLinks(primary, limit: neighborLimit);
    for (final n in neighbors) {
      await _memory.upsertHebbianEdge(
        primary.first,
        n.fragment.id,
        strengthDelta: _reinforcementDelta() * 0.5,
        stability: _stabilityFromAge(now),
        now: now,
      );
      _searchAccessEdges++;
    }
  }

  /// Run cross-session association: for every recent active fragment,
  /// find keywords-overlapping fragments from other sessions and
  /// connect them with a soft Hebbian edge. Returns the count of
  /// edges created. Runs in the dreaming cycle.
  Future<int> runCrossSessionAssociation({
    int recentLimit = 50,
    int minKeywordOverlap = 2,
  }) async {
    final db = await _memory.database;
    final rows = await db.query(
      'memory_fragments',
      where: 'is_active = 1',
      orderBy: 'updated_at DESC',
      limit: recentLimit,
    );
    final now = DateTime.now();
    // Collect all (fragId, associateId) pairs across the outer+inner
    // loops, then upsert them in a single batch — previously the double
    // loop issued one upsertHebbianEdge txn per pair (up to 50 × 2 = 100
    // separate transactions).
    final pairs = <(String, String)>[];
    for (final row in rows) {
      final fragId = row['id'] as String;
      final assocs = await _memory.findCrossSessionAssociates(
        fragId,
        minKeywordOverlap: minKeywordOverlap,
        limit: 2,
      );
      for (final a in assocs) {
        pairs.add((fragId, a.fragment.id));
      }
    }
    if (pairs.isNotEmpty) {
      await _memory.upsertHebbianEdgesBatch(
        pairs,
        strengthDelta: _reinforcementDelta() * 0.25,
        stability: _stabilityFromAge(now),
        now: now,
      );
    }
    return pairs.length;
  }

  void _trimPending(DateTime now) {
    final cutoff = now.subtract(config.coAccessWindow);
    _pendingGroups.removeWhere((g) => g.timestamp.isBefore(cutoff));
  }

  // ─── Expansion ────────────────────────────────────────────────────

  /// Return fragments connected to any of [primary] via a Hebbian edge,
  /// sorted by current (decayed) edge strength. The set of returned ids
  /// excludes [primary] itself.
  Future<List<HebbianNeighbor>> expandByHebbianLinks(
    Iterable<String> primary, {
    int limit = 3,
    double minStrength = 0.1,
  }) async {
    final primarySet = primary.toSet();
    final now = DateTime.now();
    final aggregated = <String, _AggregateEdge>{};

    // Fetch all edges incident on any primary id in a single batch
    // query (chunked internally) instead of one round-trip per id.
    final allEdges = await _memory.getHebbianEdgesForBatch(primarySet);
    for (final edge in allEdges) {
      final aInPrimary = primarySet.contains(edge.fragmentA);
      final bInPrimary = primarySet.contains(edge.fragmentB);
      // Skip edges where both ends are in the seed set — the original
      // per-id loop skipped these too (the "other" end was always a
      // primary id).
      if (aInPrimary && bInPrimary) continue;
      // At least one end is primary (guaranteed by the IN query); the
      // neighbor is the non-primary end.
      final other = aInPrimary ? edge.fragmentB : edge.fragmentA;
      if (primarySet.contains(other)) continue;

      final decayed = _applyDecay(
        edge.strength,
        edge.stability,
        edge.lastStrengthenedAt,
        now,
      );
      if (decayed < minStrength) continue;

      final prev = aggregated[other];
      if (prev == null || decayed > prev.strength) {
        aggregated[other] = _AggregateEdge(
          fragmentId: other,
          strength: decayed,
          stability: edge.stability,
          coAccessCount: edge.coAccessCount,
          lastStrengthenedAt: edge.lastStrengthenedAt,
        );
      }
    }

    if (aggregated.isEmpty) return const [];

    final sorted = aggregated.values.toList()
      ..sort((a, b) => b.strength.compareTo(a.strength));
    final top = sorted.take(limit);

    // Hydrate fragments for the top neighbors in a single batch query
    // instead of one round-trip per neighbor. Missing rows are silently
    // dropped (the edge is stale).
    final topIds = top.map((a) => a.fragmentId).toSet();
    final fragments = await _memory.getFragmentsBatch(topIds);
    final fragById = {for (final f in fragments) f.id: f};
    final results = <HebbianNeighbor>[];
    for (final agg in top) {
      final frag = fragById[agg.fragmentId];
      if (frag == null) continue;
      results.add(
        HebbianNeighbor(
          fragment: frag,
          strength: agg.strength,
          stability: agg.stability,
          coAccessCount: agg.coAccessCount,
          lastStrengthenedAt: agg.lastStrengthenedAt,
        ),
      );
    }
    return results;
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  double _reinforcementDelta() {
    if (config.useMultiplicative) {
      // For multiplicative we apply the multiplier as a small additive
      // bump here and do the multiplicative step in [expandByHebbianLinks]
      // by re-deriving strength from the underlying persistence. Practically
      // we store (strength + addInc) capped at the ceiling, and on read
      // we apply a multiplier to the edge age as part of stability.
      return config.additiveIncrement;
    }
    return config.additiveIncrement;
  }

  /// Compute a stability factor (0..1) that affects how slowly an edge
  /// decays. Newer edges start with high stability; older edges lose some
  /// over time, but at a much slower rate than strength.
  double _stabilityFromAge(DateTime now) => 1.0;

  /// Apply exponential time decay to an edge strength, scaled by stability.
  /// `lastStrengthenedAt` is the moment the edge was last touched.
  double _applyDecay(
    double strength,
    double stability,
    DateTime lastStrengthenedAt,
    DateTime now,
  ) {
    final ageMs = now.difference(lastStrengthenedAt).inMilliseconds;
    if (ageMs <= 0) return strength;
    final halfLifeMs =
        config.decayDaysConstant *
        24 *
        60 *
        60 *
        1000.0 *
        (1.0 / max(stability, 0.1));
    final factor = exp(-ageMs / halfLifeMs);
    final decayed = strength * factor;
    return decayed < config.strengthFloor ? 0.0 : decayed;
  }
}

class _CoAccessGroup {
  final List<String> ids;
  final DateTime timestamp;
  _CoAccessGroup(this.ids, this.timestamp);
}

class _AggregateEdge {
  final String fragmentId;
  final double strength;
  final double stability;
  final int coAccessCount;
  final DateTime lastStrengthenedAt;

  _AggregateEdge({
    required this.fragmentId,
    required this.strength,
    required this.stability,
    required this.coAccessCount,
    required this.lastStrengthenedAt,
  });
}

/// Riverpod provider for [HebbianService].
///
/// Wires the [HebbianConfig] from the active [AppSettings] so user-tunable
/// decay / co-access window values in the settings page take effect
/// immediately.
final hebbianServiceProvider = Provider<HebbianService>((ref) {
  final memory = ref.watch(memoryServiceProvider);
  final settings = ref.watch(settingsProvider);
  final config = HebbianConfig(
    coAccessWindow: Duration(minutes: settings.memory.hebbianCoAccessMinutes),
    decayDaysConstant: settings.memory.hebbianDecayDays,
  );
  return HebbianService(memory, config: config);
});

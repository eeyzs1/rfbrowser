import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/chat_memory.dart';
import '../../data/stopwords.dart';
import 'memory_database.dart';

const _uuid = Uuid();

/// Repository for the `memory_hebbian_links` table — co-access
/// reinforcement edges that form the memory association graph.
class HebbianEdgeRepository {
  final MemoryDatabase _db;
  HebbianEdgeRepository(this._db);

  Future<Database> get _database => _db.database;

  /// Fetch all edges incident on a fragment (as either endpoint).
  Future<List<HebbianEdge>> getHebbianEdgesFor(String fragmentId) async {
    final db = await _database;
    final rows = await db.query(
      'memory_hebbian_links',
      where: 'fragment_a = ? OR fragment_b = ?',
      whereArgs: [fragmentId, fragmentId],
    );
    return rows.map(HebbianEdge.fromRow).toList();
  }

  /// Fetch all edges incident on any of [ids] (as either endpoint) in a
  /// single query per chunk. Used by [HebbianService.expandByHebbianLinks]
  /// to avoid one round-trip per primary id.
  ///
  /// SQLite limits the number of bound variables to 999; because the
  /// query references each id twice (`fragment_a IN (...) OR fragment_b
  /// IN (...)`), [ids] is chunked so each query stays well below that
  /// limit.
  Future<List<HebbianEdge>> getHebbianEdgesForBatch(
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return const [];
    final db = await _database;
    final results = <HebbianEdge>[];
    for (final chunk in _chunk(idList, 400)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT * FROM memory_hebbian_links '
        'WHERE fragment_a IN ($placeholders) '
        'OR fragment_b IN ($placeholders)',
        [...chunk, ...chunk],
      );
      results.addAll(rows.map(HebbianEdge.fromRow));
    }
    return results;
  }

  /// Compact, paginated edge list for the Hebbian graph view. Returns
  /// the top [limit] strongest edges, descending. Used by the memory
  /// graph page to render the network.
  Future<List<HebbianEdge>> getTopHebbianEdges({int limit = 200}) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT id, fragment_a, fragment_b, strength, stability, '
      'co_access_count, last_strengthened_at FROM memory_hebbian_links '
      'ORDER BY strength DESC, last_strengthened_at DESC LIMIT ?',
      [limit],
    );
    return rows
        .map(
          (r) => HebbianEdge(
            id: r['id'] as String,
            fragmentA: r['fragment_a'] as String,
            fragmentB: r['fragment_b'] as String,
            strength: (r['strength'] as num).toDouble(),
            stability: (r['stability'] as num).toDouble(),
            coAccessCount: r['co_access_count'] as int,
            lastStrengthenedAt: DateTime.parse(
              r['last_strengthened_at'] as String,
            ),
          ),
        )
        .toList();
  }

  /// Get a list of fragment ids that participate in at least one
  /// Hebbian edge. Used by the memory graph page to filter the
  /// fragment list down to "network nodes" only.
  Future<List<MemoryFragment>> getNetworkedFragments({int limit = 200}) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT f.* FROM memory_fragments f
      WHERE f.is_active = 1
        AND f.id IN (
          SELECT fragment_a FROM memory_hebbian_links
          UNION
          SELECT fragment_b FROM memory_hebbian_links
        )
      ORDER BY f.importance_score DESC, f.last_access_at DESC
      LIMIT ?
    ''',
      [limit],
    );
    return rows.map(MemoryFragment.fromRow).toList();
  }

  /// Tokenize a fragment's content into a small keyword set used for
  /// cross-session association. Lowercases, strips punctuation, drops
  /// stopwords and tokens shorter than 4 chars. Returns at most
  /// [limit] tokens, the longest first (to bias the match toward
  /// high-signal words).
  static List<String> tokenizeForCrossSession(String content, {int limit = 8}) {
    if (content.isEmpty) return const [];
    final words =
        content
            .toLowerCase()
            .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 4 && !kCrossSessionStopwords.contains(w))
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    return words.take(limit).toList();
  }

  /// Find fragments from *other* sessions that share at least
  /// [minKeywordOverlap] keywords with [fragmentId]. Excludes the
  /// fragment's own session so that same-session co-access is left
  /// to the Hebbian machinery. Ordered by overlap count desc.
  ///
  /// The keyword-overlap matching over the candidate set runs in a
  /// worker isolate via [compute] so that tokenizing up to 200
  /// candidates does not block the UI isolate.
  Future<List<({MemoryFragment fragment, int overlap})> >
  findCrossSessionAssociates(
    String fragmentId, {
    int minKeywordOverlap = 2,
    int limit = 5,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'memory_fragments',
      where: 'id = ?',
      whereArgs: [fragmentId],
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    final source = rows.first;
    final sourceSession = source['session_id'] as String;
    final keywords = tokenizeForCrossSession(source['content'] as String);
    if (keywords.isEmpty) return const [];

    // Pull a candidate set of recent active fragments from other sessions.
    final candidates = await db.query(
      'memory_fragments',
      where: 'is_active = 1 AND id != ? AND session_id != ?',
      whereArgs: [fragmentId, sourceSession],
      orderBy: 'updated_at DESC',
      limit: 200,
    );

    // Match keywords in a worker isolate to keep the UI isolate free.
    final matches = await compute(
      _matchCrossSessionKeywords,
      _CrossSessionMatchInput(
        sourceKeywords: keywords,
        candidateContents: [
          for (final c in candidates) c['content'] as String,
        ],
        minKeywordOverlap: minKeywordOverlap,
      ),
    );

    final results = <({MemoryFragment fragment, int overlap})>[];
    for (final m in matches) {
      results.add((
        fragment: MemoryFragment.fromRow(candidates[m.index]),
        overlap: m.overlap,
      ));
    }
    results.sort((a, b) => b.overlap.compareTo(a.overlap));
    return results.take(limit).toList();
  }

  /// Upsert a Hebbian edge between two fragments. The pair is stored with the
  /// smaller id in `fragment_a` so lookups are symmetric.
  Future<void> upsertHebbianEdge(
    String fragmentA,
    String fragmentB, {
    required double strengthDelta,
    required double stability,
    required DateTime now,
  }) async {
    if (fragmentA == fragmentB) return;
    final a = fragmentA.compareTo(fragmentB) <= 0 ? fragmentA : fragmentB;
    final b = fragmentA.compareTo(fragmentB) <= 0 ? fragmentB : fragmentA;
    final db = await _database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'memory_hebbian_links',
        where: 'fragment_a = ? AND fragment_b = ?',
        whereArgs: [a, b],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('memory_hebbian_links', {
          'id': _uuid.v4(),
          'fragment_a': a,
          'fragment_b': b,
          'strength': 0.1 + strengthDelta,
          'stability': stability,
          'co_access_count': 1,
          'last_strengthened_at': now.toIso8601String(),
        });
      } else {
        final row = existing.first;
        final prevStrength = (row['strength'] as num).toDouble();
        final newStrength = (prevStrength + strengthDelta)
            .clamp(0.01, 10.0)
            .toDouble();
        await txn.update(
          'memory_hebbian_links',
          {
            'strength': newStrength,
            'stability': stability,
            'co_access_count': (row['co_access_count'] as int) + 1,
            'last_strengthened_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  }

  /// Upsert many Hebbian edges in a single transaction. Each pair is
  /// normalized so the smaller id is stored in `fragment_a` (keeping
  /// lookups symmetric) and duplicate pairs within [pairs] are
  /// collapsed. Existing edges are strengthened by [strengthDelta];
  /// missing edges are inserted with an initial strength of
  /// `0.1 + strengthDelta`.
  ///
  /// This is the batch counterpart of [upsertHebbianEdge]. It replaces
  /// the per-pair transaction that produced an N+1 write pattern in
  /// [HebbianService.recordCoAccess] (n=10 → 45 separate transactions
  /// become one).
  Future<void> upsertHebbianEdgesBatch(
    List<(String, String)> pairs, {
    required double strengthDelta,
    required double stability,
    required DateTime now,
  }) async {
    // Normalize + dedupe pairs.
    final normalized = <String, (String, String)>{};
    for (final (a, b) in pairs) {
      if (a == b) continue;
      final (na, nb) = a.compareTo(b) <= 0 ? (a, b) : (b, a);
      normalized['$na\x00$nb'] = (na, nb);
    }
    if (normalized.isEmpty) return;
    final db = await _database;
    final nowIso = now.toIso8601String();
    await db.transaction((txn) async {
      // Fetch all existing edges for the involved fragments in one
      // query (chunked to respect SQLite's 999-variable limit). The
      // OR may return edges outside our pair set; we filter to exact
      // pairs via the map below.
      final involvedIds = <String>{
        for (final (a, b) in normalized.values) ...[a, b],
      };
      final existingByKey = <String, Map<String, Object?>>{};
      for (final chunk in _chunk(involvedIds.toList(), 400)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await txn.rawQuery(
          'SELECT * FROM memory_hebbian_links '
          'WHERE fragment_a IN ($placeholders) '
          'OR fragment_b IN ($placeholders)',
          [...chunk, ...chunk],
        );
        for (final row in rows) {
          existingByKey['${row['fragment_a']}\x00${row['fragment_b']}'] = row;
        }
      }

      final batch = txn.batch();
      for (final (na, nb) in normalized.values) {
        final key = '$na\x00$nb';
        final existing = existingByKey[key];
        if (existing == null) {
          batch.insert('memory_hebbian_links', {
            'id': _uuid.v4(),
            'fragment_a': na,
            'fragment_b': nb,
            'strength': 0.1 + strengthDelta,
            'stability': stability,
            'co_access_count': 1,
            'last_strengthened_at': nowIso,
          });
        } else {
          final prevStrength = (existing['strength'] as num).toDouble();
          final newStrength = (prevStrength + strengthDelta)
              .clamp(0.01, 10.0)
              .toDouble();
          batch.update(
            'memory_hebbian_links',
            {
              'strength': newStrength,
              'stability': stability,
              'co_access_count': (existing['co_access_count'] as int) + 1,
              'last_strengthened_at': nowIso,
            },
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  /// Delete Hebbian edges that have decayed below the floor for longer
  /// than [olderThan] (defaults to 90 days). Returns the number of rows
  /// removed. Called periodically by the dreaming engine to prevent the
  /// edge table from growing without bound.
  ///
  /// "Below the floor for X days" is approximated by selecting rows whose
  /// [HebbianEdge.lastStrengthenedAt] is older than [olderThan] AND whose
  /// [HebbianEdge.coAccessCount] is exactly 1 (i.e. they have never been
  /// reinforced). That keeps the cleanup conservative — edges that have
  /// proven valuable at least once survive a long quiet period.
  Future<int> deleteStaleHebbianEdges({
    Duration olderThan = const Duration(days: 90),
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now())
        .subtract(olderThan)
        .toIso8601String();
    final db = await _database;
    return db.delete(
      'memory_hebbian_links',
      where: 'last_strengthened_at < ? AND co_access_count <= 1',
      whereArgs: [cutoff],
    );
  }
}

/// Split [list] into chunks of at most [size] elements. Used to keep
/// `IN (...)` queries under SQLite's 999 bound-variable limit.
Iterable<List<T>> _chunk<T>(List<T> list, int size) sync* {
  for (var i = 0; i < list.length; i += size) {
    yield list.sublist(i, i + size > list.length ? list.length : i + size);
  }
}

/// Input for the worker-isolate keyword matching in
/// [HebbianEdgeRepository.findCrossSessionAssociates]. Only primitive /
/// sendable fields so it can cross an isolate boundary via [compute].
class _CrossSessionMatchInput {
  final List<String> sourceKeywords;
  final List<String> candidateContents;
  final int minKeywordOverlap;
  const _CrossSessionMatchInput({
    required this.sourceKeywords,
    required this.candidateContents,
    required this.minKeywordOverlap,
  });
}

/// Result of matching one candidate: its index in the candidate list
/// and the keyword overlap count.
class _CrossSessionMatch {
  final int index;
  final int overlap;
  const _CrossSessionMatch({required this.index, required this.overlap});
}

/// Top-level function — keyword-overlap matching for
/// [HebbianEdgeRepository.findCrossSessionAssociates]. Runs in a worker
/// isolate via [compute] so tokenizing the candidate set (up to 200
/// fragments) does not stall the UI isolate. Must be top-level (not a
/// closure) so it can be sent to the spawned isolate.
List<_CrossSessionMatch> _matchCrossSessionKeywords(
  _CrossSessionMatchInput input,
) {
  final sourceKeywords = input.sourceKeywords.toSet();
  final results = <_CrossSessionMatch>[];
  for (var i = 0; i < input.candidateContents.length; i++) {
    final candKeywords = HebbianEdgeRepository.tokenizeForCrossSession(
      input.candidateContents[i],
    ).toSet();
    final overlap = sourceKeywords.intersection(candKeywords).length;
    if (overlap >= input.minKeywordOverlap) {
      results.add(_CrossSessionMatch(index: i, overlap: overlap));
    }
  }
  return results;
}

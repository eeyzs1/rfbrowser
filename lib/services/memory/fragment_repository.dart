import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../data/models/chat_memory.dart';
import '../../data/stores/index_store.dart';
import 'memory_database.dart';

const _uuid = Uuid();

/// Repository for the `memory_fragments` table (Layer 1 of the memory
/// pyramid). All fragment CRUD and FTS search live here.
class FragmentRepository {
  final MemoryDatabase _db;
  FragmentRepository(this._db);

  Future<Database> get _database => _db.database;

  /// Insert or replace a memory fragment.
  Future<void> upsertFragment(MemoryFragment fragment) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert(
        'memory_fragments',
        fragment.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final tokenized = IndexStore.tokenizeForFts(fragment.content);
      await txn.insert('memory_fragments_fts', {
        'id': fragment.id,
        'content': tokenized,
        'category': fragment.category,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Mark a fragment as superseded (inactive).
  Future<void> deactivateFragment(
    String fragmentId, {
    String? supersededBy,
  }) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'memory_fragments',
      {'is_active': 0, 'superseded_by': supersededBy, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [fragmentId],
    );
  }

  /// Hard-delete a fragment by id. This is irreversible and also removes
  /// any Hebbian edges incident on the fragment. Use for explicit
  /// "Delete" actions from the UI; for normal forgetting the
  /// tier-transition path is preferred.
  Future<int> deleteFragment(String fragmentId) async {
    final db = await _database;
    return db.transaction((txn) async {
      await txn.delete(
        'memory_hebbian_links',
        where: 'fragment_a = ? OR fragment_b = ?',
        whereArgs: [fragmentId, fragmentId],
      );
      await txn.delete(
        'memory_fragments_fts',
        where: 'id = ?',
        whereArgs: [fragmentId],
      );
      return txn.delete(
        'memory_fragments',
        where: 'id = ?',
        whereArgs: [fragmentId],
      );
    });
  }

  /// Insert a fragment directly from a user "remember this" action in the
  /// chat panel. Bypasses the dreaming cycle so the fragment is
  /// immediately searchable and contributes to the next context
  /// assembly. Sets [MemoryFragment.source] to `'manual'` and
  /// [MemoryFragment.importanceScore] to [importance] (default 0.7, above
  /// the natural decay threshold) so it survives longer than an
  /// auto-extracted fact.
  ///
  /// If a fragment with the same [sourceMessageId] already exists, this
  /// returns its id without inserting a duplicate. This makes the chat
  /// button idempotent: clicking "remember" twice does nothing harmful.
  Future<String> addFragmentFromMessage({
    required String sessionId,
    required String messageId,
    required String content,
    double importance = 0.7,
    String source = 'manual',
    Map<String, Object?>? extra,
  }) async {
    final db = await _database;
    final now = DateTime.now();
    final existing = await db.query(
      'memory_fragments',
      where: 'source_message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return (existing.first['id'] as String);
    }
    final id = _uuid.v4();
    await db.insert('memory_fragments', {
      'id': id,
      'session_id': sessionId,
      'source_message_id': messageId,
      'content': content,
      'tier': MemoryTier.short.name,
      'importance_score': importance,
      'access_count': 0,
      'is_pinned': 0,
      'is_active': 1,
      'source': source,
      'extra_json': extra == null ? null : jsonEncode(extra),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    // Add an FTS row so the new fragment is immediately searchable.
    await db.insert('memory_fragments_fts', {
      'id': id,
      'content': content,
      'category': 'fact',
    });
    return id;
  }

  /// Mark a fragment as "forgotten by the user" — soft-delete with a
  /// special [MemoryFragment.source] of `'forgotten'`. The dreaming
  /// engine will skip these and they will not be returned by
  /// [searchFragments]. They remain in the DB for audit.
  Future<int> forgetFragment(String fragmentId) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    return db.update(
      'memory_fragments',
      {'is_active': 0, 'source': 'forgotten', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [fragmentId],
    );
  }

  /// Look up a fragment by its `source_message_id`. Used by the chat
  /// panel to determine whether a "Remember" or "Forget" button should
  /// be shown for a given message.
  Future<MemoryFragment?> getFragmentByMessageId(String? messageId) async {
    if (messageId == null) return null;
    final db = await _database;
    final rows = await db.query(
      'memory_fragments',
      where: 'source_message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MemoryFragment.fromRow(rows.first);
  }

  /// Transition a fragment's tier (short → mid → long).
  /// Optionally archives the raw content by writing `archivedAt` and clearing
  /// the body, leaving only a pointer back to the consolidating summary.
  Future<void> transitionFragmentTier(
    String fragmentId, {
    required MemoryTier newTier,
    required DateTime transitionedAt,
    String? summaryId,
    bool archive = false,
  }) async {
    final db = await _database;
    final update = <String, Object?>{
      'tier': newTier.name,
      'updated_at': transitionedAt.toIso8601String(),
    };
    if (summaryId != null) {
      update['parent_summary_id'] = summaryId;
    }
    if (archive) {
      update['archived_at'] = transitionedAt.toIso8601String();
    }
    await db.update(
      'memory_fragments',
      update,
      where: 'id = ?',
      whereArgs: [fragmentId],
    );
  }

  /// Pin / unpin a fragment. Pinned records are exempt from tier transitions
  /// and get a +0.3 boost in scoring.
  Future<void> setPinned(String fragmentId, bool pinned) async {
    final db = await _database;
    await db.update(
      'memory_fragments',
      {
        'is_pinned': pinned ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [fragmentId],
    );
  }

  /// Mark a fragment as accessed. Increments access_count and updates
  /// last_access_at. Called by callers (e.g. AI service) when a fragment is
  /// surfaced to the user.
  Future<void> markAccessed(String fragmentId) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE memory_fragments
      SET access_count = access_count + 1, last_access_at = ?
      WHERE id = ?
      ''',
      [now, fragmentId],
    );
  }

  /// Mark a batch of fragments as accessed in a single UPDATE per chunk
  /// (chunked to stay under SQLite's 999 bound-variable limit). Each id
  /// gets access_count incremented and last_access_at set to [now].
  Future<void> markAccessedBatch(Iterable<String> fragmentIds) async {
    // Count occurrences per id — duplicate ids must increment multiple times
    // (e.g. markAccessedBatch(['a','b','a']) must give 'a' accessCount += 2).
    final counts = <String, int>{};
    for (final id in fragmentIds) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return;
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final entry in counts.entries) {
        await txn.rawUpdate(
          'UPDATE memory_fragments SET access_count = access_count + ?, last_access_at = ? WHERE id = ?',
          [entry.value, now, entry.key],
        );
      }
    });
  }

  /// Search active memory fragments using FTS5, optionally restricted by tier.
  /// Records the resulting ids as accessed so that the Hebbian engine can
  /// later expand them as a co-access group.
  Future<List<MemoryFragment>> searchFragments(
    String query, {
    int limit = 5,
    List<MemoryTier>? tiers,
  }) async {
    final db = await _database;
    final tokenized = IndexStore.tokenizeForFts(query);
    if (tokenized.isEmpty) return [];
    final tierFilter = tiers == null || tiers.isEmpty
        ? null
        : tiers.map((t) => "'${t.name}'").join(',');
    final sql =
        '''
      SELECT f.* FROM memory_fragments f
      INNER JOIN memory_fragments_fts ft ON ft.id = f.id
      WHERE memory_fragments_fts MATCH ?
        AND f.is_active = 1
        ${tierFilter != null ? 'AND f.tier IN ($tierFilter)' : ''}
      ORDER BY rank
      LIMIT ?
    ''';
    try {
      final rows = await db.rawQuery(sql, [tokenized, limit]);
      final results = rows.map(MemoryFragment.fromRow).toList();
      // Asynchronously mark all hits as accessed; ignore failures (they're
      // advisory signals for the scoring engine, not critical writes).
      unawaited(
        markAccessedBatch(results.map((r) => r.id)).catchError((Object e) {
          appLog.error('FragmentRepository.markAccessedBatch error', error: e);
        }),
      );
      return results;
    } catch (e) {
      appLog.error('FragmentRepository FTS error for "$tokenized"', error: e);
      return [];
    }
  }

  /// Score breakdown for a single search hit. Used by the Memory
  /// Browser to render "why this matched" tooltips.
  FragmentMatch _match(MemoryFragment f, Set<String> tokens, DateTime now) {
    final lower = f.content.toLowerCase();
    final matched = tokens.where((t) => lower.contains(t)).length;
    final ageDays = f.lastAccessAt == null
        ? now.difference(f.createdAt).inDays
        : now.difference(f.lastAccessAt!).inDays;
    final recency = (1.0 - ageDays / 30.0).clamp(0.0, 1.0);
    final coverage = tokens.isEmpty ? 0.0 : matched / tokens.length;
    final composite = 0.5 * coverage + 0.3 * f.importanceScore + 0.2 * recency;
    return FragmentMatch(
      fragment: f,
      matchedTokens: matched,
      totalTokens: tokens.length,
      importanceScore: f.importanceScore,
      recencyScore: recency,
      compositeScore: composite,
    );
  }

  /// Run the same FTS query as [searchFragments] but also compute a
  /// per-hit score breakdown so the UI can show "why this matched".
  /// Components:
  ///   - tokenCoverage: how many of the query tokens appeared in the
  ///     fragment (0-1)
  ///   - importanceScore: the fragment's stored importance (0-1)
  ///   - recencyScore: 1 - daysSinceAccess / 30 (clamped to 0)
  ///   - compositeScore: 0.5*coverage + 0.3*importance + 0.2*recency
  Future<List<FragmentMatch>> searchFragmentsWithScores(
    String query, {
    int limit = 5,
  }) async {
    final fragments = await searchFragments(query, limit: limit);
    if (fragments.isEmpty) return const [];
    // IndexStore.tokenizeForFts joins tokens with a single space; split
    // back into a set for token-coverage scoring.
    final tokens = IndexStore.tokenizeForFts(
      query,
    ).split(' ').where((t) => t.isNotEmpty).toSet();
    final now = DateTime.now();
    return [for (final f in fragments) _match(f, tokens, now)];
  }

  /// Get all active fragments (for rebuilding or inspection). Defaults to
  /// the 500 most-recently-updated rows to avoid loading the entire table
  /// into memory; pass a larger [limit] (or null) for full scans.
  Future<List<MemoryFragment>> getAllActiveFragments({
    int limit = 500,
    int offset = 0,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'memory_fragments',
      where: 'is_active = 1',
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(MemoryFragment.fromRow).toList();
  }

  /// Get active fragments in a specific tier, oldest first.
  Future<List<MemoryFragment>> getFragmentsInTier(
    MemoryTier tier, {
    int limit = 500,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'memory_fragments',
      where: 'is_active = 1 AND tier = ?',
      whereArgs: [tier.name],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(MemoryFragment.fromRow).toList();
  }

  /// Get a single fragment by id.
  Future<MemoryFragment?> getFragment(String id) async {
    final db = await _database;
    final rows = await db.query(
      'memory_fragments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MemoryFragment.fromRow(rows.first);
  }

  /// Get multiple fragments by id in a single query per chunk. Missing
  /// ids are simply absent from the returned list. Used by
  /// [HebbianService.expandByHebbianLinks] to hydrate the top neighbor
  /// fragments without one round-trip per id.
  ///
  /// [ids] is chunked to stay under SQLite's 999 bound-variable limit.
  Future<List<MemoryFragment>> getFragmentsBatch(Iterable<String> ids) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return const [];
    final db = await _database;
    final results = <MemoryFragment>[];
    for (var i = 0; i < idList.length; i += 900) {
      final end = i + 900 > idList.length ? idList.length : i + 900;
      final chunk = idList.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT * FROM memory_fragments WHERE id IN ($placeholders)',
        chunk,
      );
      results.addAll(rows.map(MemoryFragment.fromRow));
    }
    return results;
  }

  /// Get fragments that were previously active but might be related to new content.
  Future<List<MemoryFragment>> getFragmentsForConflictCheck(
    List<String> keywords, {
    int limit = 5,
  }) async {
    if (keywords.isEmpty) return [];
    final db = await _database;
    // Build a simple OR query for keyword matching
    final query = keywords.map((k) => '"$k"').join(' OR ');
    final tokenized = IndexStore.tokenizeForFts(query);
    if (tokenized.isEmpty) return [];
    try {
      final rows = await db.rawQuery(
        '''
        SELECT f.* FROM memory_fragments f
        INNER JOIN memory_fragments_fts ft ON ft.id = f.id
        WHERE memory_fragments_fts MATCH ?
        ORDER BY f.updated_at DESC
        LIMIT ?
      ''',
        [tokenized, limit],
      );
      return rows.map(MemoryFragment.fromRow).toList();
    } catch (e) {
      appLog.error('FragmentRepository conflict check error', error: e);
      return [];
    }
  }

  /// Build a formatted context string from relevant fragments for system prompt.
  static String formatFragmentsForContext(List<MemoryFragment> fragments) {
    if (fragments.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('[User Memory — known facts from past conversations:]');
    for (final f in fragments) {
      buffer.writeln('- $f');
    }
    return buffer.toString();
  }
}

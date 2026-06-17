import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/chat_memory.dart';
import '../data/stores/index_store.dart';
import '../data/stores/vault_store.dart';

const _uuid = Uuid();

/// Persistent storage for chat messages and synthesized memory fragments.
///
/// Schema v2 (progressive forgetting):
///   - memory_fragments: adds tier / importance / access counters / pin
///   - memory_summaries: L1/L2/L3 consolidated summaries
///   - memory_hebbian_links: co-access reinforcement edges
///
/// Messages are persisted synchronously on every send/receive.
/// Fragments are created asynchronously by [DreamingService].
class MemoryService {
  final String _dbPath;
  Database? _db;
  Completer<Database>? _initCompleter;
  String? _currentSessionId;

  /// Process-wide single-flight lock: when a consolidation cycle is in
  /// progress, subsequent callers return immediately rather than pile up.
  Completer<void>? _consolidationLock;

  MemoryService(this._dbPath);

  /// Public accessor for the database path. Exposed so that
  /// [ChatHistoryExporter] (and any other service) can derive its output
  /// directory from the same root.
  String get databasePath => _dbPath;

  // ─── Database init ─────────────────────────────────────────────────

  Future<Database> get database async {
    if (_db != null) return _db!;
    _initCompleter ??= Completer<Database>();
    if (!_initCompleter!.isCompleted) {
      _db = await _initDb();
      _initCompleter!.complete(_db!);
    }
    return _initCompleter!.future;
  }

  /// Acquire a process-wide lock. Returns null if a consolidation is already
  /// running; callers should treat null as "someone else is doing it" and
  /// skip their work.
  Future<Completer<void>?> tryAcquireConsolidationLock() async {
    if (_consolidationLock != null) return null;
    _consolidationLock = Completer<void>();
    return _consolidationLock!;
  }

  void releaseConsolidationLock(Completer<void> lock) {
    if (identical(_consolidationLock, lock)) {
      _consolidationLock = null;
      if (!lock.isCompleted) lock.complete();
    }
  }

  Future<Database> _initDb() async {
    final dir = Directory(p.dirname(_dbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return openDatabase(
      _dbPath,
      version: 3,
      onCreate: (db, version) async {
        await _createV2Schema(db);
        await _upgradeV2ToV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeV1ToV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeV2ToV3(db);
        }
      },
    );
  }

  Future<void> _createV2Schema(Database db) async {
    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES chat_sessions(id)
      )
    ''');
    await _createFragmentsV2(db);
    await _createSummariesTable(db);
    await _createHebbianTable(db);
    await _createIndexes(db);
  }

  Future<void> _upgradeV1ToV2(Database db) async {
    // 1. Rename old fragments table to preserve data
    await db.execute(
      'ALTER TABLE memory_fragments RENAME TO memory_fragments_v1',
    );
    // 2. Recreate with v2 schema
    await _createFragmentsV2(db);
    // 3. Copy data over with sensible defaults for new fields
    await db.execute('''
      INSERT INTO memory_fragments
        (id, session_id, content, category, is_active, superseded_by,
         tier, importance_score, access_count, last_access_at, is_pinned,
         media_refs, archived_at, summary_tier, parent_summary_id,
         created_at, updated_at)
      SELECT
        id, session_id, content, category, is_active, superseded_by,
        'short', 0.0, 0, NULL, 0, NULL, NULL, 'none', NULL,
        created_at, updated_at
      FROM memory_fragments_v1
    ''');
    await db.execute('DROP TABLE memory_fragments_v1');
    // 4. FTS5 table — drop and rebuild to match new content
    await db.execute('DROP TABLE memory_fragments_fts');
    await db.execute('''
      CREATE VIRTUAL TABLE memory_fragments_fts USING fts5(
        id UNINDEXED, content, category,
        tokenize=porter
      )
    ''');
    // 5. Repopulate FTS from fragments
    await db.execute('''
      INSERT INTO memory_fragments_fts(id, content, category)
      SELECT id, content, category FROM memory_fragments
    ''');
    // 6. New tables
    await _createSummariesTable(db);
    await _createHebbianTable(db);
    // 7. Indexes
    await _createIndexes(db);
  }

  /// v2 → v3: add `source_message_id`, `source`, `extra_json` columns to
  /// `memory_fragments`. These are populated by the "Remember this" /
  /// "Forget" UI actions and let us link a fragment back to the
  /// originating chat message.
  Future<void> _upgradeV2ToV3(Database db) async {
    await db.execute(
      'ALTER TABLE memory_fragments ADD COLUMN source_message_id TEXT',
    );
    await db.execute(
      "ALTER TABLE memory_fragments ADD COLUMN source TEXT NOT NULL DEFAULT 'auto'",
    );
    await db.execute('ALTER TABLE memory_fragments ADD COLUMN extra_json TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_fragments_source_message_id '
      'ON memory_fragments(source_message_id)',
    );
  }

  Future<void> _createFragmentsV2(Database db) async {
    await db.execute('''
      CREATE TABLE memory_fragments (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'fact',
        is_active INTEGER NOT NULL DEFAULT 1,
        superseded_by TEXT,
        tier TEXT NOT NULL DEFAULT 'short',
        importance_score REAL NOT NULL DEFAULT 0.0,
        access_count INTEGER NOT NULL DEFAULT 0,
        last_access_at TEXT,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        media_refs TEXT,
        archived_at TEXT,
        summary_tier TEXT NOT NULL DEFAULT 'none',
        parent_summary_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE memory_fragments_fts USING fts5(
        id UNINDEXED, content, category,
        tokenize=porter
      )
    ''');
  }

  Future<void> _createSummariesTable(Database db) async {
    await db.execute('''
      CREATE TABLE memory_summaries (
        summary_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        summary_tier TEXT NOT NULL,
        source_tier TEXT NOT NULL,
        start_timestamp TEXT NOT NULL,
        end_timestamp TEXT NOT NULL,
        message_count INTEGER NOT NULL,
        source_record_ids TEXT NOT NULL,
        key_points TEXT NOT NULL,
        keywords TEXT NOT NULL,
        summary_text TEXT NOT NULL,
        quality_score REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createHebbianTable(Database db) async {
    await db.execute('''
      CREATE TABLE memory_hebbian_links (
        id TEXT PRIMARY KEY,
        fragment_a TEXT NOT NULL,
        fragment_b TEXT NOT NULL,
        strength REAL NOT NULL DEFAULT 0.1,
        stability REAL NOT NULL DEFAULT 1.0,
        co_access_count INTEGER NOT NULL DEFAULT 0,
        last_strengthened_at TEXT NOT NULL,
        UNIQUE(fragment_a, fragment_b)
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX idx_messages_session ON chat_messages(session_id)',
    );
    await db.execute(
      'CREATE INDEX idx_fragments_active ON memory_fragments(is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_fragments_tier ON memory_fragments(tier)',
    );
    await db.execute(
      'CREATE INDEX idx_fragments_pinned ON memory_fragments(is_pinned)',
    );
    await db.execute(
      'CREATE INDEX idx_summaries_tier ON memory_summaries(summary_tier)',
    );
    await db.execute(
      'CREATE INDEX idx_hebbian_a ON memory_hebbian_links(fragment_a)',
    );
    await db.execute(
      'CREATE INDEX idx_hebbian_b ON memory_hebbian_links(fragment_b)',
    );
  }

  // ─── Session management ────────────────────────────────────────────

  String get currentSessionId => _currentSessionId ?? _newSessionId();

  String _newSessionId() {
    _currentSessionId = _uuid.v4();
    return _currentSessionId!;
  }

  /// Start a brand-new session (for "New Conversation" button).
  void newSession() {
    _currentSessionId = _uuid.v4();
  }

  /// Set the active session id explicitly (e.g. when restoring a previous chat).
  void setSessionId(String id) {
    _currentSessionId = id;
  }

  /// Ensure the current session row exists in the database.
  Future<void> _ensureSession() async {
    final db = await database;
    final sid = currentSessionId;
    final exists = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [sid],
      limit: 1,
    );
    if (exists.isEmpty) {
      final now = DateTime.now().toIso8601String();
      await db.insert('chat_sessions', {
        'id': sid,
        'title': 'Chat ${now.substring(0, 16)}',
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ─── Message persistence (Layer 0) ─────────────────────────────────

  /// Persist a single message immediately. Called on every send/receive.
  /// Returns immediately after write — fire-and-forget safe against crashes.
  Future<void> saveMessage({
    required String role,
    required String content,
  }) async {
    await _ensureSession();
    final db = await database;
    await db.insert('chat_messages', {
      'id': _uuid.v4(),
      'session_id': currentSessionId,
      'role': role,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
    // Update session timestamp
    await db.update(
      'chat_sessions',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [currentSessionId],
    );
  }

  /// Get all messages for the current session, ordered by timestamp.
  Future<List<ChatRecord>> getSessionMessages({String? sessionId}) async {
    final db = await database;
    final sid = sessionId ?? currentSessionId;
    final rows = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sid],
      orderBy: 'timestamp ASC',
    );
    return rows.map(ChatRecord.fromJson).toList();
  }

  /// Get all sessions, most recent first.
  Future<List<ChatSession>> getAllSessions({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'chat_sessions',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => ChatSession(
            id: r['id'] as String,
            title: r['title'] as String,
            createdAt: DateTime.parse(r['created_at'] as String),
            updatedAt: DateTime.parse(r['updated_at'] as String),
          ),
        )
        .toList();
  }

  /// Get unconsolidated message count for dreaming trigger.
  Future<int> getUnconsolidatedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM chat_messages
      WHERE session_id = ?
    ''',
      [currentSessionId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Get recent messages for consolidation, limited by count.
  Future<List<ChatRecord>> getRecentMessages({int limit = 30}) async {
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [currentSessionId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(ChatRecord.fromJson).toList().reversed.toList();
  }

  // ─── Fragment CRUD (Layer 1) ───────────────────────────────────────

  /// Insert or replace a memory fragment.
  Future<void> upsertFragment(MemoryFragment fragment) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
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
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    final rows = await db.query(
      'memory_fragments',
      where: 'source_message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MemoryFragment.fromRow(rows.first);
  }

  /// Compact, paginated edge list for the Hebbian graph view. Returns
  /// the top [limit] strongest edges, descending. Used by the memory
  /// graph page to render the network.
  Future<List<HebbianEdge>> getTopHebbianEdges({int limit = 200}) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
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
    final db = await database;
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
    final db = await database;
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

  /// Mark a batch of fragments as accessed in a single transaction.
  Future<void> markAccessedBatch(Iterable<String> fragmentIds) async {
    final ids = fragmentIds.toList();
    if (ids.isEmpty) return;
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.rawUpdate(
          '''
          UPDATE memory_fragments
          SET access_count = access_count + 1, last_access_at = ?
          WHERE id = ?
          ''',
          [now, id],
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
    final db = await database;
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
          debugPrint('MemoryService.markAccessedBatch error: $e');
        }),
      );
      return results;
    } catch (e) {
      debugPrint('MemoryService FTS error for "$tokenized": $e');
      return [];
    }
  }

  /// Get all active fragments (for rebuilding or inspection).
  Future<List<MemoryFragment>> getAllActiveFragments() async {
    final db = await database;
    final rows = await db.query(
      'memory_fragments',
      where: 'is_active = 1',
      orderBy: 'updated_at DESC',
    );
    return rows.map(MemoryFragment.fromRow).toList();
  }

  /// Get active fragments in a specific tier, oldest first.
  Future<List<MemoryFragment>> getFragmentsInTier(
    MemoryTier tier, {
    int limit = 500,
  }) async {
    final db = await database;
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
    final db = await database;
    final rows = await db.query(
      'memory_fragments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MemoryFragment.fromRow(rows.first);
  }

  /// Get fragments that were previously active but might be related to new content.
  Future<List<MemoryFragment>> getFragmentsForConflictCheck(
    List<String> keywords, {
    int limit = 5,
  }) async {
    if (keywords.isEmpty) return [];
    final db = await database;
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
      debugPrint('MemoryService conflict check error: $e');
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

  // ─── Summary CRUD (Layer 1.5) ──────────────────────────────────────

  /// Persist a synthesized memory summary. Stored in its own table so it can
  /// be queried independently of fragments.
  Future<void> saveSummary(MemorySummary summary) async {
    final db = await database;
    await db.insert('memory_summaries', _summaryToRow(summary));
  }

  Future<void> saveSummaries(List<MemorySummary> summaries) async {
    if (summaries.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final s in summaries) {
        await txn.insert('memory_summaries', _summaryToRow(s));
      }
    });
  }

  /// Find summaries whose keywords or text match the given query.
  Future<List<MemorySummary>> searchSummaries(
    String query, {
    int limit = 5,
    List<MemorySummaryTier>? tiers,
  }) async {
    final db = await database;
    final tokenized = IndexStore.tokenizeForFts(query);
    if (tokenized.isEmpty) return [];
    final tierFilter = tiers == null || tiers.isEmpty
        ? null
        : tiers.map((t) => "'${t.name}'").join(',');
    final whereTier = tierFilter != null
        ? 'AND summary_tier IN ($tierFilter)'
        : '';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM memory_summaries
      WHERE (keywords LIKE ? OR summary_text LIKE ?) $whereTier
      ORDER BY end_timestamp DESC
      LIMIT ?
      ''',
      ['%$tokenized%', '%$tokenized%', limit],
    );
    return rows.map(_summaryFromRow).toList();
  }

  Map<String, Object?> _summaryToRow(MemorySummary s) => {
    'summary_id': s.summaryId,
    'user_id': s.userId,
    'summary_tier': s.summaryTier.name,
    'source_tier': s.sourceTier.name,
    'start_timestamp': s.startTimestamp.toIso8601String(),
    'end_timestamp': s.endTimestamp.toIso8601String(),
    'message_count': s.messageCount,
    'source_record_ids': s.sourceRecordIds.join('|'),
    'key_points': s.keyPoints.join('|'),
    'keywords': s.keywords.join('|'),
    'summary_text': s.summaryText,
    'quality_score': s.qualityScore,
    'created_at': s.createdAt.toIso8601String(),
    'updated_at': s.updatedAt.toIso8601String(),
  };

  MemorySummary _summaryFromRow(Map<String, Object?> r) {
    List<String> splitList(Object? raw) {
      final s = (raw as String?) ?? '';
      if (s.isEmpty) return const [];
      return s.split('|').where((e) => e.isNotEmpty).toList(growable: false);
    }

    return MemorySummary(
      summaryId: r['summary_id']! as String,
      userId: r['user_id']! as String,
      summaryTier: MemorySummaryTier.values.firstWhere(
        (t) => t.name == r['summary_tier'],
        orElse: () => MemorySummaryTier.l1,
      ),
      sourceTier: MemoryTier.values.firstWhere(
        (t) => t.name == r['source_tier'],
        orElse: () => MemoryTier.short,
      ),
      startTimestamp: DateTime.parse(r['start_timestamp']! as String),
      endTimestamp: DateTime.parse(r['end_timestamp']! as String),
      messageCount: r['message_count']! as int,
      sourceRecordIds: splitList(r['source_record_ids']),
      keyPoints: splitList(r['key_points']),
      keywords: splitList(r['keywords']),
      summaryText: r['summary_text']! as String,
      qualityScore: (r['quality_score'] as num?)?.toDouble(),
      createdAt: DateTime.parse(r['created_at']! as String),
      updatedAt: DateTime.parse(r['updated_at']! as String),
    );
  }

  // ─── Hebbian edge CRUD ─────────────────────────────────────────────

  /// Fetch all edges incident on a fragment (as either endpoint).
  Future<List<HebbianEdge>> getHebbianEdgesFor(String fragmentId) async {
    final db = await database;
    final rows = await db.query(
      'memory_hebbian_links',
      where: 'fragment_a = ? OR fragment_b = ?',
      whereArgs: [fragmentId, fragmentId],
    );
    return rows.map(HebbianEdge.fromRow).toList();
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
    final db = await database;
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
    final db = await database;
    return db.delete(
      'memory_hebbian_links',
      where: 'last_strengthened_at < ? AND co_access_count <= 1',
      whereArgs: [cutoff],
    );
  }

  // ─── Bulk session export ───────────────────────────────────────────

  /// Remove all messages for the current session (for "Clear Chat").
  Future<void> clearCurrentSession() async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [currentSessionId],
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
  }
}

/// A single Hebbian edge between two memory fragments.
///
/// Mirrors `insightConnections` in OpenLoomi's `hebbian.ts`.
class HebbianEdge {
  final String id;
  final String fragmentA;
  final String fragmentB;
  final double strength;
  final double stability;
  final int coAccessCount;
  final DateTime lastStrengthenedAt;

  const HebbianEdge({
    required this.id,
    required this.fragmentA,
    required this.fragmentB,
    required this.strength,
    required this.stability,
    required this.coAccessCount,
    required this.lastStrengthenedAt,
  });

  factory HebbianEdge.fromRow(Map<String, Object?> r) => HebbianEdge(
    id: r['id']! as String,
    fragmentA: r['fragment_a']! as String,
    fragmentB: r['fragment_b']! as String,
    strength: (r['strength'] as num).toDouble(),
    stability: (r['stability'] as num).toDouble(),
    coAccessCount: r['co_access_count']! as int,
    lastStrengthenedAt: DateTime.parse(r['last_strengthened_at']! as String),
  );

  /// The fragment on the *other* end of this edge from the perspective of
  /// the given fragment id. Returns null if `self` is not actually an
  /// endpoint of this edge.
  String? otherEnd(String self) {
    if (self == fragmentA) return fragmentB;
    if (self == fragmentB) return fragmentA;
    return null;
  }
}

// ─── Riverpod providers ──────────────────────────────────────────────

final memoryServiceProvider = Provider<MemoryService>((ref) {
  // Use the same path pattern as IndexStore
  final vaultState = ref.watch(vaultProvider);
  final dbPath = vaultState.currentVault != null
      ? p.join(vaultState.currentVault!.path, '.rfbrowser', 'memory.db')
      : p.join('rfbrowser_default', 'memory.db');
  final service = MemoryService(dbPath);
  ref.onDispose(() => service.close());
  return service;
});

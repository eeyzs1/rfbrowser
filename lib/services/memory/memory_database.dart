import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite connection for the memory subsystem and runs schema
/// migrations.
///
/// Exposed accessors:
/// - [database] — lazy, completer-guarded [Database] getter.
/// - [tryAcquireConsolidationLock] / [releaseConsolidationLock] —
///   process-wide single-flight lock for dreaming cycles.
///
/// Schema history:
/// - v1: initial fragments table.
/// - v2: progressive forgetting (tier / importance / access counters / pin)
///   + summaries + Hebbian edges.
/// - v3: `source_message_id`, `source`, `extra_json` on fragments.
/// - v4: `parent_summary_id` on summaries (L1 → L2 → L3 pyramid).
class MemoryDatabase {
  final String _dbPath;
  Database? _db;
  Completer<Database>? _initCompleter;

  /// Process-wide single-flight lock: when a consolidation cycle is in
  /// progress, subsequent callers return immediately rather than pile up.
  Completer<void>? _consolidationLock;

  MemoryDatabase(this._dbPath);

  /// Public accessor for the database path. Exposed so that
  /// [ChatHistoryExporter] (and any other service) can derive its output
  /// directory from the same root.
  String get path => _dbPath;

  Future<Database> get database async {
    if (_db != null) return _db!;
    // If initialization is already in progress, wait for the pending future
    // instead of racing into _initDb() a second time.
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<Database>();
    try {
      _db = await _initDb();
      _initCompleter!.complete(_db!);
      return _db!;
    } catch (e) {
      // Allow a subsequent call to retry initialization.
      _initCompleter = null;
      rethrow;
    }
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
      version: 4,
      onCreate: (db, version) async {
        await _createV2Schema(db);
        await _upgradeV2ToV3(db);
        await _upgradeV3ToV4(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeV1ToV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeV2ToV3(db);
        }
        if (oldVersion < 4) {
          await _upgradeV3ToV4(db);
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

  /// v3 → v4: add `parent_summary_id` to `memory_summaries` so the
  /// L1 → L2 → L3 pyramid can be linked. Also adds an index on the
  /// column to keep rollup queries cheap.
  Future<void> _upgradeV3ToV4(Database db) async {
    await db.execute(
      'ALTER TABLE memory_summaries ADD COLUMN parent_summary_id TEXT',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_summaries_parent_summary_id '
      'ON memory_summaries(parent_summary_id)',
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

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
  }
}

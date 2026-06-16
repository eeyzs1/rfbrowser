import 'dart:async';
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
/// Two-layer architecture:
///   Layer 0 — chat_messages: raw conversation logs (ground truth)
///   Layer 1 — memory_fragments + memory_fragments_fts: synthesized, searchable
///
/// Messages are persisted synchronously on every send/receive.
/// Fragments are created asynchronously by [DreamingService].
class MemoryService {
  final String _dbPath;
  Database? _db;
  Completer<Database>? _initCompleter;
  String? _currentSessionId;

  MemoryService(this._dbPath);

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

  Future<Database> _initDb() async {
    final dir = Directory(p.dirname(_dbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return openDatabase(
      _dbPath,
      version: 1,
      onCreate: (db, version) async {
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
        await db.execute('''
          CREATE TABLE memory_fragments (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            content TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'fact',
            is_active INTEGER NOT NULL DEFAULT 1,
            superseded_by TEXT,
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
        await db.execute(
          'CREATE INDEX idx_messages_session ON chat_messages(session_id)',
        );
        await db.execute(
          'CREATE INDEX idx_fragments_active ON memory_fragments(is_active)',
        );
      },
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

  /// Search active memory fragments using FTS5.
  Future<List<MemoryFragment>> searchFragments(
    String query, {
    int limit = 5,
  }) async {
    final db = await database;
    final tokenized = IndexStore.tokenizeForFts(query);
    if (tokenized.isEmpty) return [];
    try {
      final rows = await db.rawQuery(
        '''
        SELECT f.* FROM memory_fragments f
        INNER JOIN memory_fragments_fts ft ON ft.id = f.id
        WHERE memory_fragments_fts MATCH ?
          AND f.is_active = 1
        ORDER BY rank
        LIMIT ?
      ''',
        [tokenized, limit],
      );
      return rows.map(MemoryFragment.fromRow).toList();
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

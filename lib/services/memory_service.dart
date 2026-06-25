import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/models/chat_memory.dart';
import '../data/stores/vault_store.dart';
import 'memory/memory_database.dart';
import 'memory/fragment_repository.dart';
import 'memory/summary_repository.dart';
import 'memory/hebbian_edge_repository.dart';
import 'memory/memory_backup_service.dart';

const _uuid = Uuid();

/// Persistent storage for chat messages and synthesized memory fragments.
///
/// This is now a thin facade over [MemoryDatabase], [FragmentRepository],
/// [SummaryRepository], [HebbianEdgeRepository] and [MemoryBackupService].
/// The public API is preserved verbatim so existing callers (including
/// tests) keep working unchanged.
///
/// Schema v2 (progressive forgetting):
///   - memory_fragments: adds tier / importance / access counters / pin
///   - memory_summaries: L1/L2/L3 consolidated summaries
///   - memory_hebbian_links: co-access reinforcement edges
///
/// Messages are persisted synchronously on every send/receive.
/// Fragments are created asynchronously by [DreamingService].
class MemoryService {
  final MemoryDatabase _database;
  late final FragmentRepository _fragments;
  late final SummaryRepository _summaries;
  late final HebbianEdgeRepository _hebbian;
  late final MemoryBackupService _backup;
  String? _currentSessionId;

  MemoryService(String dbPath) : _database = MemoryDatabase(dbPath) {
    _fragments = FragmentRepository(_database);
    _summaries = SummaryRepository(_database);
    _hebbian = HebbianEdgeRepository(_database);
    _backup = MemoryBackupService(_database);
  }

  /// Public accessor for the database path. Exposed so that
  /// [ChatHistoryExporter] (and any other service) can derive its output
  /// directory from the same root.
  String get databasePath => _database.path;

  // ─── Database init ─────────────────────────────────────────────────

  Future<Database> get database => _database.database;

  /// Acquire a process-wide lock. Returns null if a consolidation is already
  /// running; callers should treat null as "someone else is doing it" and
  /// skip their work.
  Future<Completer<void>?> tryAcquireConsolidationLock() =>
      _database.tryAcquireConsolidationLock();

  void releaseConsolidationLock(Completer<void> lock) =>
      _database.releaseConsolidationLock(lock);

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

  // ─── Fragment CRUD (Layer 1) — delegated ───────────────────────────

  Future<void> upsertFragment(MemoryFragment fragment) =>
      _fragments.upsertFragment(fragment);

  Future<void> deactivateFragment(
    String fragmentId, {
    String? supersededBy,
  }) => _fragments.deactivateFragment(fragmentId, supersededBy: supersededBy);

  Future<int> deleteFragment(String fragmentId) =>
      _fragments.deleteFragment(fragmentId);

  Future<String> addFragmentFromMessage({
    required String sessionId,
    required String messageId,
    required String content,
    double importance = 0.7,
    String source = 'manual',
    Map<String, Object?>? extra,
  }) => _fragments.addFragmentFromMessage(
    sessionId: sessionId,
    messageId: messageId,
    content: content,
    importance: importance,
    source: source,
    extra: extra,
  );

  Future<int> forgetFragment(String fragmentId) =>
      _fragments.forgetFragment(fragmentId);

  Future<MemoryFragment?> getFragmentByMessageId(String? messageId) =>
      _fragments.getFragmentByMessageId(messageId);

  Future<void> transitionFragmentTier(
    String fragmentId, {
    required MemoryTier newTier,
    required DateTime transitionedAt,
    String? summaryId,
    bool archive = false,
  }) => _fragments.transitionFragmentTier(
    fragmentId,
    newTier: newTier,
    transitionedAt: transitionedAt,
    summaryId: summaryId,
    archive: archive,
  );

  Future<void> setPinned(String fragmentId, bool pinned) =>
      _fragments.setPinned(fragmentId, pinned);

  Future<void> markAccessed(String fragmentId) =>
      _fragments.markAccessed(fragmentId);

  Future<void> markAccessedBatch(Iterable<String> fragmentIds) =>
      _fragments.markAccessedBatch(fragmentIds);

  Future<List<MemoryFragment>> searchFragments(
    String query, {
    int limit = 5,
    List<MemoryTier>? tiers,
  }) => _fragments.searchFragments(query, limit: limit, tiers: tiers);

  Future<List<FragmentMatch>> searchFragmentsWithScores(
    String query, {
    int limit = 5,
  }) => _fragments.searchFragmentsWithScores(query, limit: limit);

  Future<List<MemoryFragment>> getAllActiveFragments() =>
      _fragments.getAllActiveFragments();

  Future<List<MemoryFragment>> getFragmentsInTier(
    MemoryTier tier, {
    int limit = 500,
  }) => _fragments.getFragmentsInTier(tier, limit: limit);

  Future<MemoryFragment?> getFragment(String id) => _fragments.getFragment(id);

  Future<List<MemoryFragment>> getFragmentsBatch(Iterable<String> ids) =>
      _fragments.getFragmentsBatch(ids);

  Future<List<MemoryFragment>> getFragmentsForConflictCheck(
    List<String> keywords, {
    int limit = 5,
  }) => _fragments.getFragmentsForConflictCheck(keywords, limit: limit);

  /// Build a formatted context string from relevant fragments for system prompt.
  static String formatFragmentsForContext(List<MemoryFragment> fragments) =>
      FragmentRepository.formatFragmentsForContext(fragments);

  // ─── Summary CRUD (Layer 1.5) — delegated ──────────────────────────

  Future<void> saveSummary(MemorySummary summary) =>
      _summaries.saveSummary(summary);

  Future<void> saveSummaries(List<MemorySummary> summaries) =>
      _summaries.saveSummaries(summaries);

  Future<List<MemorySummary>> searchSummaries(
    String query, {
    int limit = 5,
    List<MemorySummaryTier>? tiers,
  }) => _summaries.searchSummaries(query, limit: limit, tiers: tiers);

  // ─── Hebbian edge CRUD — delegated ─────────────────────────────────

  Future<List<HebbianEdge>> getHebbianEdgesFor(String fragmentId) =>
      _hebbian.getHebbianEdgesFor(fragmentId);

  Future<List<HebbianEdge>> getHebbianEdgesForBatch(Iterable<String> ids) =>
      _hebbian.getHebbianEdgesForBatch(ids);

  Future<List<HebbianEdge>> getTopHebbianEdges({int limit = 200}) =>
      _hebbian.getTopHebbianEdges(limit: limit);

  Future<List<MemoryFragment>> getNetworkedFragments({int limit = 200}) =>
      _hebbian.getNetworkedFragments(limit: limit);

  /// Tokenize a fragment's content into a small keyword set used for
  /// cross-session association. Delegates to [HebbianEdgeRepository].
  static List<String> tokenizeForCrossSession(String content, {int limit = 8}) =>
      HebbianEdgeRepository.tokenizeForCrossSession(content, limit: limit);

  Future<List<({MemoryFragment fragment, int overlap})> >
  findCrossSessionAssociates(
    String fragmentId, {
    int minKeywordOverlap = 2,
    int limit = 5,
  }) => _hebbian.findCrossSessionAssociates(
    fragmentId,
    minKeywordOverlap: minKeywordOverlap,
    limit: limit,
  );

  Future<void> upsertHebbianEdge(
    String fragmentA,
    String fragmentB, {
    required double strengthDelta,
    required double stability,
    required DateTime now,
  }) => _hebbian.upsertHebbianEdge(
    fragmentA,
    fragmentB,
    strengthDelta: strengthDelta,
    stability: stability,
    now: now,
  );

  Future<void> upsertHebbianEdgesBatch(
    List<(String, String)> pairs, {
    required double strengthDelta,
    required double stability,
    required DateTime now,
  }) => _hebbian.upsertHebbianEdgesBatch(
    pairs,
    strengthDelta: strengthDelta,
    stability: stability,
    now: now,
  );

  Future<int> deleteStaleHebbianEdges({
    Duration olderThan = const Duration(days: 90),
    DateTime? now,
  }) => _hebbian.deleteStaleHebbianEdges(olderThan: olderThan, now: now);

  // ─── JSON backup / restore — delegated ─────────────────────────────

  Future<Map<String, Object?>> exportToJson({
    DateTime? now,
    int schemaVersion = 4,
  }) => _backup.exportToJson(now: now, schemaVersion: schemaVersion);

  Future<({int fragments, int summaries, int hebbianEdges})> importFromJson(
    Map<String, Object?> json, {
    bool replaceExisting = false,
  }) => _backup.importFromJson(json, replaceExisting: replaceExisting);

  // ─── Session cleanup ───────────────────────────────────────────────

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
  Future<void> close() => _database.close();
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

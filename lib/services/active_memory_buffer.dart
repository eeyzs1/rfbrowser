import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/memory_service.dart';

/// In-memory per-session "active working memory" — a small, pinned
/// buffer of fragment ids that the user is currently focused on for
/// this session. Distinct from the persistent `memory_fragments` and
/// from the LLM context:
///   - It's RAM-only (resets when the app starts)
///   - It's per-session (cleared on session switch)
///   - It's explicit (the user adds/removes ids via the UI)
///   - It bypasses the budget cap so the most important fragments
///     are always available
///
/// Inspired by OpenLoomi's "active working memory" concept. Default
/// capacity is 8 ids; older ones are evicted LRU.
class ActiveMemoryBuffer {
  final MemoryService _memory;
  ActiveMemoryBuffer(this._memory);

  final Map<String, _Buffer> _buffers = {};
  static const int defaultCapacity = 8;

  /// Add (or refresh) a fragment id in [sessionId]'s buffer. Promotes
  /// the id to most-recently used. If the buffer is full, the LRU id
  /// is evicted. Returns the (possibly new) contents of the buffer.
  Future<List<MemoryFragment>> add(
    String sessionId,
    String fragmentId, {
    int capacity = defaultCapacity,
  }) async {
    final buffer = _buffers.putIfAbsent(
      sessionId,
      () => _Buffer(capacity: capacity),
    );
    buffer.touch(fragmentId);
    if (buffer.length > capacity) {
      buffer.evictLru();
    }
    return _resolve(buffer);
  }

  /// Remove a fragment id from [sessionId]'s buffer.
  Future<List<MemoryFragment>> remove(
    String sessionId,
    String fragmentId,
  ) async {
    final buffer = _buffers[sessionId];
    if (buffer == null) return const [];
    buffer.remove(fragmentId);
    return _resolve(buffer);
  }

  /// Drop the entire buffer for [sessionId] (e.g. on session switch
  /// or clear-history).
  Future<void> clear(String sessionId) async {
    _buffers.remove(sessionId);
  }

  /// Get the active buffer for [sessionId], in MRU order. Resolves
  /// ids to full fragments via the database.
  Future<List<MemoryFragment>> getActive(String sessionId) async {
    final buffer = _buffers[sessionId];
    if (buffer == null) return const [];
    return _resolve(buffer);
  }

  /// Convenience: list of fragment ids in MRU order, no DB lookups.
  List<String> activeIds(String sessionId) {
    return List.unmodifiable(_buffers[sessionId]?.ids ?? const []);
  }

  Future<List<MemoryFragment>> _resolve(_Buffer buffer) async {
    if (buffer.isEmpty) return const [];
    final db = await _memory.database;
    final placeholders = List.filled(buffer.ids.length, '?').join(',');
    final rows = await db.query(
      'memory_fragments',
      where: 'id IN ($placeholders) AND is_active = 1',
      whereArgs: buffer.ids,
    );
    final out = rows.map(MemoryFragment.fromRow).toList();
    // Preserve MRU order.
    out.sort(
      (a, b) => buffer.ids.indexOf(a.id).compareTo(buffer.ids.indexOf(b.id)),
    );
    return out;
  }
}

class _Buffer {
  final int capacity;
  final List<String> ids = [];
  _Buffer({required this.capacity});

  int get length => ids.length;
  bool get isEmpty => ids.isEmpty;

  void touch(String id) {
    ids.remove(id);
    ids.insert(0, id);
  }

  void evictLru() {
    if (ids.isNotEmpty) ids.removeLast();
  }

  void remove(String id) {
    ids.remove(id);
  }
}

/// Riverpod provider for the per-session active memory buffer.
final activeMemoryBufferProvider = Provider<ActiveMemoryBuffer>((ref) {
  final memory = ref.watch(memoryServiceProvider);
  return ActiveMemoryBuffer(memory);
});

/// Helper used by AIService — given a user message, compute the final
/// `setFragmentIds` payload to inject into the system prompt, where
/// the active buffer takes precedence over the budget-trimmed
/// recalled set. Returns a list of fragment ids in priority order.
Future<List<String>> resolveActiveMemoryIds({
  required ActiveMemoryBuffer buffer,
  required String sessionId,
  required List<String> recalledIds,
}) async {
  final out = <String>[];
  final seen = <String>{};
  for (final id in [...buffer.activeIds(sessionId), ...recalledIds]) {
    if (seen.add(id)) out.add(id);
  }
  // Cap the result. Active memory is always preserved, recalled is
  // appended but truncated.
  const cap = 12;
  return out.length > cap ? out.sublist(0, cap) : out;
}

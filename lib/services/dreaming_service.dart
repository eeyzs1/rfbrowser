import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/ai_provider.dart';
import '../data/models/chat_memory.dart';
import 'memory_service.dart';
import 'dio_factory.dart';
import 'settings_service.dart';

const _uuid = Uuid();

/// Background service that synthesizes memory fragments from raw chat messages.
///
/// Inspired by OpenAI's Dreaming V3 architecture:
///   1. Collect raw messages (Layer 0 — already persisted by MemoryService)
///   2. Consolidate: extract fragments, detect conflicts, merge/update
///   3. Store synthesized fragments (Layer 1 — searchable via FTS5)
///
/// Triggered when:
///   - N new messages accumulate since last consolidation (default: 8)
///   - App idle timer fires (default: 30s after last message)
class DreamingService {
  final MemoryService _memory;
  final Dio _dio = DioFactory.instance;
  int _lastConsolidatedCount = 0;
  Timer? _idleTimer;
  bool _isConsolidating = false;

  /// Threshold: trigger consolidation after this many new messages.
  static const int messageThreshold = 8;

  /// Idle time before triggering consolidation (when app is quiet).
  static const Duration idleDuration = Duration(seconds: 30);

  DreamingService(this._memory);

  // ─── Public API ────────────────────────────────────────────────────

  /// Call after each message persistence. Checks threshold and idle timer.
  void onMessageSaved() {
    _resetIdleTimer();
    _checkThreshold();
  }

  /// Call when the user is done chatting (panel collapses, etc.).
  void onUserInactive() {
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
        debugPrint('DreamingService threshold check error: $e');
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
      debugPrint('DreamingService idle consolidate error: $e');
    }
  }

  // ─── Core consolidation ────────────────────────────────────────────

  Future<void> _consolidate() async {
    if (_isConsolidating) return;
    _isConsolidating = true;

    try {
      final messages = await _memory.getRecentMessages(limit: 30);
      if (messages.isEmpty) {
        _lastConsolidatedCount = 0;
        return;
      }

      final existingFragments = await _memory.getAllActiveFragments();

      final result = await _callDreamingLLM(messages, existingFragments);
      if (result == null) return;

      await _applyDreamingResult(result);
      _lastConsolidatedCount = await _memory.getUnconsolidatedCount();
      debugPrint(
        'DreamingService: consolidated ${result.newFragments.length} new, '
        '${result.supersededIds.length} superseded',
      );
    } catch (e) {
      debugPrint('DreamingService consolidation error: $e');
    } finally {
      _isConsolidating = false;
    }
  }

  // ─── LLM call ──────────────────────────────────────────────────────

  /// Call the configured LLM to extract memory fragments from recent messages.
  Future<_DreamingResult?> _callDreamingLLM(
    List<ChatRecord> messages,
    List<MemoryFragment> existingFragments,
  ) async {
    final provider = _provider;
    final model = _model;
    if (provider == null || model == null) {
      debugPrint('DreamingService: no AI provider configured, skipping');
      return null;
    }

    final prompt = _buildDreamingPrompt(messages, existingFragments);

    try {
      final response = await _dio.post(
        provider.chatEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ...provider.authHeaders(),
          },
        ),
        data: jsonEncode({
          'model': model.id,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 1024,
        }),
      );

      final content = _extractContent(response.data, provider.protocol);
      if (content == null) {
        debugPrint('DreamingService: empty response from LLM');
        return null;
      }
      return _parseDreamingResponse(content);
    } on DioException catch (e) {
      debugPrint('DreamingService LLM error: ${e.message}');
      return null;
    }
  }

  /// Build the dreaming prompt based on recent messages and existing fragments.
  String _buildDreamingPrompt(
    List<ChatRecord> messages,
    List<MemoryFragment> existingFragments,
  ) {
    final recent = messages.map((m) => '${m.role}: ${m.content}').join('\n');

    final existing = existingFragments.isNotEmpty
        ? '\nExisting memories about the user:\n${existingFragments.map((f) => '- [${f.category}] ${f.content} (id: ${f.id})').join('\n')}'
        : '\nNo existing memories.';

    return '''
Recent conversation:
$recent

$existing

Extract new facts about the user from the recent conversation. Output JSON only, no explanation.
''';
  }

  // ─── Response parsing ──────────────────────────────────────────────

  _DreamingResult? _parseDreamingResponse(String content) {
    try {
      // Extract JSON from potential markdown code blocks
      var jsonStr = content.trim();
      if (jsonStr.startsWith('```')) {
        final start = jsonStr.indexOf('\n');
        final end = jsonStr.lastIndexOf('```');
        if (start > 0 && end > start) {
          jsonStr = jsonStr.substring(start, end).trim();
        }
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final newFragments = <_FragmentData>[];
      final fragments = json['new_fragments'] as List<dynamic>? ?? [];
      for (final f in fragments) {
        final fMap = f as Map<String, dynamic>;
        newFragments.add(
          _FragmentData(
            content: fMap['content'] as String? ?? '',
            category: fMap['category'] as String? ?? 'fact',
          ),
        );
      }

      final superseded = <String>[];
      final supersededList = json['superseded_ids'] as List<dynamic>? ?? [];
      for (final s in supersededList) {
        superseded.add(s.toString());
      }

      final updated = <_FragmentData>[];
      final updatedList = json['updated_fragments'] as List<dynamic>? ?? [];
      for (final u in updatedList) {
        final uMap = u as Map<String, dynamic>;
        updated.add(
          _FragmentData(
            content: uMap['content'] as String? ?? '',
            category: uMap['category'] as String? ?? 'fact',
            supersedesId: uMap['supersedes_id'] as String?,
          ),
        );
      }

      return _DreamingResult(
        newFragments: newFragments,
        supersededIds: superseded,
        updatedFragments: updated,
      );
    } catch (e) {
      debugPrint('DreamingService parse error: $e\nContent: $content');
      return null;
    }
  }

  // ─── Apply results ─────────────────────────────────────────────────

  Future<void> _applyDreamingResult(_DreamingResult result) async {
    final now = DateTime.now();

    // Mark superseded fragments
    for (final id in result.supersededIds) {
      await _memory.deactivateFragment(id);
    }

    // Update existing fragments
    for (final u in result.updatedFragments) {
      if (u.supersedesId != null) {
        await _memory.deactivateFragment(u.supersedesId!);
      }
      final fragment = MemoryFragment(
        id: _uuid.v4(),
        sessionId: _memory.currentSessionId,
        content: u.content,
        category: u.category,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await _memory.upsertFragment(fragment);
    }

    // Insert new fragments
    for (final n in result.newFragments) {
      if (n.content.isEmpty) continue;
      final fragment = MemoryFragment(
        id: _uuid.v4(),
        sessionId: _memory.currentSessionId,
        content: n.content,
        category: n.category,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await _memory.upsertFragment(fragment);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  String? _extractContent(dynamic data, ApiProtocol protocol) {
    try {
      switch (protocol) {
        case ApiProtocol.openaiCompatible:
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            return choices[0]['message']?['content'] as String?;
          }
          return null;
        case ApiProtocol.anthropic:
          final content = data['content'] as List<dynamic>?;
          if (content != null && content.isNotEmpty) {
            return content[0]?['text'] as String?;
          }
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  // Will be set by the Provider to give access to AI config.
  AIProvider? _provider;
  AIModel? _model;

  void configureAI({AIProvider? provider, AIModel? model}) {
    _provider = provider;
    _model = model;
  }
}

// ─── Data classes ────────────────────────────────────────────────────

class _FragmentData {
  final String content;
  final String category;
  final String? supersedesId;

  _FragmentData({
    required this.content,
    this.category = 'fact',
    this.supersedesId,
  });
}

class _DreamingResult {
  final List<_FragmentData> newFragments;
  final List<String> supersededIds;
  final List<_FragmentData> updatedFragments;

  _DreamingResult({
    this.newFragments = const [],
    this.supersededIds = const [],
    this.updatedFragments = const [],
  });
}

// ─── System prompt ───────────────────────────────────────────────────

const _systemPrompt = '''
You are a memory consolidation system. Your job is to extract key facts about the user from recent conversations and merge them with existing knowledge.

Output a JSON object with these fields:
- "new_fragments": array of NEW facts not yet in existing memories. Each has "content" (1-2 sentences) and "category" (one of: fact, preference, project, constraint, context).
- "superseded_ids": array of existing fragment IDs that are now OUTDATED or CONTRADICTED by new information.
- "updated_fragments": array of updated versions of existing fragments. Each has "content", "category", and "supersedes_id" (the old fragment ID being replaced).

Rules:
1. Extract facts that will be useful across sessions. Skip trivial chat.
2. If the user says something that contradicts an existing memory, supersede the old one.
3. If the user provides updated info on a topic, merge it into a single updated fragment.
4. Each fragment should be a self-contained statement (1-2 sentences).
5. "fact" = objective information about the user. "preference" = likes/dislikes. "project" = ongoing work. "constraint" = limitations/requirements. "context" = situational info.
6. Output ONLY valid JSON, no markdown, no explanation.
''';

// ─── Riverpod provider ───────────────────────────────────────────────

final dreamingServiceProvider = Provider<DreamingService>((ref) {
  final memory = ref.read(memoryServiceProvider);
  final service = DreamingService(memory);

  // Configure AI access from current settings
  final aiConfig = ref.read(aiConfigProvider);
  final provider = aiConfig.activeProvider;
  final model = aiConfig.activeModel;
  if (provider != null && model != null) {
    service.configureAI(provider: provider, model: model);
  }

  ref.onDispose(() => service.dispose());
  return service;
});

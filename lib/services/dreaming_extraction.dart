part of 'dreaming_service.dart';

/// LLM-assisted fragment extraction. Pulled out of the main
/// `DreamingService` body so the core consolidation flow stays readable.
mixin _DreamingExtractionMixin on _DreamingServiceBase {
  Future<_ExtractionResult?> _extractFragments(
    List<ChatRecord> messages,
    List<MemoryFragment> existingFragments,
  ) async {
    final provider = _provider;
    final model = _model;
    if (provider == null || model == null) {
      // Without a provider we can't extract facts. Run the forgetting
      // engine anyway so the user still gets tier migration.
      return _ExtractionResult(
        newFragments: const [],
        supersededIds: const [],
        updatedFragments: const [],
      );
    }

    final prompt = _buildExtractionPrompt(messages, existingFragments);
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
            {'role': 'system', 'content': _extractionSystemPrompt},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': _sampling.dreamingTemperature,
          'max_tokens': _sampling.dreamingMaxTokens,
        }),
      );
      final content = _extractContent(response.data, provider.protocol);
      if (content == null) {
        appLog.warning('DreamingService: empty extraction response from LLM');
        return null;
      }
      return _parseExtractionResponse(content);
    } on DioException catch (e) {
      appLog.error('DreamingService LLM error', error: e);
      return null;
    }
  }

  String _buildExtractionPrompt(
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

  _ExtractionResult? _parseExtractionResponse(String content) {
    try {
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
            importance: (fMap['importance'] as num?)?.toDouble() ?? 0.0,
            mediaRefs: _stringList(fMap['media_refs']),
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
            importance: (uMap['importance'] as num?)?.toDouble() ?? 0.0,
            mediaRefs: _stringList(uMap['media_refs']),
            supersedesId: uMap['supersedes_id'] as String?,
          ),
        );
      }

      return _ExtractionResult(
        newFragments: newFragments,
        supersededIds: superseded,
        updatedFragments: updated,
      );
    } catch (e) {
      appLog.error('DreamingService parse error\nContent: $content', error: e);
      return null;
    }
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _applyExtractionResult(_ExtractionResult result) async {
    final now = DateTime.now();

    for (final id in result.supersededIds) {
      await _memory.deactivateFragment(id);
    }
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
        tier: MemoryTier.short,
        importanceScore: u.importance,
        mediaRefs: u.mediaRefs,
        createdAt: now,
        updatedAt: now,
      );
      await _memory.upsertFragment(fragment);
    }
    for (final n in result.newFragments) {
      if (n.content.isEmpty) continue;
      final fragment = MemoryFragment(
        id: _uuid.v4(),
        sessionId: _memory.currentSessionId,
        content: n.content,
        category: n.category,
        isActive: true,
        tier: MemoryTier.short,
        importanceScore: n.importance,
        mediaRefs: n.mediaRefs,
        createdAt: now,
        updatedAt: now,
      );
      await _memory.upsertFragment(fragment);
    }
  }

  // ─── Response parsing helpers ──────────────────────────────────────

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

  static const String _extractionSystemPrompt = '''
You are a memory extraction assistant. Identify facts about the user from the conversation
and return them as compact JSON fragments. Use short, declarative sentences.
If the conversation adds no new facts, return an empty list.
''';
}

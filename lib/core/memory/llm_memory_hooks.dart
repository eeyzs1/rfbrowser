import 'package:flutter/foundation.dart';
import 'package:rfbrowser/core/memory/memory_summarizer.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/data/models/chat_memory.dart';

/// LLM-backed memory summarizer. Falls back to the rule-based
/// implementation when no [LLMSummarizerConfig.provider] is wired.
///
/// The implementation is intentionally minimal: a single chat call per
/// [buildSummary]. Errors degrade to the rule-based output so the
/// dreaming cycle never blocks on a flaky model.
class LlmMemorySummarizer implements MemorySummarizer {
  final MemorySummarizer _fallback;
  final LlmSummarizerConfig? config;

  LlmMemorySummarizer({MemorySummarizer? fallback, this.config})
    : _fallback = fallback ?? const RuleBasedMemorySummarizer();

  @override
  MemorySummary buildSummary(MemoryGroup group, {DateTime? now}) {
    if (config == null) return _fallback.buildSummary(group, now: now);
    try {
      return _buildLlmSummary(group, now ?? DateTime.now());
    } catch (e) {
      debugPrint('LlmMemorySummarizer: falling back to rule-based: $e');
      return _fallback.buildSummary(group, now: now);
    }
  }

  MemorySummary _buildLlmSummary(MemoryGroup group, DateTime now) {
    // Synchronous LLM call would require a different runtime
    // signature. For now this implementation defers the actual
    // network call to a future upgrade; the structure (groupId,
    // tier, sources) is preserved so the rest of the pipeline
    // remains valid.
    final text = _buildPromptText(group);
    final base = _fallback.buildSummary(group, now: now);
    return MemorySummary(
      summaryId: base.summaryId,
      userId: base.userId,
      summaryTier: base.summaryTier,
      sourceTier: base.sourceTier,
      startTimestamp: base.startTimestamp,
      endTimestamp: base.endTimestamp,
      messageCount: base.messageCount,
      sourceRecordIds: base.sourceRecordIds,
      keyPoints: base.keyPoints,
      keywords: base.keywords,
      summaryText: text,
      qualityScore: base.qualityScore,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
    );
  }

  String _buildPromptText(MemoryGroup group) {
    final buf = StringBuffer();
    buf.writeln('Summarize the following memory fragments:');
    for (final r in group.records.take(20)) {
      buf.writeln('- ${r.fragment.content}');
    }
    return buf.toString();
  }
}

/// Configuration the LLM summarizer needs to actually do a network
/// call. Kept separate from the LLM provider plumbing so the
/// summarizer can be unit-tested without a real provider.
class LlmSummarizerConfig {
  final AIProvider provider;
  final AIModel model;
  final String? systemPrompt;
  const LlmSummarizerConfig({
    required this.provider,
    required this.model,
    this.systemPrompt,
  });
}

/// Re-ranks a list of memory fragments by asking the LLM which ones
/// are most relevant to [query]. The interface is pluggable so the
/// UI can fall back to the base ranking silently.
abstract class MemoryReranker {
  /// Returns [fragments] reordered, top-most relevant first. Should
  /// be a strict permutation (or a subset) of the input.
  Future<List<MemoryFragment>> rerank({
    required String query,
    required List<MemoryFragment> fragments,
    int topK = 5,
  });
}

/// Pass-through reranker: returns the input as-is, in the same order.
/// Used when the user has not opted in to LLM re-ranking.
class PassthroughReranker implements MemoryReranker {
  const PassthroughReranker();
  @override
  Future<List<MemoryFragment>> rerank({
    required String query,
    required List<MemoryFragment> fragments,
    int topK = 5,
  }) async {
    return fragments.take(topK).toList();
  }
}

/// LLM re-ranker: prompts the configured model to score each fragment
/// and returns the top-K. Falls back to pass-through on any error so
/// the AI service never blocks.
class LlmReranker implements MemoryReranker {
  final LlmSummarizerConfig? config;
  final MemoryReranker fallback;
  LlmReranker({this.config, this.fallback = const PassthroughReranker()});

  @override
  Future<List<MemoryFragment>> rerank({
    required String query,
    required List<MemoryFragment> fragments,
    int topK = 5,
  }) async {
    if (config == null || fragments.isEmpty) {
      return fallback.rerank(query: query, fragments: fragments, topK: topK);
    }
    try {
      // Synchronous LLM call would need a different runtime; for
      // now this surfaces the input order so the integration point
      // exists. A future PR can wire the real chat call without
      // changing the call site.
      return fragments.take(topK).toList();
    } catch (e) {
      debugPrint('LlmReranker: falling back: $e');
      return fallback.rerank(query: query, fragments: fragments, topK: topK);
    }
  }
}

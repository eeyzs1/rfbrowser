import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/chat_memory.dart';
import '../../data/models/note.dart';

/// Bumped whenever the on-disk shape of an embedding document changes.
/// Embedding caches can compare this version against the version that
/// produced their stored vector and re-embed when mismatched.
@visibleForTesting
const String memoryRecordEmbeddingTextVersion = 'memory-record-embedding-text-v1';
@visibleForTesting
const String noteEmbeddingTextVersion = 'note-embedding-text-v1';

const int _defaultMaxTextLength = 8_000;

/// A document ready to be embedded.
///
/// `contentHash` is a 64-bit FNV-1a hash of the normalized content. Callers
/// use it to deduplicate vectors and to detect when a re-embed is needed
/// after a content edit.
class EmbeddingDocument {
  final String content;
  final String contentHash;
  final String textVersion;

  const EmbeddingDocument({
    required this.content,
    required this.contentHash,
    required this.textVersion,
  });
}

/// Build a multi-section, deterministic string representation of a memory
/// fragment, note, or chat message ready for embedding.
///
/// The shape mirrors OpenLoomi's `buildMemoryRecordEmbeddingText` so the
/// same downstream vector store can serve both RFBrowser and OpenLoomi
/// payloads.
class EmbeddingDocumentBuilder {
  final int maxLength;

  const EmbeddingDocumentBuilder({this.maxLength = _defaultMaxTextLength});

  /// Build a document for a memory fragment. Sections included: text,
  /// tier, summary tier, importance, media, access stats, and a small
  /// number of structured dimensions.
  EmbeddingDocument buildForFragment(MemoryFragment fragment) {
    final sections = <String>[];
    _appendSection(sections, 'Text', fragment.content);
    _appendSection(sections, 'Time', fragment.createdAt.toIso8601String());
    _appendSection(sections, 'Tier', fragment.tier.name);
    _appendSection(
      sections,
      'SummaryTier',
      fragment.summaryTier == MemorySummaryTier.none
          ? null
          : fragment.summaryTier.name,
    );
    _appendSection(sections, 'Category', fragment.category);
    _appendSection(
      sections,
      'Importance',
      fragment.importanceScore.toStringAsFixed(2),
    );
    _appendSection(
      sections,
      'Pinned',
      fragment.isPinned ? 'true' : 'false',
    );
    _appendSection(
      sections,
      'AccessCount',
      fragment.accessCount.toString(),
    );
    if (fragment.mediaRefs.isNotEmpty) {
      _appendSection(sections, 'Media', fragment.mediaRefs);
    }
    return _build(sections, memoryRecordEmbeddingTextVersion);
  }

  /// Build a document for a vault note.
  EmbeddingDocument buildForNote(Note note) {
    final sections = <String>[];
    _appendSection(sections, 'Text', '${note.title}\n${note.content}');
    _appendSection(sections, 'Time', note.modified.toIso8601String());
    _appendSection(sections, 'Path', note.filePath);
    if (note.tags.isNotEmpty) {
      _appendSection(sections, 'Tags', note.tags);
    }
    return _build(sections, noteEmbeddingTextVersion);
  }

  /// Build a document for a chat message (used by search indexer).
  EmbeddingDocument buildForChatMessage(ChatRecord record) {
    final sections = <String>[];
    _appendSection(sections, 'Text', record.content);
    _appendSection(sections, 'Time', record.timestamp.toIso8601String());
    _appendSection(sections, 'Role', record.role);
    return _build(sections, memoryRecordEmbeddingTextVersion);
  }

  // ─── Internals ────────────────────────────────────────────────────

  void _appendSection(
    List<String> sections,
    String label,
    Object? value,
  ) {
    final flat = _flattenValue(value);
    if (flat.isEmpty) return;
    sections.add('$label: ${_dedupePreserveOrder(flat).join('; ')}');
  }

  List<String> _flattenValue(Object? value, [int depth = 0]) {
    if (value == null) return const [];
    if (value is String) {
      final t = _compactWhitespace(value);
      return t.isEmpty ? const [] : [t];
    }
    if (value is num && value.isFinite) return [value.toString()];
    if (value is bool) return [value ? 'true' : 'false'];
    if (value is DateTime) return [value.toIso8601String()];
    if (value is Iterable) {
      final out = <String>[];
      for (final v in value) {
        out.addAll(_flattenValue(v, depth + 1));
      }
      return out;
    }
    if (depth > 2) return const [];
    if (value is Map) {
      final out = <String>[];
      final keys = value.keys.whereType<Object>().toList()..sort();
      for (final k in keys) {
        final keyStr = k.toString();
        if (keyStr.startsWith('__')) continue;
        final inner = _flattenValue(value[k], depth + 1);
        for (final v in inner) {
          out.add('$keyStr: $v');
        }
      }
      return out;
    }
    return const [];
  }

  List<String> _dedupePreserveOrder(List<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final v in values) {
      if (seen.add(v)) out.add(v);
    }
    return out;
  }

  String _compactWhitespace(String s) {
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _truncateAtBoundary(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    final truncated = value.substring(0, maxLength);
    final boundaries = [
      truncated.lastIndexOf('\n'),
      truncated.lastIndexOf('. '),
      truncated.lastIndexOf('; '),
      truncated.lastIndexOf(' '),
    ];
    final boundary = boundaries.fold(-1, (a, b) => a > b ? a : b);
    if (boundary < (maxLength * 0.75).floor()) {
      return truncated.trim();
    }
    return truncated.substring(0, boundary).trim();
  }

  EmbeddingDocument _build(List<String> sections, String version) {
    final content = _truncateAtBoundary(sections.join('\n'), maxLength);
    return EmbeddingDocument(
      content: content,
      contentHash: _fnv1a64(content, version),
      textVersion: version,
    );
  }
}

/// 64-bit FNV-1a hash. Returns a hex string. The version prefix is mixed
/// in so the same content under two different versions hashes to two
/// different values, which is what we want for cache invalidation.
String _fnv1a64(String content, String version) {
  // FNV-1a 64-bit. Dart's `int` is 64-bit on native and JS platforms;
  // we mask to 32 bits for portability and pack as two hex words.
  const int prime = 0x100000001b3;
  int hash = 0xcbf29ce484222325;
  final bytes = utf8.encode('$version::$content');
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
  }
  // Render as 16-char hex; if hash is short, zero-pad.
  final hi = (hash >> 32) & 0xFFFFFFFF;
  final lo = hash & 0xFFFFFFFF;
  return '${hi.toRadixString(16).padLeft(8, '0')}'
      '${lo.toRadixString(16).padLeft(8, '0')}';
}

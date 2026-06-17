import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/models/chat_memory.dart';
import '../data/stores/vault_store.dart';
import 'memory_service.dart';

/// Format options for [ChatHistoryExporter.formatMarkdown].
class ChatHistoryFormat {
  final String? locale;
  final bool includeRawMetadata;
  final int maxKeyLength;

  const ChatHistoryFormat({
    this.locale,
    this.includeRawMetadata = true,
    this.maxKeyLength = 180,
  });

  static const ChatHistoryFormat defaults = ChatHistoryFormat();
}

/// Converts a [ChatSession] (plus its messages) into a Markdown document
/// with YAML frontmatter. The output is meant to be human-readable and
/// indexable by RFBrowser's full-text / link pipeline.
///
/// Output shape:
///   ```
///   ---
///   id: <session-id>
///   title: <session title>
///   created: 2026-01-15 10:32
///   updated: 2026-01-15 10:48
///   message_count: 12
///   tags: [chat]
///   ---
///
///   # <session title>
///
///   > Chat ID: <session-id>
///   > Created: 2026-01-15 10:32
///
///   ---
///
///   ## Chat Messages
///
///   ### User
///   *2026-01-15 10:32*
///   ...
///
///   ### openloomi
///   *2026-01-15 10:33*
///   ...
///   ```
class ChatHistoryExporter {
  final MemoryService _memory;
  final ChatHistoryFormat format;

  ChatHistoryExporter(this._memory, {this.format = ChatHistoryFormat.defaults});

  // ─── High-level API ───────────────────────────────────────────────

  /// Export the session identified by [sessionId] (or the current one) as
  /// a Markdown file. Returns the absolute path of the written file, or
  /// null when no vault is open / no messages exist.
  Future<String?> exportSession({String? sessionId, String? targetDir}) async {
    final sid = sessionId ?? _memory.currentSessionId;
    final session = await _sessionById(sid);
    if (session == null) return null;
    final messages = await _memory.getSessionMessages(sessionId: sid);
    if (messages.isEmpty) return null;
    final md = formatMarkdown(
      sessionId: session.id,
      title: session.title,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      messages: messages,
    );
    final dir = targetDir ?? await _resolveExportDir();
    if (dir == null) {
      debugPrint('ChatHistoryExporter: no vault open, skipping export');
      return null;
    }
    final file = File(p.join(dir, _filenameForSession(session)));
    await file.parent.create(recursive: true);
    await file.writeAsString(md, flush: true);
    return file.path;
  }

  /// Pure formatting helper exposed for tests and the settings UI preview.
  String formatMarkdown({
    required String sessionId,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required List<ChatRecord> messages,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      _frontmatter(
        sessionId: sessionId,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
        messageCount: messages.length,
      ),
    );
    buffer.writeln('# $title\n');
    buffer.writeln('> Chat ID: $sessionId');
    buffer.writeln('> Created: ${_formatDateTime(createdAt)}');
    buffer.writeln('> Updated: ${_formatDateTime(updatedAt)}\n');
    buffer.writeln('---\n');
    if (messages.isEmpty) {
      buffer.writeln('## Chat Messages\n');
      buffer.writeln('*No Chat Messages*\n');
      return buffer.toString();
    }
    buffer.writeln('## Chat Messages\n');
    for (final msg in messages) {
      final role = _roleLabel(msg.role);
      buffer.writeln('### $role');
      buffer.writeln('*${_formatDateTime(msg.timestamp)}*\n');
      buffer.writeln('${_truncate(msg.content, format.maxKeyLength)}\n');
      buffer.writeln('---\n');
    }
    buffer.writeln('**Total**: ${messages.length} Messages\n');
    return buffer.toString();
  }

  // ─── File naming & paths ──────────────────────────────────────────

  String _filenameForSession(ChatSession session) {
    final slug = _slugify(session.title);
    final stamp = session.createdAt.toIso8601String().substring(0, 10);
    final suffix = session.id.length >= 8
        ? session.id.substring(0, 8)
        : session.id;
    return '${stamp}_${slug}_$suffix.md';
  }

  Future<String?> _resolveExportDir() async {
    // The vault store reads from the current Vault; we go via the same
    // getter as memoryServiceProvider. If no vault is open we return null
    // and the caller decides what to do.
    final vault = _memoryDatabaseRoot();
    if (vault == null) return null;
    return p.join(vault, '.rfbrowser', 'chats');
  }

  String? _memoryDatabaseRoot() {
    // _memory._dbPath is set at construction; we don't have a public getter,
    // but it's encoded in the path's parent (`.rfbrowser`). Walk up two
    // levels to get the vault root.
    final segments = p.split(_memory.databasePath);
    if (segments.length < 3) return null;
    // Drop both 'memory.db' and '.rfbrowser'.
    return p.joinAll(segments.sublist(0, segments.length - 2));
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  Future<ChatSession?> _sessionById(String id) async {
    final all = await _memory.getAllSessions(limit: 1000);
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  String _frontmatter({
    required String sessionId,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int messageCount,
  }) {
    final sessionTag =
        'session-${sessionId.length >= 8 ? sessionId.substring(0, 8) : sessionId}';
    final tags = ['chat', 'memory', sessionTag];
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('id: $sessionId');
    buf.writeln('title: ${_yamlEscape(title)}');
    buf.writeln('created: ${createdAt.toIso8601String()}');
    buf.writeln('updated: ${updatedAt.toIso8601String()}');
    buf.writeln('message_count: $messageCount');
    buf.writeln('tags: [${tags.join(', ')}]');
    if (format.includeRawMetadata) {
      buf.writeln('exporter: rfbrowser/chat-history-exporter@v1');
    }
    buf.writeln('---');
    return buf.toString();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'user':
        return 'User';
      case 'assistant':
        return 'openloomi';
      case 'system':
        return 'System';
      case 'tool':
        return 'Tool';
      case 'tool_call':
        return 'Tool Call';
      case 'tool_result':
        return 'Tool Result';
      default:
        return role;
    }
  }

  String _formatDateTime(DateTime t) {
    final l = t.toLocal();
    final mm = l.month.toString().padLeft(2, '0');
    final dd = l.day.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '${l.year}-$mm-$dd $hh:$mi';
  }

  String _slugify(String input) {
    final lower = input.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\-_]+'), '-');
    final collapsed = cleaned.replaceAll(RegExp(r'-+'), '-');
    final trimmed = collapsed.replaceAll(RegExp(r'^-|-$'), '');
    if (trimmed.isEmpty) return 'chat';
    return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
  }

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen - 3)}...';
  }

  String _yamlEscape(String s) {
    if (s.contains(':') || s.contains('#') || s.contains('"')) {
      return '"${s.replaceAll('"', '\\"')}"';
    }
    return s;
  }
}

/// Riverpod provider for [ChatHistoryExporter]. Reads the current vault
/// from [vaultProvider] so the export path is always in sync with the
/// active workspace.
final chatHistoryExporterProvider = Provider<ChatHistoryExporter>((ref) {
  final memory = ref.watch(memoryServiceProvider);
  return ChatHistoryExporter(memory);
});

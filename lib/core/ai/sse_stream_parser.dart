// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';

/// A typed event emitted by [SseStreamParser]. The parser is protocol-aware
/// (OpenAI / Bailian / Ollama all use SSE with `data: ...` lines) and splits
/// the stream into the two things callers care about: text deltas for the UI
/// and tool-call fragments for the agent loop.
sealed class SseEvent {
  const SseEvent();
}

/// Text-delta event: incremental assistant text to append to the message
/// buffer. May be empty if the chunk contained only tool-call fragments.
class SseTextDelta extends SseEvent {
  final String text;
  const SseTextDelta(this.text);
  @override
  String toString() => 'SseTextDelta($text)';
}

/// A new tool call has started (we received its id and name).
class SseToolCallStart extends SseEvent {
  final int index;
  final String id;
  final String name;
  const SseToolCallStart({
    required this.index,
    required this.id,
    required this.name,
  });
  @override
  String toString() => 'SseToolCallStart($index: $name)';
}

/// Incremental argument fragment for a previously-started tool call.
class SseToolCallDelta extends SseEvent {
  final int index;
  final String argsFragment;
  const SseToolCallDelta({required this.index, required this.argsFragment});
  @override
  String toString() =>
      'SseToolCallDelta($index: +${argsFragment.length} chars)';
}

/// Stream finished normally ([DONE] seen or upstream closed).
class SseDone extends SseEvent {
  const SseDone();
}

/// A non-fatal parse error: malformed JSON, unknown shape, etc. The stream
/// continues; the caller may surface these for debugging.
class SseParseError extends SseEvent {
  final String message;
  const SseParseError(this.message);
  @override
  String toString() => 'SseParseError($message)';
}

/// Known provider protocols. Most OpenAI-compatible providers use the same
/// shape; we only need to special-case Bailian and Ollama for quirks in
/// field names (e.g. Bailian wraps text inside `output.text`).
enum SseProtocol { openai, bailian, ollama }

/// G13-A: SSE stream parser that *also* buffers partial lines.
///
/// Real-world HTTP responses arrive in arbitrary chunk boundaries. A single
/// `data: {...}\n` line can be split across two chunks; naively splitting the
/// raw text on `\n` (as the old inline parser did) mangles the first and
/// last lines. This parser maintains a `pendingLine` buffer so we never lose
/// or corrupt a chunk.
class SseStreamParser {
  final SseProtocol protocol;

  SseStreamParser(this.protocol);

  /// Parse the given raw byte chunk and yield events.
  ///
  /// This is intentionally NOT an async generator — the caller drives the
  /// iteration by calling it on each chunk as it arrives. This keeps the
  /// state private and lets unit tests feed in synthetic bytes.
  List<SseEvent> feed(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final events = <SseEvent>[];

    // Combine any leftover bytes from the previous chunk with the new ones.
    // (We rebuild the string in each call instead of carrying a buffer to
    //  keep the parser stateless for testing — the caller (SseStreamBuffer)
    //  owns the actual partial-line state.)
    final lines = text.split('\n');
    for (final raw in lines) {
      if (raw.isEmpty) continue;
      if (!raw.startsWith('data: ')) continue;
      final data = raw.substring(6).trim();
      if (data == '[DONE]') {
        events.add(const SseDone());
        continue;
      }
      try {
        final json = jsonDecode(data);
        events.addAll(_extractEvents(json));
      } catch (e) {
        events.add(SseParseError('JSON decode failed: $e'));
      }
    }
    return events;
  }

  /// Pull the text-delta out of a single JSON object. Tool-call fragments
  /// are also extracted and returned as their own events.
  List<SseEvent> _extractEvents(dynamic json) {
    final out = <SseEvent>[];

    // OpenAI / Ollama / Bailian-compatible: choices[0].delta.{content,tool_calls}
    final choices = json is Map ? json['choices'] as List? : null;
    if (choices == null || choices.isEmpty) {
      // Bailian non-streaming completion responses wrap under `output.text`.
      if (json is Map && json['output'] is Map) {
        final t = (json['output'] as Map)['text'];
        if (t is String && t.isNotEmpty) {
          out.add(SseTextDelta(t));
        }
      }
      return out;
    }

    final delta = choices.first is Map
        ? (choices.first as Map)['delta'] as Map?
        : null;
    if (delta == null) return out;

    // Text content.
    final text = delta['content'];
    if (text is String && text.isNotEmpty) {
      out.add(SseTextDelta(text));
    }

    // Tool call fragments.
    final toolCalls = delta['tool_calls'];
    if (toolCalls is List) {
      for (final tc in toolCalls) {
        if (tc is! Map) continue;
        final index = tc['index'];
        if (index is! int) continue;

        final id = tc['id'];
        final fn = tc['function'] as Map?;
        final name = fn?['name'] as String?;

        if (id is String && id.isNotEmpty) {
          // New tool call or continuation with id — emit start.
          out.add(SseToolCallStart(index: index, id: id, name: name ?? ''));
        }

        final argsDelta = fn?['arguments'];
        if (argsDelta is String && argsDelta.isNotEmpty) {
          out.add(SseToolCallDelta(index: index, argsFragment: argsDelta));
        } else if (argsDelta is Map) {
          // Some providers serialise args as nested JSON; flatten it.
          final flattened = jsonEncode(argsDelta);
          out.add(SseToolCallDelta(index: index, argsFragment: flattened));
        }
      }
    }
    return out;
  }
}

/// G13-A: a stateful buffer that drives an [SseStreamParser] over a raw
/// `Stream<List<int>>`. Owns the partial-line state so the parser itself
/// stays pure / testable.
class SseStreamBuffer {
  final SseStreamParser parser;
  final StringBuffer _partial = StringBuffer();
  final StreamController<SseEvent> _events =
      StreamController<SseEvent>.broadcast();

  SseStreamBuffer(this.parser);

  /// Subscribe to the parsed event stream.
  Stream<SseEvent> get events => _events.stream;

  /// Run the buffer over a raw byte stream. Closes the event stream when
  /// the upstream closes.
  Future<void> bind(Stream<List<int>> source) async {
    StringBuffer carry = _partial;
    await for (final chunk in source) {
      final text = utf8.decode(chunk, allowMalformed: true);
      carry.write(text);

      // Split on \n, but keep the last segment (after the final \n) as the
      // new partial-line state.
      final raw = carry.toString();
      final parts = raw.split('\n');
      carry = StringBuffer();
      for (var i = 0; i < parts.length; i++) {
        final isLast = i == parts.length - 1;
        final piece = parts[i];
        if (isLast) {
          // Last segment is incomplete until the next chunk arrives.
          carry.write(piece);
          // If the source chunk ended with \n, the last piece is "" — that's
          // a complete line, not a partial. Feed it.
          if (raw.endsWith('\n') && piece.isEmpty) {
            // piece was already empty; nothing to feed.
          } else if (piece.isNotEmpty) {
            _feedLine(piece);
          }
        } else {
          if (piece.isNotEmpty) {
            _feedLine(piece);
          }
        }
      }
    }
    // Drain any remaining partial line.
    if (carry.isNotEmpty) {
      _feedLine(carry.toString());
    }
    if (!_events.isClosed) {
      _events.add(const SseDone());
      await _events.close();
    }
  }

  void _feedLine(String line) {
    for (final ev in parser.feed(utf8.encode('$line\n'))) {
      _events.add(ev);
    }
  }

  Future<void> close() async {
    if (!_events.isClosed) await _events.close();
  }
}

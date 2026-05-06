import '../../data/models/context_assembly.dart';
import '../../data/models/note.dart';
import 'reference_parser.dart';

abstract class ContentSource {
  Future<ContextItem?> resolve(ParsedReference ref);
}

class NoteContentSource extends ContentSource {
  final List<Note> notes;

  NoteContentSource(this.notes);

  @override
  Future<ContextItem?> resolve(ParsedReference ref) async {
    if (ref.type != ContextRefType.note) return null;

    if (ref.target == 'current') {
      return null;
    }

    final note = notes.where(
      (n) =>
          n.title.toLowerCase() == ref.target.toLowerCase() ||
          n.aliases.any((a) => a.toLowerCase() == ref.target.toLowerCase()),
    ).firstOrNull;

    if (note == null) {
      return ContextItem(
        type: ContextType.note,
        id: ref.target,
        content: '',
        metadata: {'error': 'not_found', 'ref': ref.rawText},
      );
    }

    String content = note.content;
    if (ref.selector != null) {
      final section = _extractSection(content, ref.selector!);
      if (section != null) content = section;
    }

    return ContextItem(
      type: ContextType.note,
      id: note.id,
      content: content,
      metadata: {'title': note.title, 'filePath': note.filePath},
    );
  }

  String? _extractSection(String content, String heading) {
    final lines = content.split('\n');
    final headingPattern = RegExp(
      r'^#{1,6}\s+' + RegExp.escape(heading) + r'\s*$',
      caseSensitive: false,
    );
    int? startIdx;
    int? headingLevel;

    for (var i = 0; i < lines.length; i++) {
      final match = headingPattern.firstMatch(lines[i]);
      if (match != null) {
        startIdx = i + 1;
        final level = lines[i].indexOf(' ');
        headingLevel = level;
        break;
      }
    }

    if (startIdx == null) return null;

    final sectionLines = <String>[];
    for (var i = startIdx; i < lines.length; i++) {
      if (headingLevel != null) {
        final nextHeading = RegExp('^#{1,$headingLevel}\\s+');
        if (nextHeading.hasMatch(lines[i]) && i > startIdx) break;
      }
      sectionLines.add(lines[i]);
    }

    return sectionLines.join('\n').trim();
  }
}

class WebContentSource extends ContentSource {
  final String? currentUrl;
  final String? currentTitle;
  final String? currentContent;

  WebContentSource({
    this.currentUrl,
    this.currentTitle,
    this.currentContent,
  });

  @override
  Future<ContextItem?> resolve(ParsedReference ref) async {
    if (ref.type != ContextRefType.web) return null;

    if (ref.target == 'current') {
      if (currentContent == null || currentContent!.isEmpty) {
        return ContextItem(
          type: ContextType.webPage,
          id: 'current',
          content: '',
          metadata: {'error': 'no_active_page'},
        );
      }
      return ContextItem(
        type: ContextType.webPage,
        id: currentUrl ?? 'current',
        content: currentContent!,
        metadata: {'title': currentTitle ?? '', 'url': currentUrl ?? ''},
      );
    }

    return ContextItem(
      type: ContextType.webPage,
      id: ref.target,
      content: '',
      metadata: {'error': 'not_found', 'ref': ref.rawText},
    );
  }
}

class ClipContentSource extends ContentSource {
  final Map<String, String> clips;

  ClipContentSource({this.clips = const {}});

  @override
  Future<ContextItem?> resolve(ParsedReference ref) async {
    if (ref.type != ContextRefType.clip) return null;

    final content = clips[ref.target];
    if (content == null) {
      return ContextItem(
        type: ContextType.note,
        id: ref.target,
        content: '',
        metadata: {'error': 'not_found', 'ref': ref.rawText},
      );
    }

    return ContextItem(
      type: ContextType.note,
      id: ref.target,
      content: content,
      metadata: {'source': 'clip'},
    );
  }
}

class AgentResultContentSource extends ContentSource {
  final Map<String, String> agentResults;

  AgentResultContentSource({this.agentResults = const {}});

  @override
  Future<ContextItem?> resolve(ParsedReference ref) async {
    if (ref.type != ContextRefType.agent) return null;

    final content = agentResults[ref.target];
    if (content == null) {
      return ContextItem(
        type: ContextType.agentResult,
        id: ref.target,
        content: '',
        metadata: {'error': 'not_found', 'ref': ref.rawText},
      );
    }

    return ContextItem(
      type: ContextType.agentResult,
      id: ref.target,
      content: content,
      metadata: {'source': 'agent'},
    );
  }
}

class FileContentSource extends ContentSource {
  final Map<String, String> files;

  FileContentSource({this.files = const {}});

  @override
  Future<ContextItem?> resolve(ParsedReference ref) async {
    if (ref.type != ContextRefType.file) return null;

    final content = files[ref.target];
    if (content == null) {
      return ContextItem(
        type: ContextType.file,
        id: ref.target,
        content: '',
        metadata: {'error': 'not_found', 'ref': ref.rawText},
      );
    }

    return ContextItem(
      type: ContextType.file,
      id: ref.target,
      content: content,
      metadata: {'source': 'file', 'path': ref.target},
    );
  }
}

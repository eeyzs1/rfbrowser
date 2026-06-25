import '../../data/models/link.dart';
import '../../data/models/link_type.dart';

class LinkExtractor {
  static final _wikilinkRegex = RegExp(
    r'\[\[([^\]#\|]+)(?:#([^\|\]]+))?(?:\|([^\]]+))?\]\]',
  );
  static final _embedRegex = RegExp(r'!\[\[([^\]#\|]+)(?:#([^\|\]]+))?\]\]');
  static final _contextRefRegex = RegExp(
    r'@(note|web|file|agent|clip)\[([^\]#]+)(?:#([^\]]+))?\]',
  );

  List<ExtractedLink> extractLinks(String content) {
    final links = <ExtractedLink>[];

    for (final match in _wikilinkRegex.allMatches(content)) {
      links.add(
        ExtractedLink(
          target: match.group(1)?.trim() ?? '',
          heading: match.group(2)?.trim(),
          alias: match.group(3)?.trim(),
          type: LinkType.wikilink,
          position: match.start,
          rawText: match.group(0)!,
          context: _extractContext(content, match.start, match.end),
        ),
      );
    }

    for (final match in _embedRegex.allMatches(content)) {
      links.add(
        ExtractedLink(
          target: match.group(1)?.trim() ?? '',
          heading: match.group(2)?.trim(),
          type: LinkType.embed,
          position: match.start,
          rawText: match.group(0)!,
          context: _extractContext(content, match.start, match.end),
        ),
      );
    }

    return links;
  }

  List<ContextReference> extractContextRefs(String content) {
    final refs = <ContextReference>[];
    for (final match in _contextRefRegex.allMatches(content)) {
      refs.add(
        ContextReference(
          type: match.group(1)!,
          target: match.group(2)?.trim() ?? '',
          selector: match.group(3)?.trim(),
          position: match.start,
          rawText: match.group(0)!,
        ),
      );
    }
    return refs;
  }

  List<String> extractTags(String content) {
    final tags = <String>[];
    final tagRegex = RegExp(
      r'(?:^|\s)#([a-zA-Z\u4e00-\u9fff][\w\u4e00-\u9fff-]*)',
    );
    for (final match in tagRegex.allMatches(content)) {
      final tag = match.group(1);
      if (tag != null && !tag.startsWith('[')) {
        tags.add(tag);
      }
    }
    return tags;
  }

  List<UnlinkedMention> findUnlinkedMentions(
    String content,
    List<String> noteTitles,
  ) {
    final mentions = <UnlinkedMention>[];
    // Pre-compute wikilink/embed match ranges ONCE so we can skip any
    // title occurrence that falls inside an already-linked span. The
    // previous implementation re-scanned the whole content with
    // _wikilinkRegex.allMatches for every single candidate match, making
    // this O(n_titles * content * wikilinks) — catastrophic for large
    // vaults (caused the editor to freeze on every keystroke because
    // BacklinksPanel recomputes this on each build).
    final linkedRanges = <List<int>>[
      for (final m in _wikilinkRegex.allMatches(content)) [m.start, m.end],
      for (final m in _embedRegex.allMatches(content)) [m.start, m.end],
    ];

    bool isInsideLinkedRange(int start, int end) {
      for (final r in linkedRanges) {
        if (r[0] <= start && r[1] >= end) return true;
      }
      return false;
    }

    for (final title in noteTitles) {
      if (title.length < 3) continue;
      final regex = RegExp(RegExp.escape(title));
      for (final match in regex.allMatches(content)) {
        if (!isInsideLinkedRange(match.start, match.end)) {
          mentions.add(
            UnlinkedMention(
              noteId: '',
              targetTitle: title,
              context: _extractContext(content, match.start, match.end),
              position: match.start,
            ),
          );
        }
      }
    }
    return mentions;
  }

  String _extractContext(String content, int start, int end) {
    final contextStart = (start - 40).clamp(0, content.length);
    final contextEnd = (end + 40).clamp(0, content.length);
    final prefix = contextStart > 0 ? '...' : '';
    final suffix = contextEnd < content.length ? '...' : '';
    return '$prefix${content.substring(contextStart, contextEnd)}$suffix';
  }
}

class ExtractedLink {
  final String target;
  final String? heading;
  final String? alias;
  final LinkType type;
  final int position;
  final String rawText;
  final String context;

  ExtractedLink({
    required this.target,
    this.heading,
    this.alias,
    required this.type,
    required this.position,
    required this.rawText,
    required this.context,
  });
}

class ContextReference {
  final String type;
  final String target;
  final String? selector;
  final int position;
  final String rawText;

  ContextReference({
    required this.type,
    required this.target,
    required this.selector,
    required this.position,
    required this.rawText,
  });
}

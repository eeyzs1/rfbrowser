import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/note.dart';
import '../data/models/link.dart';
import '../data/models/link_type.dart';
import '../data/models/unlinked_mention.dart';
import '../core/link/link_extractor.dart';
import '../core/link/link_resolver.dart';
import '../core/graph/filter_engine.dart';

class LinkState {
  final List<Link> links;
  final Map<String, List<Link>> backlinksCache;

  const LinkState({this.links = const [], this.backlinksCache = const {}});

  LinkState copyWith({
    List<Link>? links,
    Map<String, List<Link>>? backlinksCache,
  }) {
    return LinkState(
      links: links ?? this.links,
      backlinksCache: backlinksCache ?? this.backlinksCache,
    );
  }
}

class LinkNotifier extends Notifier<LinkState> {
  // Cache for getUnlinkedMentions. BacklinksPanel calls this on every build
  // (which fires on every keystroke via knowledgeProvider state updates),
  // so without caching the O(n_titles * content) regex scan would freeze
  // the editor. The cache is keyed by (noteId, activeNote.content) and is
  // invalidated whenever the note set changes (rename/create/delete) via
  // rebuildAllLinks / updateLinksForNote / linkMention.
  String? _unlinkedCacheNoteId;
  String? _unlinkedCacheContent;
  List<UnlinkedMentionResult> _unlinkedCacheResult = const [];

  @override
  LinkState build() {
    return const LinkState();
  }

  void _invalidateUnlinkedMentionsCache() {
    _unlinkedCacheNoteId = null;
    _unlinkedCacheContent = null;
    _unlinkedCacheResult = const [];
  }

  void rebuildAllLinks(List<Note> notes) {
    _invalidateUnlinkedMentionsCache();
    final allLinks = <Link>[];
    final resolver = LinkResolver('');
    resolver.rebuildTitleIndex(notes);

    for (final note in notes) {
      final extracted = resolver.extractLinksFromContent(note.content);
      for (final link in extracted) {
        final targetPath = resolver.resolveTitleToPath(link.target);
        if (targetPath != null) {
          allLinks.add(
            Link(
              sourceId: note.id,
              targetId: _pathToId(targetPath),
              type: link.type,
              context: link.context,
              position: link.position,
            ),
          );
        }
      }
    }

    final backlinks = <String, List<Link>>{};
    for (final note in notes) {
      backlinks[note.id] = allLinks
          .where((l) => l.targetId == note.id)
          .toList();
    }

    state = LinkState(links: allLinks, backlinksCache: backlinks);
  }

  void updateLinksForNote(Note changedNote, List<Note> allNotes) {
    _invalidateUnlinkedMentionsCache();
    final existingLinks = state.links.toList();
    existingLinks.removeWhere((l) => l.sourceId == changedNote.id);

    final resolver = LinkResolver('');
    resolver.rebuildTitleIndex(allNotes);

    final extracted = resolver.extractLinksFromContent(changedNote.content);
    for (final link in extracted) {
      final targetPath = resolver.resolveTitleToPath(link.target);
      if (targetPath != null) {
        existingLinks.add(
          Link(
            sourceId: changedNote.id,
            targetId: _pathToId(targetPath),
            type: link.type,
            context: link.context,
            position: link.position,
          ),
        );
      }
    }

    final backlinks = <String, List<Link>>{};
    for (final note in allNotes) {
      backlinks[note.id] = existingLinks
          .where((l) => l.targetId == note.id)
          .toList();
    }

    state = LinkState(links: existingLinks, backlinksCache: backlinks);
  }

  List<Link> getNoteLinks(String noteId) {
    return state.links.where((l) => l.sourceId == noteId).toList();
  }

  List<Link> getBacklinks(String noteId) {
    return state.backlinksCache[noteId] ?? [];
  }

  List<UnlinkedMentionResult> getUnlinkedMentions(
    String noteId,
    List<Note> allNotes,
  ) {
    final note = allNotes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) return const [];

    // Cache hit: same active note and unchanged content → return cached
    // result without re-running the expensive regex scan.
    if (_unlinkedCacheNoteId == noteId &&
        _unlinkedCacheContent == note.content) {
      return _unlinkedCacheResult;
    }

    final titles = allNotes.map((n) => n.title).toList();
    final extractor = LinkExtractor();
    final result = extractor
        .findUnlinkedMentions(note.content, titles)
        .map(
          (m) => UnlinkedMentionResult(
            sourceNoteId: m.noteId,
            targetTitle: m.targetTitle,
            context: m.context,
            position: m.position,
          ),
        )
        .toList();

    _unlinkedCacheNoteId = noteId;
    _unlinkedCacheContent = note.content;
    _unlinkedCacheResult = result;
    return result;
  }

  List<Map<String, dynamic>> getGraphData(List<Note> notes) {
    final nodeMap = <String, Map<String, dynamic>>{};
    for (final note in notes) {
      final connected = state.links.any(
        (l) => l.sourceId == note.id || l.targetId == note.id,
      );
      nodeMap[note.id] = {
        'id': note.id,
        'title': note.title,
        'tags': note.tags,
        'degree': connected ? 1 : 0,
      };
    }
    final edgeList = state.links
        .map(
          (l) => {
            'source': l.sourceId,
            'target': l.targetId,
            'type': l.type.name,
            'position': l.position,
          },
        )
        .toList();
    return [
      {'nodes': nodeMap.values.toList(), 'edges': edgeList},
    ];
  }

  LocalGraphResult getLocalGraph(
    String centerNoteId,
    List<Note> allNotes, {
    int depth = 1,
  }) {
    final graphFilter = GraphFilter(allNotes: allNotes, allLinks: state.links);
    return graphFilter.getLocalGraph(centerNoteId, depth: depth);
  }

  Future<void> linkMention(
    String sourceNoteId,
    String targetTitle,
    int position,
    List<Note> allNotes,
  ) async {
    _invalidateUnlinkedMentionsCache();
    final targetNote = allNotes
        .where((n) => n.title == targetTitle)
        .firstOrNull;
    if (targetNote == null) return;

    final newLink = Link(
      sourceId: sourceNoteId,
      targetId: targetNote.id,
      type: LinkType.wikilink,
      position: position,
    );

    final links = state.links.toList()..add(newLink);
    final backlinks = Map<String, List<Link>>.from(state.backlinksCache);
    backlinks[targetNote.id] = [...(backlinks[targetNote.id] ?? []), newLink];
    state = LinkState(links: links, backlinksCache: backlinks);
  }

  String _pathToId(String path) {
    return path.replaceAll(RegExp(r'[/\\]'), '_').replaceAll('.md', '');
  }
}

final linkServiceProvider = NotifierProvider<LinkNotifier, LinkState>(
  LinkNotifier.new,
);

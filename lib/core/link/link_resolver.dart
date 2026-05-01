import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/note.dart';
import '../../data/models/link.dart';
import '../../data/stores/vault_store.dart';
import 'link_extractor.dart';

class LinkResolver {
  final String vaultPath;
  final LinkExtractor _extractor = LinkExtractor();
  Map<String, String> _titleToPath = {};

  LinkResolver(this.vaultPath);

  Future<void> rebuildTitleIndex(List<Note> notes) async {
    _titleToPath = {};
    for (final note in notes) {
      _titleToPath[note.title.toLowerCase()] = note.filePath;
      for (final alias in note.aliases) {
        _titleToPath[alias.toLowerCase()] = note.filePath;
      }
    }
  }

  String? resolveTitleToPath(String title) {
    return _titleToPath[title.toLowerCase()];
  }

  List<ExtractedLink> extractLinksFromContent(String content) {
    return _extractor.extractLinks(content);
  }

  List<ContextReference> extractContextRefs(String content) {
    return _extractor.extractContextRefs(content);
  }

  List<String> extractTags(String content) {
    return _extractor.extractTags(content);
  }

  Future<List<Link>> resolveLinksForNote(Note note) async {
    final links = _extractor.extractLinks(note.content);

    final resolvedLinks = <Link>[];
    for (final link in links) {
      final targetPath = resolveTitleToPath(link.target);
      if (targetPath != null) {
        resolvedLinks.add(Link(
          sourceId: note.id,
          targetId: _pathToId(targetPath),
          type: link.type,
          context: link.context,
          position: link.position,
        ));
      }
    }
    return resolvedLinks;
  }

  Future<List<UnlinkedMention>> findUnlinkedMentions(Note note, List<String> allTitles) async {
    return _extractor.findUnlinkedMentions(note.content, allTitles);
  }

  String _pathToId(String path) {
    return path.replaceAll(RegExp(r'[/\\]'), '_').replaceAll('.md', '');
  }
}

final linkResolverProvider = Provider<LinkResolver?>((ref) {
  final vaultState = ref.watch(vaultProvider);
  if (vaultState.currentVault == null) return null;
  return LinkResolver(vaultState.currentVault!.path);
});

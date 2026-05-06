import '../link/link_extractor.dart';

class ReferenceParser {
  final LinkExtractor _extractor = LinkExtractor();

  List<ParsedReference> parse(String input) {
    final refs = _extractor.extractContextRefs(input);
    return refs
        .map(
          (ref) => ParsedReference(
            type: _parseType(ref.type),
            target: ref.target,
            selector: ref.selector,
            position: ref.position,
            rawText: ref.rawText,
          ),
        )
        .toList();
  }

  ContextRefType _parseType(String type) {
    switch (type) {
      case 'note':
        return ContextRefType.note;
      case 'web':
        return ContextRefType.web;
      case 'file':
        return ContextRefType.file;
      case 'agent':
        return ContextRefType.agent;
      case 'clip':
        return ContextRefType.clip;
      default:
        return ContextRefType.note;
    }
  }
}

enum ContextRefType { note, web, file, agent, clip }

class ParsedReference {
  final ContextRefType type;
  final String target;
  final String? selector;
  final int position;
  final String rawText;

  ParsedReference({
    required this.type,
    required this.target,
    this.selector,
    required this.position,
    required this.rawText,
  });
}

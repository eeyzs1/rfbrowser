import 'link_type.dart';

class Link {
  final String sourceId;
  final String targetId;
  final LinkType type;
  final String? context;
  final int? position;

  Link({
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.context,
    this.position,
  });
}

class UnlinkedMention {
  final String noteId;
  final String targetTitle;
  final String context;
  final int position;

  UnlinkedMention({
    required this.noteId,
    required this.targetTitle,
    required this.context,
    required this.position,
  });
}

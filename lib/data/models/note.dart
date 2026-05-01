import 'package:uuid/uuid.dart';

class Note {
  final String id;
  String title;
  String filePath;
  String content;
  Map<String, dynamic> frontMatter;
  List<String> tags;
  List<String> aliases;
  DateTime created;
  DateTime modified;
  String? sourceUrl;
  String? sourceTitle;
  String? agentTaskId;

  Note({
    String? id,
    required this.title,
    required this.filePath,
    this.content = '',
    Map<String, dynamic>? frontMatter,
    List<String>? tags,
    List<String>? aliases,
    DateTime? created,
    DateTime? modified,
    this.sourceUrl,
    this.sourceTitle,
    this.agentTaskId,
  }) : id = id ?? const Uuid().v4(),
       frontMatter = frontMatter ?? {},
       tags = tags ?? [],
       aliases = aliases ?? [],
       created = created ?? DateTime.now(),
       modified = modified ?? DateTime.now();

  Note copyWith({
    String? title,
    String? filePath,
    String? content,
    Map<String, dynamic>? frontMatter,
    List<String>? tags,
    List<String>? aliases,
    DateTime? modified,
    String? sourceUrl,
    String? sourceTitle,
    String? agentTaskId,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      content: content ?? this.content,
      frontMatter: frontMatter ?? Map.from(this.frontMatter),
      tags: tags ?? List.from(this.tags),
      aliases: aliases ?? List.from(this.aliases),
      created: created,
      modified: modified ?? DateTime.now(),
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      agentTaskId: agentTaskId ?? this.agentTaskId,
    );
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    if (frontMatter.isNotEmpty || tags.isNotEmpty || aliases.isNotEmpty) {
      buffer.writeln('---');
      if (title.isNotEmpty) buffer.writeln('title: "$title"');
      buffer.writeln('created: ${created.toIso8601String()}');
      buffer.writeln('modified: ${modified.toIso8601String()}');
      if (tags.isNotEmpty) {
        buffer.writeln('tags: [${tags.join(', ')}]');
      }
      if (aliases.isNotEmpty) {
        buffer.writeln('aliases: [${aliases.map((a) => '"$a"').join(', ')}]');
      }
      if (sourceUrl != null) buffer.writeln('source: $sourceUrl');
      if (sourceTitle != null) buffer.writeln('source-title: "$sourceTitle"');
      if (agentTaskId != null) buffer.writeln('agent-task: $agentTaskId');
      frontMatter.forEach((key, value) {
        if (![
          'title',
          'created',
          'modified',
          'tags',
          'aliases',
          'source',
          'source-title',
          'agent-task',
        ].contains(key)) {
          buffer.writeln('$key: $value');
        }
      });
      buffer.writeln('---');
      buffer.writeln();
    }
    buffer.write(content);
    return buffer.toString();
  }

  static Note fromMarkdown(String filePath, String markdown) {
    final frontMatter = <String, dynamic>{};
    String content = markdown;
    String title = '';
    List<String> tags = [];
    List<String> aliases = [];
    String? sourceUrl;
    String? sourceTitle;

    if (markdown.startsWith('---')) {
      final endIndex = markdown.indexOf('---', 3);
      if (endIndex > 0) {
        final fmText = markdown.substring(3, endIndex).trim();
        content = markdown.substring(endIndex + 3).trim();
        for (final line in fmText.split('\n')) {
          final colonIdx = line.indexOf(':');
          if (colonIdx > 0) {
            final key = line.substring(0, colonIdx).trim();
            final value = line.substring(colonIdx + 1).trim();
            switch (key) {
              case 'title':
                title = value.replaceAll('"', '');
              case 'tags':
                tags = value
                    .replaceAll('[', '')
                    .replaceAll(']', '')
                    .split(',')
                    .map((s) => s.trim().replaceAll('"', ''))
                    .where((s) => s.isNotEmpty)
                    .toList();
              case 'aliases':
                aliases = value
                    .replaceAll('[', '')
                    .replaceAll(']', '')
                    .split(',')
                    .map((s) => s.trim().replaceAll('"', ''))
                    .where((s) => s.isNotEmpty)
                    .toList();
              case 'source':
                sourceUrl = value;
              case 'source-title':
                sourceTitle = value.replaceAll('"', '');
              default:
                frontMatter[key] = value;
            }
          }
        }
      }
    }

    if (title.isEmpty) {
      final firstLine = content
          .split('\n')
          .firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Untitled');
      title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (title.isEmpty) title = 'Untitled';
    }

    return Note(
      title: title,
      filePath: filePath,
      content: content,
      frontMatter: frontMatter,
      tags: tags,
      aliases: aliases,
      created: frontMatter['created'] != null
          ? DateTime.tryParse(frontMatter['created'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      modified: frontMatter['modified'] != null
          ? DateTime.tryParse(frontMatter['modified'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      sourceUrl: sourceUrl,
      sourceTitle: sourceTitle,
    );
  }
}

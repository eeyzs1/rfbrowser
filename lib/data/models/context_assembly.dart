enum ContextType { note, webPage, selection, screenshot, file, agentResult }

class ContextItem {
  final ContextType type;
  final String id;
  final String content;
  final String? summary;
  final Map<String, dynamic> metadata;

  ContextItem({
    required this.type,
    required this.id,
    required this.content,
    this.summary,
    this.metadata = const {},
  });

  ContextItem copyWith({
    ContextType? type,
    String? id,
    String? content,
    String? summary,
    Map<String, dynamic>? metadata,
  }) {
    return ContextItem(
      type: type ?? this.type,
      id: id ?? this.id,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ContextAssembly {
  final List<ContextItem> items;
  final bool truncated;

  ContextAssembly({List<ContextItem>? items, this.truncated = false})
    : items = items ?? [];

  ContextAssembly addItem(ContextItem item) {
    return ContextAssembly(
      items: [...items, item],
      truncated: truncated,
    );
  }

  String toPrompt() {
    final buffer = StringBuffer();
    for (final item in items) {
      if (item.content.isEmpty) continue;
      final title = item.metadata['title'] ?? item.id;
      buffer.writeln('[Context: ${item.type.name} "$title"]');
      buffer.writeln(item.content);
      buffer.writeln('[End Context]');
      buffer.writeln();
    }
    return buffer.toString();
  }

  int get estimatedTokens {
    int total = 0;
    for (final item in items) {
      total += item.content.length ~/ 4;
    }
    return total;
  }
}

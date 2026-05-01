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
}

class ContextAssembly {
  final List<ContextItem> items;

  ContextAssembly({List<ContextItem>? items}) : items = items ?? [];

  ContextAssembly addItem(ContextItem item) {
    return ContextAssembly(items: [...items, item]);
  }

  String toPrompt() {
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.writeln('[${item.type.name}: ${item.id}]');
      buffer.writeln(item.content);
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

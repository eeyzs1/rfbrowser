enum DragSource { browser, sidebar, canvas, editor }

class DragDataType { static const text = 'text'; static const link = 'link'; static const image = 'image'; static const note = 'note'; }

class DragData {
  final DragSource source;
  final String type;
  final String content;
  final String? id;
  final String? url;
  final String? title;

  const DragData({
    required this.source,
    required this.type,
    required this.content,
    this.id,
    this.url,
    this.title,
  });

  Map<String, dynamic> toJson() => {
    'source': source.index,
    'type': type,
    'content': content,
    'id': id,
    'url': url,
    'title': title,
  };

  factory DragData.fromJson(Map<String, dynamic> json) => DragData(
    source: DragSource.values[json['source'] as int? ?? 0],
    type: json['type'] as String? ?? 'text',
    content: json['content'] as String? ?? '',
    id: json['id'] as String?,
    url: json['url'] as String?,
    title: json['title'] as String?,
  );
}

class DropHandler {
  String handle(DragData data) {
    switch (data.type) {
      case DragDataType.text:
        final source = data.url != null ? ' @web[${data.url}]' : '';
        return '> ${data.content}\n—$source';
      case DragDataType.link:
        return '[${data.title ?? data.content}](${data.url ?? data.content})';
      case DragDataType.note:
        return '[[${data.title ?? data.content}]]';
      case DragDataType.image:
        return '![[${data.content}]]';
      default:
        return data.content;
    }
  }
}

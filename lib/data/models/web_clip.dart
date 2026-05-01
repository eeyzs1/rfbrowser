class WebClip {
  final String id;
  final String url;
  final String title;
  final String content;
  final String? rawHtml;
  final List<String> selectedText;
  final String? screenshot;
  final DateTime captured;
  final String noteId;

  WebClip({
    required this.id,
    required this.url,
    required this.title,
    required this.content,
    this.rawHtml,
    this.selectedText = const [],
    this.screenshot,
    DateTime? captured,
    required this.noteId,
  }) : captured = captured ?? DateTime.now();
}

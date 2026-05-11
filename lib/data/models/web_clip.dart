import 'dart:convert';

class WebClip {
  final String id;
  final String url;
  final String title;
  final String content;
  final String? rawHtmlPath;
  final String? screenshotPath;
  final List<String> selectedText;
  final DateTime captured;
  final String noteId;

  WebClip({
    required this.id,
    required this.url,
    required this.title,
    required this.content,
    this.rawHtmlPath,
    this.screenshotPath,
    this.selectedText = const [],
    DateTime? captured,
    required this.noteId,
  }) : captured = captured ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'content': content,
        'rawHtmlPath': rawHtmlPath,
        'screenshotPath': screenshotPath,
        'selectedText': selectedText,
        'captured': captured.toIso8601String(),
        'noteId': noteId,
      };

  factory WebClip.fromJson(Map<String, dynamic> json) => WebClip(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        rawHtmlPath: json['rawHtmlPath'] as String?,
        screenshotPath: json['screenshotPath'] as String?,
        selectedText: (json['selectedText'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        captured: json['captured'] != null
            ? DateTime.parse(json['captured'] as String)
            : DateTime.now(),
        noteId: json['noteId'] as String? ?? '',
      );

  String toJsonString() => jsonEncode(toJson());

  factory WebClip.fromJsonString(String str) =>
      WebClip.fromJson(jsonDecode(str) as Map<String, dynamic>);
}

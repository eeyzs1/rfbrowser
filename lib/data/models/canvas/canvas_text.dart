enum TextAlignH { left, center, right }

enum TextAlignV { top, middle, bottom }

enum RichTextSegmentType { text, bold, italic, underline, code, strikethrough }

class RichTextSegment {
  final String text;
  final RichTextSegmentType type;
  const RichTextSegment({
    required this.text,
    this.type = RichTextSegmentType.text,
  });
  Map<String, dynamic> toJson() => {'text': text, 'type': type.index};
  factory RichTextSegment.fromJson(Map<String, dynamic> json) =>
      RichTextSegment(
        text: json['text'] as String? ?? '',
        type: RichTextSegmentType.values[json['type'] as int? ?? 0],
      );
}

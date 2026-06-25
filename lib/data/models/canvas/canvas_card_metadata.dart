class CanvasCardMetadata {
  final Map<String, String> properties;
  final String? hyperlink;
  const CanvasCardMetadata({this.properties = const {}, this.hyperlink});
  Map<String, dynamic> toJson() => {
    if (properties.isNotEmpty) 'properties': properties,
    if (hyperlink != null) 'hyperlink': hyperlink,
  };
  factory CanvasCardMetadata.fromJson(Map<String, dynamic> json) =>
      CanvasCardMetadata(
        properties:
            (json['properties'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {},
        hyperlink: json['hyperlink'] as String?,
      );
  CanvasCardMetadata copyWith({
    Map<String, String>? properties,
    String? hyperlink,
    bool clearHyperlink = false,
  }) => CanvasCardMetadata(
    properties: properties ?? this.properties,
    hyperlink: clearHyperlink ? null : (hyperlink ?? this.hyperlink),
  );
}

class CanvasTableCell {
  final String text;
  const CanvasTableCell({this.text = ''});
  Map<String, dynamic> toJson() => {'text': text};
  factory CanvasTableCell.fromJson(Map<String, dynamic> json) =>
      CanvasTableCell(text: json['text'] as String? ?? '');
}

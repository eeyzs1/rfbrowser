class CanvasGroup {
  final String id;
  final String name;
  final List<String> cardIds;
  final int colorValue;

  const CanvasGroup({
    required this.id,
    required this.name,
    this.cardIds = const [],
    this.colorValue = 0xFFFFFFFF,
  });

  CanvasGroup copyWith({
    String? name,
    List<String>? cardIds,
    int? colorValue,
  }) => CanvasGroup(
    id: id,
    name: name ?? this.name,
    cardIds: cardIds ?? this.cardIds,
    colorValue: colorValue ?? this.colorValue,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cardIds': cardIds,
    'colorValue': colorValue,
  };

  factory CanvasGroup.fromJson(Map<String, dynamic> json) => CanvasGroup(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    cardIds: (json['cardIds'] as List?)?.cast<String>() ?? [],
    colorValue: json['colorValue'] as int? ?? 0xFFFFFFFF,
  );
}

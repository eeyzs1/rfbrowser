class CanvasLayer {
  final String id;
  final String name;
  final int order;
  final bool visible;
  final bool locked;

  const CanvasLayer({
    required this.id,
    required this.name,
    this.order = 0,
    this.visible = true,
    this.locked = false,
  });

  CanvasLayer copyWith({
    String? name,
    int? order,
    bool? visible,
    bool? locked,
  }) => CanvasLayer(
    id: id,
    name: name ?? this.name,
    order: order ?? this.order,
    visible: visible ?? this.visible,
    locked: locked ?? this.locked,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'order': order,
    if (!visible) 'visible': false,
    if (locked) 'locked': true,
  };

  factory CanvasLayer.fromJson(Map<String, dynamic> json) => CanvasLayer(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    order: json['order'] as int? ?? 0,
    visible: json['visible'] as bool? ?? true,
    locked: json['locked'] as bool? ?? false,
  );
}

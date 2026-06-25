import 'package:flutter/material.dart';

import 'canvas_card_style.dart';
import 'canvas_card_type.dart';

enum AutoLayoutType { forceDirected, hierarchical, grid }

enum ExportFormat { png, svg, markdown }

enum AlignmentGuideType {
  centerVertical,
  centerHorizontal,
  leftEdge,
  rightEdge,
  topEdge,
  bottomEdge,
  equalSpacingH,
  equalSpacingV,
}

class ScratchpadItem {
  final String id;
  final String name;
  final CanvasCardType type;
  final double width;
  final double height;
  final int colorValue;
  final CanvasCardStyle? style;
  final String category;

  const ScratchpadItem({
    required this.id,
    required this.name,
    required this.type,
    this.width = 240,
    this.height = 160,
    this.colorValue = 0xFFFFFFFF,
    this.style,
    this.category = 'General',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.index,
    'width': width,
    'height': height,
    'colorValue': colorValue,
    if (style != null) 'style': style!.toJson(),
    'category': category,
  };

  factory ScratchpadItem.fromJson(Map<String, dynamic> json) => ScratchpadItem(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    type:
        CanvasCardType.values[(json['type'] as int).clamp(
          0,
          CanvasCardType.values.length - 1,
        )],
    width: (json['width'] as num?)?.toDouble() ?? 240,
    height: (json['height'] as num?)?.toDouble() ?? 160,
    colorValue: json['colorValue'] as int? ?? 0xFFFFFFFF,
    style: json['style'] != null
        ? CanvasCardStyle.fromJson(json['style'] as Map<String, dynamic>)
        : null,
    category: json['category'] as String? ?? 'General',
  );
}

class AlignmentGuide {
  final Offset start;
  final Offset end;
  final AlignmentGuideType type;

  const AlignmentGuide({
    required this.start,
    required this.end,
    required this.type,
  });
}

enum AlignmentType { left, centerH, right, top, centerV, bottom }

enum DistributeType { horizontal, vertical }

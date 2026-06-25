import 'package:flutter/material.dart';

import 'canvas_card.dart';

enum ConnectionSide {
  top,
  bottom,
  left,
  right;

  Offset point(Rect rect, [double offset = 0.5]) => switch (this) {
    ConnectionSide.top => Offset(rect.left + rect.width * offset, rect.top),
    ConnectionSide.bottom => Offset(
      rect.left + rect.width * offset,
      rect.bottom,
    ),
    ConnectionSide.left => Offset(rect.left, rect.top + rect.height * offset),
    ConnectionSide.right => Offset(rect.right, rect.top + rect.height * offset),
  };
}

enum ConnectionPath { curved, straight, orthogonal }

enum ArrowStyle { none, triangle, filledTriangle, diamond, circle }

enum LineJumpStyle { none, arc, gap, square }

enum FlowAnimationStyle { none, flow, pulse, dash }

class CanvasConnectionStyle {
  final ConnectionPath pathType;
  final ArrowStyle arrowStyle;
  final ArrowStyle startArrowStyle;
  final double strokeWidth;
  final int colorValue;
  final LineJumpStyle lineJumpStyle;
  final double lineJumpSize;
  final FlowAnimationStyle flowAnimation;
  final double arrowSize;
  final double labelFontSize;
  final double waypointSize;

  const CanvasConnectionStyle({
    this.pathType = ConnectionPath.curved,
    this.arrowStyle = ArrowStyle.filledTriangle,
    this.startArrowStyle = ArrowStyle.none,
    this.strokeWidth = 2.0,
    this.colorValue = 0xFF000000,
    this.lineJumpStyle = LineJumpStyle.none,
    this.lineJumpSize = 8.0,
    this.flowAnimation = FlowAnimationStyle.none,
    this.arrowSize = 8.0,
    this.labelFontSize = 0.0,
    this.waypointSize = 6.0,
  });

  static const CanvasConnectionStyle defaults = CanvasConnectionStyle();

  CanvasConnectionStyle copyWith({
    ConnectionPath? pathType,
    ArrowStyle? arrowStyle,
    ArrowStyle? startArrowStyle,
    double? strokeWidth,
    int? colorValue,
    LineJumpStyle? lineJumpStyle,
    double? lineJumpSize,
    FlowAnimationStyle? flowAnimation,
    double? arrowSize,
    double? labelFontSize,
    double? waypointSize,
  }) => CanvasConnectionStyle(
    pathType: pathType ?? this.pathType,
    arrowStyle: arrowStyle ?? this.arrowStyle,
    startArrowStyle: startArrowStyle ?? this.startArrowStyle,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    colorValue: colorValue ?? this.colorValue,
    lineJumpStyle: lineJumpStyle ?? this.lineJumpStyle,
    lineJumpSize: lineJumpSize ?? this.lineJumpSize,
    flowAnimation: flowAnimation ?? this.flowAnimation,
    arrowSize: arrowSize ?? this.arrowSize,
    labelFontSize: labelFontSize ?? this.labelFontSize,
    waypointSize: waypointSize ?? this.waypointSize,
  );

  Map<String, dynamic> toJson() => {
    'pathType': pathType.index,
    'arrowStyle': arrowStyle.index,
    'startArrowStyle': startArrowStyle.index,
    'strokeWidth': strokeWidth,
    'colorValue': colorValue,
    'lineJumpStyle': lineJumpStyle.index,
    'lineJumpSize': lineJumpSize,
    'flowAnimation': flowAnimation.index,
    'arrowSize': arrowSize,
    'labelFontSize': labelFontSize,
    'waypointSize': waypointSize,
  };

  factory CanvasConnectionStyle.fromJson(Map<String, dynamic> json) =>
      CanvasConnectionStyle(
        pathType: ConnectionPath.values[json['pathType'] as int? ?? 0],
        arrowStyle: ArrowStyle.values[json['arrowStyle'] as int? ?? 2],
        startArrowStyle:
            ArrowStyle.values[json['startArrowStyle'] as int? ?? 0],
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
        colorValue: json['colorValue'] as int? ?? 0xFF000000,
        lineJumpStyle: LineJumpStyle.values[json['lineJumpStyle'] as int? ?? 0],
        lineJumpSize: (json['lineJumpSize'] as num?)?.toDouble() ?? 8.0,
        flowAnimation:
            FlowAnimationStyle.values[json['flowAnimation'] as int? ?? 0],
        arrowSize: (json['arrowSize'] as num?)?.toDouble() ?? 8.0,
        labelFontSize: (json['labelFontSize'] as num?)?.toDouble() ?? 0.0,
        waypointSize: (json['waypointSize'] as num?)?.toDouble() ?? 6.0,
      );
}

class CanvasConnection {
  final String id;
  final String fromCardId;
  final String toCardId;
  final ConnectionSide fromSide;
  final ConnectionSide toSide;
  final double fromSideOffset;
  final double toSideOffset;
  final String label;
  final bool isAuto;
  final CanvasConnectionStyle? style;
  final List<Offset> waypoints;

  const CanvasConnection({
    required this.id,
    required this.fromCardId,
    required this.toCardId,
    this.fromSide = ConnectionSide.right,
    this.toSide = ConnectionSide.left,
    this.fromSideOffset = 0.5,
    this.toSideOffset = 0.5,
    this.label = '',
    this.isAuto = false,
    this.style,
    this.waypoints = const [],
  });

  static (ConnectionSide, ConnectionSide) computeSides(
    CanvasCard from,
    CanvasCard to,
  ) {
    final dx = to.center.dx - from.center.dx;
    final dy = to.center.dy - from.center.dy;
    final fromSide = dx.abs() > dy.abs()
        ? (dx > 0 ? ConnectionSide.right : ConnectionSide.left)
        : (dy > 0 ? ConnectionSide.bottom : ConnectionSide.top);
    final toSide = dx.abs() > dy.abs()
        ? (dx > 0 ? ConnectionSide.left : ConnectionSide.right)
        : (dy > 0 ? ConnectionSide.top : ConnectionSide.bottom);
    return (fromSide, toSide);
  }

  CanvasConnection copyWith({
    String? fromCardId,
    String? toCardId,
    ConnectionSide? fromSide,
    ConnectionSide? toSide,
    double? fromSideOffset,
    double? toSideOffset,
    String? label,
    bool? isAuto,
    CanvasConnectionStyle? style,
    bool clearStyle = false,
    List<Offset>? waypoints,
  }) => CanvasConnection(
    id: id,
    fromCardId: fromCardId ?? this.fromCardId,
    toCardId: toCardId ?? this.toCardId,
    fromSide: fromSide ?? this.fromSide,
    toSide: toSide ?? this.toSide,
    fromSideOffset: fromSideOffset ?? this.fromSideOffset,
    toSideOffset: toSideOffset ?? this.toSideOffset,
    label: label ?? this.label,
    isAuto: isAuto ?? this.isAuto,
    style: clearStyle ? null : (style ?? this.style),
    waypoints: waypoints ?? this.waypoints,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromCardId': fromCardId,
    'toCardId': toCardId,
    'fromSide': fromSide.index,
    'toSide': toSide.index,
    'fromSideOffset': fromSideOffset,
    'toSideOffset': toSideOffset,
    'label': label,
    'isAuto': isAuto,
    if (style != null) 'style': style!.toJson(),
    if (waypoints.isNotEmpty)
      'waypoints': waypoints.map((w) => {'x': w.dx, 'y': w.dy}).toList(),
  };

  factory CanvasConnection.fromJson(
    Map<String, dynamic> json,
  ) => CanvasConnection(
    id: json['id'] as String,
    fromCardId: json['fromCardId'] as String,
    toCardId: json['toCardId'] as String,
    fromSide: ConnectionSide.values[json['fromSide'] as int? ?? 3],
    toSide: ConnectionSide.values[json['toSide'] as int? ?? 2],
    fromSideOffset: (json['fromSideOffset'] as num?)?.toDouble() ?? 0.5,
    toSideOffset: (json['toSideOffset'] as num?)?.toDouble() ?? 0.5,
    label: json['label'] as String? ?? '',
    isAuto: json['isAuto'] as bool? ?? false,
    style: json['style'] != null
        ? CanvasConnectionStyle.fromJson(json['style'] as Map<String, dynamic>)
        : null,
    waypoints:
        (json['waypoints'] as List?)?.map((w) {
          final m = w as Map<String, dynamic>;
          return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
        }).toList() ??
        [],
  );
}

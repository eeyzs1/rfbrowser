import 'dart:convert';
import 'package:flutter/material.dart';

enum CanvasCardType {
  note,
  text,
  image,
  link,
  container,
  rectangle,
  roundedRect,
  ellipse,
  diamond,
  hexagon,
  parallelogram,
  triangle,
  cylinder,
  star,
  swimlaneH,
  swimlaneV,
  table,
  freehand;

  String get label => switch (this) {
    CanvasCardType.note => 'Note',
    CanvasCardType.text => 'Text',
    CanvasCardType.image => 'Image',
    CanvasCardType.link => 'Link',
    CanvasCardType.container => 'Container',
    CanvasCardType.rectangle => 'Rectangle',
    CanvasCardType.roundedRect => 'Rounded Rect',
    CanvasCardType.ellipse => 'Ellipse',
    CanvasCardType.diamond => 'Diamond',
    CanvasCardType.hexagon => 'Hexagon',
    CanvasCardType.parallelogram => 'Parallelogram',
    CanvasCardType.triangle => 'Triangle',
    CanvasCardType.cylinder => 'Cylinder',
    CanvasCardType.star => 'Star',
    CanvasCardType.swimlaneH => 'Swimlane H',
    CanvasCardType.swimlaneV => 'Swimlane V',
    CanvasCardType.table => 'Table',
    CanvasCardType.freehand => 'Freehand',
  };

  IconData get icon => switch (this) {
    CanvasCardType.note => Icons.description,
    CanvasCardType.text => Icons.text_fields,
    CanvasCardType.image => Icons.image,
    CanvasCardType.link => Icons.link,
    CanvasCardType.container => Icons.crop_square,
    CanvasCardType.rectangle => Icons.rectangle,
    CanvasCardType.roundedRect => Icons.rounded_corner,
    CanvasCardType.ellipse => Icons.circle,
    CanvasCardType.diamond => Icons.diamond,
    CanvasCardType.hexagon => Icons.hexagon,
    CanvasCardType.parallelogram => Icons.change_history,
    CanvasCardType.triangle => Icons.details,
    CanvasCardType.cylinder => Icons.view_column,
    CanvasCardType.star => Icons.star_outline,
    CanvasCardType.swimlaneH => Icons.view_stream,
    CanvasCardType.swimlaneV => Icons.view_week,
    CanvasCardType.table => Icons.table_chart,
    CanvasCardType.freehand => Icons.draw,
  };

  bool get isGeometric => switch (this) {
    rectangle ||
    roundedRect ||
    ellipse ||
    diamond ||
    hexagon ||
    parallelogram ||
    triangle ||
    cylinder ||
    star ||
    table => true,
    _ => false,
  };

  bool get isSwimlane => this == swimlaneH || this == swimlaneV;

  double get defaultWidth => switch (this) {
    swimlaneH => 800,
    swimlaneV => 240,
    container => 400,
    table => 320,
    _ => 160,
  };

  double get defaultHeight => switch (this) {
    swimlaneH => 200,
    swimlaneV => 600,
    container => 300,
    table => 200,
    _ => 100,
  };
}

enum CardBorderStyle { solid, dashed, dotted, none }

enum GradientDirection {
  topToBottom,
  bottomToTop,
  leftToRight,
  rightToLeft,
  topLeftToBottomRight,
  topRightToBottomLeft;

  Alignment get begin => switch (this) {
    topToBottom => Alignment.topCenter,
    bottomToTop => Alignment.bottomCenter,
    leftToRight => Alignment.centerLeft,
    rightToLeft => Alignment.centerRight,
    topLeftToBottomRight => Alignment.topLeft,
    topRightToBottomLeft => Alignment.topRight,
  };

  Alignment get end => switch (this) {
    topToBottom => Alignment.bottomCenter,
    bottomToTop => Alignment.topCenter,
    leftToRight => Alignment.centerRight,
    rightToLeft => Alignment.centerLeft,
    topLeftToBottomRight => Alignment.bottomRight,
    topRightToBottomLeft => Alignment.bottomLeft,
  };
}

class CanvasCardStyle {
  final int fillColor;
  final int? gradientColor;
  final GradientDirection gradientDirection;
  final int borderColor;
  final double borderWidth;
  final CardBorderStyle borderStyle;
  final double borderRadius;
  final double opacity;
  final bool shadow;
  final bool glassEffect;
  final bool comicEffect;

  const CanvasCardStyle({
    this.fillColor = 0xFFFFFFFF,
    this.gradientColor,
    this.gradientDirection = GradientDirection.topToBottom,
    this.borderColor = 0xFFE0E0E0,
    this.borderWidth = 1.0,
    this.borderStyle = CardBorderStyle.solid,
    this.borderRadius = 8.0,
    this.opacity = 1.0,
    this.shadow = true,
    this.glassEffect = false,
    this.comicEffect = false,
  });

  static const CanvasCardStyle defaults = CanvasCardStyle();

  CanvasCardStyle copyWith({
    int? fillColor,
    int? gradientColor,
    bool clearGradient = false,
    GradientDirection? gradientDirection,
    int? borderColor,
    double? borderWidth,
    CardBorderStyle? borderStyle,
    double? borderRadius,
    double? opacity,
    bool? shadow,
    bool? glassEffect,
    bool? comicEffect,
  }) => CanvasCardStyle(
    fillColor: fillColor ?? this.fillColor,
    gradientColor: clearGradient ? null : (gradientColor ?? this.gradientColor),
    gradientDirection: gradientDirection ?? this.gradientDirection,
    borderColor: borderColor ?? this.borderColor,
    borderWidth: borderWidth ?? this.borderWidth,
    borderStyle: borderStyle ?? this.borderStyle,
    borderRadius: borderRadius ?? this.borderRadius,
    opacity: opacity ?? this.opacity,
    shadow: shadow ?? this.shadow,
    glassEffect: glassEffect ?? this.glassEffect,
    comicEffect: comicEffect ?? this.comicEffect,
  );

  Map<String, dynamic> toJson() => {
    'fillColor': fillColor,
    if (gradientColor != null) 'gradientColor': gradientColor,
    'gradientDirection': gradientDirection.index,
    'borderColor': borderColor,
    'borderWidth': borderWidth,
    'borderStyle': borderStyle.index,
    'borderRadius': borderRadius,
    'opacity': opacity,
    'shadow': shadow,
    'glassEffect': glassEffect,
    'comicEffect': comicEffect,
  };

  factory CanvasCardStyle.fromJson(Map<String, dynamic> json) =>
      CanvasCardStyle(
        fillColor: json['fillColor'] as int? ?? 0xFFFFFFFF,
        gradientColor: json['gradientColor'] as int?,
        gradientDirection:
            GradientDirection.values[json['gradientDirection'] as int? ?? 0],
        borderColor: json['borderColor'] as int? ?? 0xFFE0E0E0,
        borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 1.0,
        borderStyle: CardBorderStyle.values[json['borderStyle'] as int? ?? 0],
        borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 8.0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        shadow: json['shadow'] as bool? ?? true,
        glassEffect: json['glassEffect'] as bool? ?? false,
        comicEffect: json['comicEffect'] as bool? ?? false,
      );
}

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

class CanvasCard {
  final String id;
  final CanvasCardType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String title;
  final String content;
  final int colorValue;
  final String? noteId;
  final double fontSize;
  final CanvasCardStyle? style;
  final List<String> childIds;
  final bool collapsed;
  final String? layerId;
  final List<String> tags;
  final TextAlignH textAlignH;
  final TextAlignV textAlignV;
  final List<RichTextSegment> richContent;
  final CanvasCardMetadata? metadata;
  final bool autoNumber;
  final List<Offset> freehandPoints;
  final int tableRows;
  final int tableCols;
  final List<CanvasTableCell> tableCells;
  final bool verticalText;
  final String fontFamily;
  final int textColorValue;
  final String? latexFormula;
  final String? htmlContent;
  final String? customSvgData;
  final double connectionPointOffsetX;
  final double connectionPointOffsetY;

  const CanvasCard({
    required this.id,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 160,
    this.height = 100,
    this.title = '',
    this.content = '',
    this.colorValue = 0xFFFFFFFF,
    this.noteId,
    this.fontSize = 0,
    this.style,
    this.childIds = const [],
    this.collapsed = false,
    this.layerId,
    this.tags = const [],
    this.textAlignH = TextAlignH.left,
    this.textAlignV = TextAlignV.top,
    this.richContent = const [],
    this.metadata,
    this.autoNumber = false,
    this.freehandPoints = const [],
    this.tableRows = 3,
    this.tableCols = 3,
    this.tableCells = const [],
    this.verticalText = false,
    this.fontFamily = '',
    this.textColorValue = 0xFF000000,
    this.latexFormula,
    this.htmlContent,
    this.customSvgData,
    this.connectionPointOffsetX = 0.5,
    this.connectionPointOffsetY = 0.5,
  });

  double effectiveFontSize(double base) =>
      fontSize > 0 ? fontSize : base * 0.85;

  CanvasCard copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? title,
    String? content,
    int? colorValue,
    String? noteId,
    double? fontSize,
    CanvasCardStyle? style,
    bool clearStyle = false,
    List<String>? childIds,
    bool? collapsed,
    String? layerId,
    bool clearLayerId = false,
    List<String>? tags,
    TextAlignH? textAlignH,
    TextAlignV? textAlignV,
    List<RichTextSegment>? richContent,
    CanvasCardMetadata? metadata,
    bool clearMetadata = false,
    bool? autoNumber,
    List<Offset>? freehandPoints,
    int? tableRows,
    int? tableCols,
    List<CanvasTableCell>? tableCells,
    bool? verticalText,
    String? fontFamily,
    int? textColorValue,
    String? latexFormula,
    bool clearLatex = false,
    String? htmlContent,
    bool clearHtml = false,
    String? customSvgData,
    bool clearSvg = false,
    double? connectionPointOffsetX,
    double? connectionPointOffsetY,
  }) {
    return CanvasCard(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      title: title ?? this.title,
      content: content ?? this.content,
      colorValue: colorValue ?? this.colorValue,
      noteId: noteId ?? this.noteId,
      fontSize: fontSize ?? this.fontSize,
      style: clearStyle ? null : (style ?? this.style),
      childIds: childIds ?? this.childIds,
      collapsed: collapsed ?? this.collapsed,
      layerId: clearLayerId ? null : (layerId ?? this.layerId),
      tags: tags ?? this.tags,
      textAlignH: textAlignH ?? this.textAlignH,
      textAlignV: textAlignV ?? this.textAlignV,
      richContent: richContent ?? this.richContent,
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      autoNumber: autoNumber ?? this.autoNumber,
      freehandPoints: freehandPoints ?? this.freehandPoints,
      tableRows: tableRows ?? this.tableRows,
      tableCols: tableCols ?? this.tableCols,
      tableCells: tableCells ?? this.tableCells,
      verticalText: verticalText ?? this.verticalText,
      fontFamily: fontFamily ?? this.fontFamily,
      textColorValue: textColorValue ?? this.textColorValue,
      latexFormula: clearLatex ? null : (latexFormula ?? this.latexFormula),
      htmlContent: clearHtml ? null : (htmlContent ?? this.htmlContent),
      customSvgData: clearSvg ? null : (customSvgData ?? this.customSvgData),
      connectionPointOffsetX:
          connectionPointOffsetX ?? this.connectionPointOffsetX,
      connectionPointOffsetY:
          connectionPointOffsetY ?? this.connectionPointOffsetY,
    );
  }

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  Offset get center => Offset(x + width / 2, y + height / 2);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'title': title,
    'content': content,
    'colorValue': colorValue,
    'noteId': noteId,
    'fontSize': fontSize,
    if (style != null) 'style': style!.toJson(),
    if (childIds.isNotEmpty) 'childIds': childIds,
    if (collapsed) 'collapsed': collapsed,
    if (layerId != null) 'layerId': layerId,
    if (tags.isNotEmpty) 'tags': tags,
    'textAlignH': textAlignH.index,
    'textAlignV': textAlignV.index,
    if (richContent.isNotEmpty)
      'richContent': richContent.map((s) => s.toJson()).toList(),
    if (metadata != null) 'metadata': metadata!.toJson(),
    if (autoNumber) 'autoNumber': autoNumber,
    if (freehandPoints.isNotEmpty)
      'freehandPoints': freehandPoints
          .map((p) => {'x': p.dx, 'y': p.dy})
          .toList(),
    if (type == CanvasCardType.table) ...{
      'tableRows': tableRows,
      'tableCols': tableCols,
      if (tableCells.isNotEmpty)
        'tableCells': tableCells.map((c) => c.toJson()).toList(),
    },
    if (verticalText) 'verticalText': verticalText,
    if (fontFamily.isNotEmpty) 'fontFamily': fontFamily,
    if (textColorValue != 0xFF000000) 'textColorValue': textColorValue,
    if (latexFormula != null) 'latexFormula': latexFormula,
    if (htmlContent != null) 'htmlContent': htmlContent,
    if (customSvgData != null) 'customSvgData': customSvgData,
    if (connectionPointOffsetX != 0.5)
      'connectionPointOffsetX': connectionPointOffsetX,
    if (connectionPointOffsetY != 0.5)
      'connectionPointOffsetY': connectionPointOffsetY,
  };

  factory CanvasCard.fromJson(Map<String, dynamic> json) => CanvasCard(
    id: json['id'] as String,
    type:
        CanvasCardType.values[(json['type'] as int).clamp(
          0,
          CanvasCardType.values.length - 1,
        )],
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    colorValue: json['colorValue'] as int? ?? 0xFFFFFFFF,
    noteId: json['noteId'] as String?,
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 0,
    style: json['style'] != null
        ? CanvasCardStyle.fromJson(json['style'] as Map<String, dynamic>)
        : null,
    childIds: (json['childIds'] as List?)?.cast<String>() ?? [],
    collapsed: json['collapsed'] as bool? ?? false,
    layerId: json['layerId'] as String?,
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    textAlignH: TextAlignH.values[json['textAlignH'] as int? ?? 0],
    textAlignV: TextAlignV.values[json['textAlignV'] as int? ?? 0],
    richContent:
        (json['richContent'] as List?)
            ?.map((s) => RichTextSegment.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
    metadata: json['metadata'] != null
        ? CanvasCardMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
        : null,
    autoNumber: json['autoNumber'] as bool? ?? false,
    freehandPoints:
        (json['freehandPoints'] as List?)?.map((p) {
          final m = p as Map<String, dynamic>;
          return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
        }).toList() ??
        [],
    tableRows: json['tableRows'] as int? ?? 3,
    tableCols: json['tableCols'] as int? ?? 3,
    tableCells:
        (json['tableCells'] as List?)
            ?.map((c) => CanvasTableCell.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [],
    verticalText: json['verticalText'] as bool? ?? false,
    fontFamily: json['fontFamily'] as String? ?? '',
    textColorValue: json['textColorValue'] as int? ?? 0xFF000000,
    latexFormula: json['latexFormula'] as String?,
    htmlContent: json['htmlContent'] as String?,
    customSvgData: json['customSvgData'] as String?,
    connectionPointOffsetX:
        (json['connectionPointOffsetX'] as num?)?.toDouble() ?? 0.5,
    connectionPointOffsetY:
        (json['connectionPointOffsetY'] as num?)?.toDouble() ?? 0.5,
  );
}

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

class CanvasLayer {
  final String id;
  final String name;
  final int order;

  const CanvasLayer({required this.id, required this.name, this.order = 0});

  CanvasLayer copyWith({String? name, int? order}) =>
      CanvasLayer(id: id, name: name ?? this.name, order: order ?? this.order);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'order': order};

  factory CanvasLayer.fromJson(Map<String, dynamic> json) => CanvasLayer(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    order: json['order'] as int? ?? 0,
  );
}

enum AutoLayoutType { forceDirected, hierarchical, grid }

enum ExportFormat { png, svg, markdown }

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

class CanvasSettings {
  final bool autoConnectionsEnabled;
  final bool snapToGrid;
  final bool gridVisible;
  final DateTime lastModified;
  final int? backgroundColorValue;
  final CanvasCardStyle? defaultCardStyle;
  final CanvasConnectionStyle? defaultConnectionStyle;
  final bool rulersVisible;

  CanvasSettings({
    this.autoConnectionsEnabled = true,
    this.snapToGrid = true,
    this.gridVisible = true,
    DateTime? lastModified,
    this.backgroundColorValue,
    this.defaultCardStyle,
    this.defaultConnectionStyle,
    this.rulersVisible = false,
  }) : lastModified = lastModified ?? DateTime.now();

  CanvasSettings copyWith({
    bool? autoConnectionsEnabled,
    bool? snapToGrid,
    bool? gridVisible,
    DateTime? lastModified,
    int? backgroundColorValue,
    bool clearBackgroundColor = false,
    CanvasCardStyle? defaultCardStyle,
    bool clearDefaultCardStyle = false,
    CanvasConnectionStyle? defaultConnectionStyle,
    bool clearDefaultConnectionStyle = false,
    bool? rulersVisible,
  }) {
    return CanvasSettings(
      autoConnectionsEnabled:
          autoConnectionsEnabled ?? this.autoConnectionsEnabled,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      gridVisible: gridVisible ?? this.gridVisible,
      lastModified: lastModified ?? this.lastModified,
      backgroundColorValue: clearBackgroundColor
          ? null
          : (backgroundColorValue ?? this.backgroundColorValue),
      defaultCardStyle: clearDefaultCardStyle
          ? null
          : (defaultCardStyle ?? this.defaultCardStyle),
      defaultConnectionStyle: clearDefaultConnectionStyle
          ? null
          : (defaultConnectionStyle ?? this.defaultConnectionStyle),
      rulersVisible: rulersVisible ?? this.rulersVisible,
    );
  }

  Map<String, dynamic> toJson() => {
    'autoConnectionsEnabled': autoConnectionsEnabled,
    'snapToGrid': snapToGrid,
    'gridVisible': gridVisible,
    'lastModified': lastModified.toIso8601String(),
    if (backgroundColorValue != null)
      'backgroundColorValue': backgroundColorValue,
    if (defaultCardStyle != null)
      'defaultCardStyle': defaultCardStyle!.toJson(),
    if (defaultConnectionStyle != null)
      'defaultConnectionStyle': defaultConnectionStyle!.toJson(),
    'rulersVisible': rulersVisible,
  };

  factory CanvasSettings.fromJson(Map<String, dynamic> json) => CanvasSettings(
    autoConnectionsEnabled: json['autoConnectionsEnabled'] as bool? ?? true,
    snapToGrid: json['snapToGrid'] as bool? ?? true,
    gridVisible: json['gridVisible'] as bool? ?? true,
    lastModified: json['lastModified'] != null
        ? DateTime.tryParse(json['lastModified'] as String)
        : null,
    backgroundColorValue: json['backgroundColorValue'] as int?,
    defaultCardStyle: json['defaultCardStyle'] != null
        ? CanvasCardStyle.fromJson(
            json['defaultCardStyle'] as Map<String, dynamic>,
          )
        : null,
    defaultConnectionStyle: json['defaultConnectionStyle'] != null
        ? CanvasConnectionStyle.fromJson(
            json['defaultConnectionStyle'] as Map<String, dynamic>,
          )
        : null,
    rulersVisible: json['rulersVisible'] as bool? ?? false,
  );
}

class CanvasSearchState {
  final String query;
  final List<String> matchedCardIds;
  final int activeIndex;

  const CanvasSearchState({
    this.query = '',
    this.matchedCardIds = const [],
    this.activeIndex = 0,
  });

  bool get isActive => query.isNotEmpty;

  CanvasSearchState copyWith({
    String? query,
    List<String>? matchedCardIds,
    int? activeIndex,
  }) {
    return CanvasSearchState(
      query: query ?? this.query,
      matchedCardIds: matchedCardIds ?? this.matchedCardIds,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class CanvasData {
  static const unassignedSentinel = '__unassigned__';

  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final List<CanvasGroup> groups;
  final List<CanvasLayer> layers;
  final CanvasSettings settings;
  final List<String> selectedCardIds;
  final String? inlineEditingCardId;
  final String? selectedConnectionId;
  final String? selectedLayerId;

  CanvasData({
    this.cards = const [],
    this.connections = const [],
    this.groups = const [],
    this.layers = const [],
    CanvasSettings? settings,
    this.selectedCardIds = const [],
    this.inlineEditingCardId,
    this.selectedConnectionId,
    this.selectedLayerId,
  }) : settings = settings ?? CanvasSettings();

  CanvasData copyWith({
    List<CanvasCard>? cards,
    List<CanvasConnection>? connections,
    List<CanvasGroup>? groups,
    List<CanvasLayer>? layers,
    CanvasSettings? settings,
    List<String>? selectedCardIds,
    String? inlineEditingCardId,
    String? selectedConnectionId,
    bool clearSelectedCardIds = false,
    bool clearInlineEditingCardId = false,
    bool clearSelectedConnectionId = false,
    String? selectedLayerId,
    bool clearSelectedLayerId = false,
  }) {
    return CanvasData(
      cards: cards ?? this.cards,
      connections: connections ?? this.connections,
      groups: groups ?? this.groups,
      layers: layers ?? this.layers,
      settings: settings ?? this.settings,
      selectedCardIds: clearSelectedCardIds
          ? []
          : (selectedCardIds ?? this.selectedCardIds),
      inlineEditingCardId: clearInlineEditingCardId
          ? null
          : (inlineEditingCardId ?? this.inlineEditingCardId),
      selectedConnectionId: clearSelectedConnectionId
          ? null
          : (selectedConnectionId ?? this.selectedConnectionId),
      selectedLayerId: clearSelectedLayerId
          ? null
          : (selectedLayerId ?? this.selectedLayerId),
    );
  }

  String toJsonString() => jsonEncode({
    'cards': cards.map((c) => c.toJson()).toList(),
    'connections': connections.map((c) => c.toJson()).toList(),
    'groups': groups.map((g) => g.toJson()).toList(),
    'layers': layers.map((l) => l.toJson()).toList(),
    'settings': settings.toJson(),
    if (selectedLayerId != null) 'selectedLayerId': selectedLayerId,
  });

  factory CanvasData.fromJsonString(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return CanvasData(
        cards:
            (data['cards'] as List?)
                ?.map((e) => CanvasCard.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        connections:
            (data['connections'] as List?)
                ?.map(
                  (e) => CanvasConnection.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        groups:
            (data['groups'] as List?)
                ?.map((e) => CanvasGroup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        layers:
            (data['layers'] as List?)
                ?.map((e) => CanvasLayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        settings: data['settings'] != null
            ? CanvasSettings.fromJson(data['settings'] as Map<String, dynamic>)
            : CanvasSettings(),
        selectedLayerId: data['selectedLayerId'] as String?,
      );
    } catch (_) {
      debugPrint('CanvasData: failed to parse JSON');
      return CanvasData();
    }
  }
}

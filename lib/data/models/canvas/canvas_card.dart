import 'package:flutter/material.dart';

import 'canvas_card_metadata.dart';
import 'canvas_card_style.dart';
import 'canvas_card_type.dart';
import 'canvas_text.dart';

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
  final String? imagePath;

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
    this.imagePath,
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
    String? imagePath,
    bool clearImage = false,
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
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
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
    if (imagePath != null) 'imagePath': imagePath,
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
    imagePath: json['imagePath'] as String?,
  );
}

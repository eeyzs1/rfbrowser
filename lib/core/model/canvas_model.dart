import 'dart:convert';
import 'package:flutter/material.dart';

enum CanvasCardType {
  note,
  image,
  link,
  text;

  String get label => switch (this) {
        CanvasCardType.note => 'Note',
        CanvasCardType.image => 'Image',
        CanvasCardType.link => 'Link',
        CanvasCardType.text => 'Text',
      };

  IconData get icon => switch (this) {
        CanvasCardType.note => Icons.description,
        CanvasCardType.image => Icons.image,
        CanvasCardType.link => Icons.link,
        CanvasCardType.text => Icons.text_fields,
      };
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

  const CanvasCard({
    required this.id,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 240,
    this.height = 160,
    this.title = '',
    this.content = '',
    this.colorValue = 0xFFFFFFFF,
    this.noteId,
  });

  CanvasCard copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? title,
    String? content,
    int? colorValue,
    String? noteId,
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
      };

  factory CanvasCard.fromJson(Map<String, dynamic> json) => CanvasCard(
        id: json['id'] as String,
        type: CanvasCardType.values[json['type'] as int],
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        colorValue: json['colorValue'] as int? ?? 0xFFFFFFFF,
        noteId: json['noteId'] as String?,
      );
}

enum ConnectionSide {
  top,
  bottom,
  left,
  right;

  Offset point(Rect rect) => switch (this) {
        ConnectionSide.top => Offset(rect.center.dx, rect.top),
        ConnectionSide.bottom => Offset(rect.center.dx, rect.bottom),
        ConnectionSide.left => Offset(rect.left, rect.center.dy),
        ConnectionSide.right => Offset(rect.right, rect.center.dy),
      };
}

class CanvasConnection {
  final String id;
  final String fromCardId;
  final String toCardId;
  final ConnectionSide fromSide;
  final ConnectionSide toSide;
  final String label;

  const CanvasConnection({
    required this.id,
    required this.fromCardId,
    required this.toCardId,
    this.fromSide = ConnectionSide.right,
    this.toSide = ConnectionSide.left,
    this.label = '',
  });

  CanvasConnection copyWith({String? label}) => CanvasConnection(
        id: id,
        fromCardId: fromCardId,
        toCardId: toCardId,
        fromSide: fromSide,
        toSide: toSide,
        label: label ?? this.label,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromCardId': fromCardId,
        'toCardId': toCardId,
        'fromSide': fromSide.index,
        'toSide': toSide.index,
        'label': label,
      };

  factory CanvasConnection.fromJson(Map<String, dynamic> json) =>
      CanvasConnection(
        id: json['id'] as String,
        fromCardId: json['fromCardId'] as String,
        toCardId: json['toCardId'] as String,
        fromSide:
            ConnectionSide.values[json['fromSide'] as int? ?? 3],
        toSide: ConnectionSide.values[json['toSide'] as int? ?? 2],
        label: json['label'] as String? ?? '',
      );
}

class CanvasData {
  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;

  const CanvasData({
    this.cards = const [],
    this.connections = const [],
  });

  CanvasData copyWith({
    List<CanvasCard>? cards,
    List<CanvasConnection>? connections,
  }) {
    return CanvasData(
      cards: cards ?? this.cards,
      connections: connections ?? this.connections,
    );
  }

  String toJsonString() => jsonEncode({
        'cards': cards.map((c) => c.toJson()).toList(),
        'connections': connections.map((c) => c.toJson()).toList(),
      });

  factory CanvasData.fromJsonString(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return CanvasData(
        cards: (data['cards'] as List?)
                ?.map((e) => CanvasCard.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        connections: (data['connections'] as List?)
                ?.map(
                    (e) => CanvasConnection.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (_) {
      return const CanvasData();
    }
  }
}

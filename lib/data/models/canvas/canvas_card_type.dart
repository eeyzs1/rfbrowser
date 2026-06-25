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

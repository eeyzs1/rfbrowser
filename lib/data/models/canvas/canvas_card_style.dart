import 'canvas_card_type.dart';

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

import 'canvas_card_style.dart';
import 'canvas_connection.dart';

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

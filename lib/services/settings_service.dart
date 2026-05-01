import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppButtonStyle { rounded, sharp, pill }

enum ComponentDensity { compact, comfortable, spacious }

enum IconSize { small, medium, large }

class AppSettings {
  final String locale;
  final bool isDarkMode;
  final String activeModel;
  final double editorFontSize;
  final bool showLineNumbers;
  final String themePreset;
  final int? accentColorValue;
  final AppButtonStyle buttonStyle;
  final ComponentDensity density;
  final IconSize iconSize;
  final double borderRadius;

  AppSettings({
    this.locale = 'en',
    this.isDarkMode = true,
    this.activeModel = 'gpt-4o',
    this.editorFontSize = 14.0,
    this.showLineNumbers = false,
    this.themePreset = 'sky',
    this.accentColorValue,
    this.buttonStyle = AppButtonStyle.rounded,
    this.density = ComponentDensity.comfortable,
    this.iconSize = IconSize.medium,
    this.borderRadius = 8.0,
  });

  Color get accentColor =>
      accentColorValue != null ? Color(accentColorValue!) : _presetColor;

  Color get _presetColor {
    switch (themePreset) {
      case 'sky':
        return const Color(0xFF0EA5E9);
      case 'violet':
        return const Color(0xFF8B5CF6);
      case 'rose':
        return const Color(0xFFF43F5E);
      case 'emerald':
        return const Color(0xFF10B981);
      case 'amber':
        return const Color(0xFFF59E0B);
      case 'custom':
        return accentColor;
      default:
        return const Color(0xFF0EA5E9);
    }
  }

  double get effectiveBorderRadius {
    switch (buttonStyle) {
      case AppButtonStyle.sharp:
        return 2.0;
      case AppButtonStyle.pill:
        return 100.0;
      case AppButtonStyle.rounded:
        return borderRadius;
    }
  }

  double get effectiveIconSize {
    switch (iconSize) {
      case IconSize.small:
        return 16.0;
      case IconSize.medium:
        return 18.0;
      case IconSize.large:
        return 22.0;
    }
  }

  VisualDensity get effectiveVisualDensity {
    switch (density) {
      case ComponentDensity.compact:
        return VisualDensity.compact;
      case ComponentDensity.comfortable:
        return VisualDensity.standard;
      case ComponentDensity.spacious:
        return const VisualDensity(horizontal: 0, vertical: 2);
    }
  }

  AppSettings copyWith({
    String? locale,
    bool? isDarkMode,
    String? activeModel,
    double? editorFontSize,
    bool? showLineNumbers,
    String? themePreset,
    int? accentColorValue,
    bool clearAccentColor = false,
    AppButtonStyle? buttonStyle,
    ComponentDensity? density,
    IconSize? iconSize,
    double? borderRadius,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      activeModel: activeModel ?? this.activeModel,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      themePreset: themePreset ?? this.themePreset,
      accentColorValue: clearAccentColor
          ? null
          : (accentColorValue ?? this.accentColorValue),
      buttonStyle: buttonStyle ?? this.buttonStyle,
      density: density ?? this.density,
      iconSize: iconSize ?? this.iconSize,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final _secureStorage = const FlutterSecureStorage();
  String? _apiKey;

  SettingsNotifier() : super(AppSettings());

  String? get apiKey => _apiKey;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = await _secureStorage.read(key: 'api_key');
    state = AppSettings(
      locale: prefs.getString('locale') ?? 'en',
      isDarkMode: prefs.getBool('isDarkMode') ?? true,
      activeModel: prefs.getString('activeModel') ?? 'gpt-4o',
      editorFontSize: prefs.getDouble('editorFontSize') ?? 14.0,
      showLineNumbers: prefs.getBool('showLineNumbers') ?? false,
      themePreset: prefs.getString('themePreset') ?? 'sky',
      accentColorValue: prefs.getInt('accentColorValue'),
      buttonStyle: AppButtonStyle.values[prefs.getInt('buttonStyle') ?? 0],
      density: ComponentDensity.values[prefs.getInt('density') ?? 1],
      iconSize: IconSize.values[prefs.getInt('iconSize') ?? 1],
      borderRadius: prefs.getDouble('borderRadius') ?? 8.0,
    );
  }

  Future<void> setLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    state = state.copyWith(locale: locale);
  }

  Future<void> toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', !state.isDarkMode);
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: 'api_key', value: key);
    _apiKey = key;
  }

  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: 'api_key');
    _apiKey = null;
  }

  Future<void> setActiveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeModel', model);
    state = state.copyWith(activeModel: model);
  }

  Future<void> setEditorFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('editorFontSize', size);
    state = state.copyWith(editorFontSize: size);
  }

  Future<void> setThemePreset(String preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themePreset', preset);
    state = state.copyWith(
      themePreset: preset,
      clearAccentColor: preset != 'custom',
    );
  }

  Future<void> setAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColorValue', color.toARGB32());
    state = state.copyWith(
      themePreset: 'custom',
      accentColorValue: color.toARGB32(),
    );
  }

  Future<void> setButtonStyle(AppButtonStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('buttonStyle', style.index);
    state = state.copyWith(buttonStyle: style);
  }

  Future<void> setDensity(ComponentDensity d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('density', d.index);
    state = state.copyWith(density: d);
  }

  Future<void> setIconSize(IconSize s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('iconSize', s.index);
    state = state.copyWith(iconSize: s);
  }

  Future<void> setBorderRadius(double r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('borderRadius', r);
    state = state.copyWith(borderRadius: r);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});

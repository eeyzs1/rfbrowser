import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/shared_prefs_aware.dart';
import '../data/models/memory_settings.dart';

// Re-export AI config types so existing imports of `settings_service.dart`
// continue to work after the AI config code was extracted to its own file.
export 'ai_config_service.dart';

part 'settings_memory_setters.dart';

enum AppButtonStyle { rounded, sharp, pill }

enum ComponentDensity { compact, comfortable, spacious }

const _presetColors = <String, Color>{
  'sky': Color(0xFF0EA5E9),
  'violet': Color(0xFF8B5CF6),
  'rose': Color(0xFFF43F5E),
  'emerald': Color(0xFF10B981),
  'amber': Color(0xFFF59E0B),
  'indigo': Color(0xFF6366F1),
  'teal': Color(0xFF14B8A6),
  'orange': Color(0xFFF97316),
  'pink': Color(0xFFEC4899),
  'slate': Color(0xFF64748B),
};

Color getPresetColor(String id) => _presetColors[id] ?? const Color(0xFF0EA5E9);

class AppSettings {
  final String locale;
  final double editorFontSize;
  final bool showLineNumbers;
  final String themePreset;
  final int accentColorValue;
  final int scaffoldBgColorValue;
  final int surfaceColorValue;
  /// Custom font/text color. When null, text color is auto-derived from the
  /// surface color (light text on dark surfaces, dark text on light surfaces).
  final int? fontColorValue;
  final AppButtonStyle buttonStyle;
  final ComponentDensity density;
  final int iconSize;
  final double borderRadius;
  final bool alwaysShowWelcomePage;
  final bool highContrastMode;
  final double themeTintOpacity;
  final double surfaceOpacity;
  final double backgroundOpacity;
  final String searchEngine;
  final ThemeMode themeMode;

  // ── Memory subsystem (progressive forgetting + Hebbian) ──────────
  /// All memory-related configuration. See [MemorySettings] for the
  /// individual field docs. Persisted to SharedPreferences with the
  /// legacy `memory*` key names for backward compatibility.
  final MemorySettings memory;

  AppSettings({
    this.locale = 'system',
    this.editorFontSize = 14.0,
    this.showLineNumbers = false,
    this.themePreset = 'sky',
    this.accentColorValue = 0xFF0EA5E9,
    this.scaffoldBgColorValue = 0xFF0F172A,
    this.surfaceColorValue = 0xFF1E293B,
    this.fontColorValue,
    this.buttonStyle = AppButtonStyle.rounded,
    this.density = ComponentDensity.comfortable,
    this.iconSize = 18,
    this.borderRadius = 8.0,
    this.alwaysShowWelcomePage = false,
    this.highContrastMode = false,
    this.themeTintOpacity = 0.8,
    this.surfaceOpacity = 1.0,
    this.backgroundOpacity = 1.0,
    this.searchEngine = 'bing',
    this.themeMode = ThemeMode.system,
    this.memory = const MemorySettings(),
  });

  Color get accentColor => Color(accentColorValue);

  Color get scaffoldBgColor => Color(scaffoldBgColorValue);

  Color get surfaceColor => Color(surfaceColorValue);

  /// Returns the custom font color if set, otherwise null (auto-derive).
  Color? get fontColor => fontColorValue != null ? Color(fontColorValue!) : null;

  /// 根据 [themeMode] 判断是否为暗色模式：
  /// - [ThemeMode.system]：跟随系统亮度
  /// - [ThemeMode.light]：始终返回 false
  /// - [ThemeMode.dark]：始终返回 true
  bool get isDarkMode {
    switch (themeMode) {
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
      case ThemeMode.system:
        return WidgetsBinding
                .instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
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
    double? editorFontSize,
    bool? showLineNumbers,
    String? themePreset,
    int? accentColorValue,
    int? scaffoldBgColorValue,
    int? surfaceColorValue,
    int? fontColorValue,
    bool clearFontColor = false,
    AppButtonStyle? buttonStyle,
    ComponentDensity? density,
    int? iconSize,
    double? borderRadius,
    bool? alwaysShowWelcomePage,
    bool? highContrastMode,
    double? themeTintOpacity,
    double? surfaceOpacity,
    double? backgroundOpacity,
    String? searchEngine,
    ThemeMode? themeMode,
    MemorySettings? memory,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      themePreset: themePreset ?? this.themePreset,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      scaffoldBgColorValue: scaffoldBgColorValue ?? this.scaffoldBgColorValue,
      surfaceColorValue: surfaceColorValue ?? this.surfaceColorValue,
      fontColorValue: clearFontColor ? null : (fontColorValue ?? this.fontColorValue),
      buttonStyle: buttonStyle ?? this.buttonStyle,
      density: density ?? this.density,
      iconSize: iconSize ?? this.iconSize,
      borderRadius: borderRadius ?? this.borderRadius,
      alwaysShowWelcomePage:
          alwaysShowWelcomePage ?? this.alwaysShowWelcomePage,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      themeTintOpacity: themeTintOpacity ?? this.themeTintOpacity,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      searchEngine: searchEngine ?? this.searchEngine,
      themeMode: themeMode ?? this.themeMode,
      memory: memory ?? this.memory,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings>
    with SharedPrefsAware, _MemorySettersMixin {
  @override
  AppSettings build() => AppSettings();

  Future<void> loadSettings() async {
    final prefs = await ensurePrefs;
    final preset = prefs.getString('themePreset') ?? 'sky';
    final savedColor = prefs.getInt('accentColorValue');
    final colorValue = savedColor ?? getPresetColor(preset).toARGB32();
    // 读取持久化的 themeMode，默认跟随系统
    final savedThemeMode = prefs.getString('themeMode') ?? 'system';
    final themeMode = _parseThemeMode(savedThemeMode);
    state = AppSettings(
      locale: prefs.getString('locale') ?? 'system',
      editorFontSize: prefs.getDouble('editorFontSize') ?? 14.0,
      showLineNumbers: prefs.getBool('showLineNumbers') ?? false,
      themePreset: preset,
      accentColorValue: colorValue,
      scaffoldBgColorValue: prefs.getInt('scaffoldBgColorValue') ?? 0xFF0F172A,
      surfaceColorValue: prefs.getInt('surfaceColorValue') ?? 0xFF1E293B,
      fontColorValue: prefs.getInt('fontColorValue'),
      buttonStyle: AppButtonStyle.values[prefs.getInt('buttonStyle') ?? 0],
      density: ComponentDensity.values[prefs.getInt('density') ?? 1],
      iconSize: (prefs.getInt('iconSize') ?? 18).clamp(12, 36),
      borderRadius: prefs.getDouble('borderRadius') ?? 8.0,
      alwaysShowWelcomePage: prefs.getBool('alwaysShowWelcomePage') ?? false,
      highContrastMode: prefs.getBool('highContrastMode') ?? false,
      themeTintOpacity: prefs.getDouble('themeTintOpacity') ?? 0.8,
      surfaceOpacity: prefs.getDouble('surfaceOpacity') ?? 1.0,
      backgroundOpacity: prefs.getDouble('backgroundOpacity') ?? 1.0,
      searchEngine: prefs.getString('searchEngine') ?? 'bing',
      themeMode: themeMode,
      memory: MemorySettings.fromPrefs(prefs),
    );
  }

  /// 将字符串解析为 [ThemeMode]，默认返回 [ThemeMode.system]。
  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Future<void> _updateSetting<T>({
    required String key,
    required T value,
    required Future<void> Function(SharedPreferences, String, T) persist,
    required AppSettings Function(AppSettings, T) update,
  }) async {
    final prefs = await ensurePrefs;
    await persist(prefs, key, value);
    state = update(state, value);
  }

  Future<void> setLocale(String locale) async {
    await _updateSetting(
      key: 'locale',
      value: locale,
      persist: (p, k, v) => p.setString(k, v),
      update: (s, v) => s.copyWith(locale: v),
    );
  }

  Future<void> setEditorFontSize(double size) async {
    await _updateSetting(
      key: 'editorFontSize',
      value: size,
      persist: (p, k, v) => p.setDouble(k, v),
      update: (s, v) => s.copyWith(editorFontSize: v),
    );
  }

  /// Live update for slider dragging — updates state immediately without
  /// disk I/O so the UI stays responsive. Call [setEditorFontSize] on
  /// drag end to persist.
  void setEditorFontSizeLive(double size) {
    state = state.copyWith(editorFontSize: size);
  }

  Future<void> setThemePreset(String preset) async {
    final color = getPresetColor(preset);
    final prefs = await ensurePrefs;
    await prefs.setString('themePreset', preset);
    await prefs.setInt('accentColorValue', color.toARGB32());
    state = state.copyWith(
      themePreset: preset,
      accentColorValue: color.toARGB32(),
    );
  }

  Future<void> setAccentColor(Color color) async {
    final prefs = await ensurePrefs;
    await prefs.setString('themePreset', 'custom');
    await prefs.setInt('accentColorValue', color.toARGB32());
    state = state.copyWith(
      themePreset: 'custom',
      accentColorValue: color.toARGB32(),
    );
  }

  Future<void> setScaffoldBgColor(Color color) async {
    await _updateSetting(
      key: 'scaffoldBgColorValue',
      value: color.toARGB32(),
      persist: (p, k, v) => p.setInt(k, v),
      update: (s, v) => s.copyWith(scaffoldBgColorValue: v),
    );
  }

  Future<void> setSurfaceColor(Color color) async {
    await _updateSetting(
      key: 'surfaceColorValue',
      value: color.toARGB32(),
      persist: (p, k, v) => p.setInt(k, v),
      update: (s, v) => s.copyWith(surfaceColorValue: v),
    );
  }

  Future<void> setFontColor(Color color) async {
    await _updateSetting(
      key: 'fontColorValue',
      value: color.toARGB32(),
      persist: (p, k, v) => p.setInt(k, v),
      update: (s, v) => s.copyWith(fontColorValue: v),
    );
  }

  Future<void> clearFontColor() async {
    final prefs = await ensurePrefs;
    await prefs.remove('fontColorValue');
    state = state.copyWith(clearFontColor: true);
  }

  Future<void> setButtonStyle(AppButtonStyle style) async {
    await _updateSetting(
      key: 'buttonStyle',
      value: style.index,
      persist: (p, k, v) => p.setInt(k, v),
      update: (s, v) => s.copyWith(buttonStyle: style),
    );
  }

  Future<void> setDensity(ComponentDensity d) async {
    await _updateSetting(
      key: 'density',
      value: d.index,
      persist: (p, k, v) => p.setInt(k, v),
      update: (s, v) => s.copyWith(density: d),
    );
  }

  Future<void> setIconSize(int size) async {
    await _updateSetting(
      key: 'iconSize',
      value: size,
      persist: (p, k, v) => p.setInt(k, v),
      update: (s, v) => s.copyWith(iconSize: v),
    );
  }

  /// Live update for icon size slider — no disk I/O during drag.
  void setIconSizeLive(int size) {
    state = state.copyWith(iconSize: size);
  }

  Future<void> setBorderRadius(double r) async {
    await _updateSetting(
      key: 'borderRadius',
      value: r,
      persist: (p, k, v) => p.setDouble(k, v),
      update: (s, v) => s.copyWith(borderRadius: v),
    );
  }

  /// Live update for border radius slider — no disk I/O during drag.
  void setBorderRadiusLive(double r) {
    state = state.copyWith(borderRadius: r);
  }

  Future<void> setAlwaysShowWelcomePage(bool value) async {
    await _updateSetting(
      key: 'alwaysShowWelcomePage',
      value: value,
      persist: (p, k, v) => p.setBool(k, v),
      update: (s, v) => s.copyWith(alwaysShowWelcomePage: v),
    );
  }

  Future<void> setHighContrastMode(bool value) async {
    await _updateSetting(
      key: 'highContrastMode',
      value: value,
      persist: (p, k, v) => p.setBool(k, v),
      update: (s, v) => s.copyWith(highContrastMode: v),
    );
  }

  Future<void> setThemeTintOpacity(double value) async {
    await _updateSetting(
      key: 'themeTintOpacity',
      value: value,
      persist: (p, k, v) => p.setDouble(k, v),
      update: (s, v) => s.copyWith(themeTintOpacity: v),
    );
  }

  /// Live update for theme tint opacity slider — no disk I/O during drag.
  void setThemeTintOpacityLive(double value) {
    state = state.copyWith(themeTintOpacity: value);
  }

  Future<void> setSurfaceOpacity(double value) async {
    await _updateSetting(
      key: 'surfaceOpacity',
      value: value,
      persist: (p, k, v) => p.setDouble(k, v),
      update: (s, v) => s.copyWith(surfaceOpacity: v),
    );
  }

  /// Live update for surface opacity slider — no disk I/O during drag.
  void setSurfaceOpacityLive(double value) {
    state = state.copyWith(surfaceOpacity: value);
  }

  Future<void> setBackgroundOpacity(double value) async {
    await _updateSetting(
      key: 'backgroundOpacity',
      value: value,
      persist: (p, k, v) => p.setDouble(k, v),
      update: (s, v) => s.copyWith(backgroundOpacity: v),
    );
  }

  /// Live update for background opacity slider — no disk I/O during drag.
  void setBackgroundOpacityLive(double value) {
    state = state.copyWith(backgroundOpacity: value);
  }

  Future<void> setSearchEngine(String engine) async {
    await _updateSetting(
      key: 'searchEngine',
      value: engine,
      persist: (p, k, v) => p.setString(k, v),
      update: (s, v) => s.copyWith(searchEngine: v),
    );
  }

  /// 设置主题模式（system/light/dark），持久化到 SharedPreferences。
  Future<void> setThemeMode(ThemeMode mode) async {
    final modeString = switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
    await _updateSetting(
      key: 'themeMode',
      value: modeString,
      persist: (p, k, v) => p.setString(k, v),
      update: (s, v) => s.copyWith(themeMode: mode),
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);


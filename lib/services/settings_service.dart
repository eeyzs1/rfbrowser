import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models/ai_provider.dart';
import '../core/color_extensions.dart';
import '../core/shared_prefs_aware.dart';

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

  // ── Memory subsystem (progressive forgetting + Hebbian) ──────────
  /// Whether the ambient [RequestContext] is injected into AI prompts.
  final bool memoryInjectContext;

  /// Threshold below which a `short`-tier fragment is migrated to `mid`.
  final double memoryShortToMidThreshold;

  /// Threshold below which a `mid`-tier fragment is migrated to `long`.
  final double memoryMidToLongThreshold;

  /// Number of days a fragment must live in `short` tier before being
  /// considered for migration to `mid`. Mirrors the OpenLoomi policy.
  final int memoryShortMaxAgeDays;

  /// Number of days a fragment must live in `mid` tier before being
  /// considered for migration to `long`.
  final int memoryMidMaxAgeDays;

  /// Co-access window for Hebbian edge reinforcement (minutes).
  final int memoryHebbianCoAccessMinutes;

  /// Hebbian edge decay constant (days to fall to 1/e).
  final int memoryHebbianDecayDays;

  /// How many chat messages between auto-Markdown exports. 0 disables.
  final int memoryAutoExportEveryNMessages;

  /// Whether the dreaming engine runs in the background automatically.
  final bool memoryDreamingEnabled;

  /// Half-life of the createdAt recency signal (days). Longer = facts
  /// are treated as "still fresh" for longer. Default 180.
  final int memoryCreatedRecencyHalfLifeDays;

  /// Half-life of the lastAccessAt recency signal (days). Shorter than
  /// the created half-life so that "actively used" is a sharper signal.
  /// Default 30.
  final int memoryAccessRecencyHalfLifeDays;

  /// Master switch for the dual-time-signal scoring. When false the
  /// scorer falls back to the original createdAt-only behavior.
  final bool memoryUseLastAccessForRecency;

  /// Maximum approximate token count the memory subsystem will inject
  /// into the AI's system prompt. Fragments are dropped in
  /// importance-ascending order until the budget is met. Default 800
  /// (≈ 3200 characters), which is roughly 5 short fragments.
  final int memoryContextBudget;

  /// When true, the LLM is asked to summarize fragments during
  /// dreaming cycles (requires a configured AI provider). When false
  /// the system uses the rule-based summarizer which has zero cost.
  final bool memoryUseLlmSummarizer;

  /// When true, recall is re-ranked by the LLM after the FTS+Hebbian
  /// pass. Disabled by default since it adds latency to every AI
  /// request.
  final bool memoryUseLlmRerank;

  AppSettings({
    this.locale = 'system',
    this.editorFontSize = 14.0,
    this.showLineNumbers = false,
    this.themePreset = 'sky',
    this.accentColorValue = 0xFF0EA5E9,
    this.scaffoldBgColorValue = 0xFF0F172A,
    this.surfaceColorValue = 0xFF1E293B,
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
    this.memoryInjectContext = true,
    this.memoryShortToMidThreshold = 0.65,
    this.memoryMidToLongThreshold = 0.45,
    this.memoryShortMaxAgeDays = 7,
    this.memoryMidMaxAgeDays = 30,
    this.memoryHebbianCoAccessMinutes = 5,
    this.memoryHebbianDecayDays = 30,
    this.memoryAutoExportEveryNMessages = 16,
    this.memoryDreamingEnabled = true,
    this.memoryCreatedRecencyHalfLifeDays = 180,
    this.memoryAccessRecencyHalfLifeDays = 30,
    this.memoryUseLastAccessForRecency = true,
    this.memoryContextBudget = 800,
    this.memoryUseLlmSummarizer = false,
    this.memoryUseLlmRerank = false,
  });

  Color get accentColor => Color(accentColorValue);

  Color get scaffoldBgColor => Color(scaffoldBgColorValue);

  Color get surfaceColor => Color(surfaceColorValue);

  bool get isDarkMode => scaffoldBgColor.isDark;

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
    bool? memoryInjectContext,
    double? memoryShortToMidThreshold,
    double? memoryMidToLongThreshold,
    int? memoryShortMaxAgeDays,
    int? memoryMidMaxAgeDays,
    int? memoryHebbianCoAccessMinutes,
    int? memoryHebbianDecayDays,
    int? memoryAutoExportEveryNMessages,
    bool? memoryDreamingEnabled,
    int? memoryCreatedRecencyHalfLifeDays,
    int? memoryAccessRecencyHalfLifeDays,
    bool? memoryUseLastAccessForRecency,
    int? memoryContextBudget,
    bool? memoryUseLlmSummarizer,
    bool? memoryUseLlmRerank,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      themePreset: themePreset ?? this.themePreset,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      scaffoldBgColorValue: scaffoldBgColorValue ?? this.scaffoldBgColorValue,
      surfaceColorValue: surfaceColorValue ?? this.surfaceColorValue,
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
      memoryInjectContext: memoryInjectContext ?? this.memoryInjectContext,
      memoryShortToMidThreshold:
          memoryShortToMidThreshold ?? this.memoryShortToMidThreshold,
      memoryMidToLongThreshold:
          memoryMidToLongThreshold ?? this.memoryMidToLongThreshold,
      memoryShortMaxAgeDays:
          memoryShortMaxAgeDays ?? this.memoryShortMaxAgeDays,
      memoryMidMaxAgeDays: memoryMidMaxAgeDays ?? this.memoryMidMaxAgeDays,
      memoryHebbianCoAccessMinutes:
          memoryHebbianCoAccessMinutes ?? this.memoryHebbianCoAccessMinutes,
      memoryHebbianDecayDays:
          memoryHebbianDecayDays ?? this.memoryHebbianDecayDays,
      memoryAutoExportEveryNMessages:
          memoryAutoExportEveryNMessages ?? this.memoryAutoExportEveryNMessages,
      memoryDreamingEnabled:
          memoryDreamingEnabled ?? this.memoryDreamingEnabled,
      memoryCreatedRecencyHalfLifeDays:
          memoryCreatedRecencyHalfLifeDays ??
          this.memoryCreatedRecencyHalfLifeDays,
      memoryAccessRecencyHalfLifeDays:
          memoryAccessRecencyHalfLifeDays ??
          this.memoryAccessRecencyHalfLifeDays,
      memoryUseLastAccessForRecency:
          memoryUseLastAccessForRecency ?? this.memoryUseLastAccessForRecency,
      memoryContextBudget: memoryContextBudget ?? this.memoryContextBudget,
      memoryUseLlmSummarizer:
          memoryUseLlmSummarizer ?? this.memoryUseLlmSummarizer,
      memoryUseLlmRerank: memoryUseLlmRerank ?? this.memoryUseLlmRerank,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> with SharedPrefsAware {
  @override
  AppSettings build() => AppSettings();

  Future<void> loadSettings() async {
    final prefs = await ensurePrefs;
    final preset = prefs.getString('themePreset') ?? 'sky';
    final savedColor = prefs.getInt('accentColorValue');
    final colorValue = savedColor ?? getPresetColor(preset).toARGB32();
    state = AppSettings(
      locale: prefs.getString('locale') ?? 'system',
      editorFontSize: prefs.getDouble('editorFontSize') ?? 14.0,
      showLineNumbers: prefs.getBool('showLineNumbers') ?? false,
      themePreset: preset,
      accentColorValue: colorValue,
      scaffoldBgColorValue: prefs.getInt('scaffoldBgColorValue') ?? 0xFF0F172A,
      surfaceColorValue: prefs.getInt('surfaceColorValue') ?? 0xFF1E293B,
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
      memoryInjectContext: prefs.getBool('memoryInjectContext') ?? true,
      memoryShortToMidThreshold:
          prefs.getDouble('memoryShortToMidThreshold') ?? 0.65,
      memoryMidToLongThreshold:
          prefs.getDouble('memoryMidToLongThreshold') ?? 0.45,
      memoryShortMaxAgeDays: prefs.getInt('memoryShortMaxAgeDays') ?? 7,
      memoryMidMaxAgeDays: prefs.getInt('memoryMidMaxAgeDays') ?? 30,
      memoryHebbianCoAccessMinutes:
          prefs.getInt('memoryHebbianCoAccessMinutes') ?? 5,
      memoryHebbianDecayDays: prefs.getInt('memoryHebbianDecayDays') ?? 30,
      memoryAutoExportEveryNMessages:
          prefs.getInt('memoryAutoExportEveryNMessages') ?? 16,
      memoryDreamingEnabled: prefs.getBool('memoryDreamingEnabled') ?? true,
      memoryCreatedRecencyHalfLifeDays:
          prefs.getInt('memoryCreatedRecencyHalfLifeDays') ?? 180,
      memoryAccessRecencyHalfLifeDays:
          prefs.getInt('memoryAccessRecencyHalfLifeDays') ?? 30,
      memoryUseLastAccessForRecency:
          prefs.getBool('memoryUseLastAccessForRecency') ?? true,
      memoryContextBudget: prefs.getInt('memoryContextBudget') ?? 800,
      memoryUseLlmSummarizer: prefs.getBool('memoryUseLlmSummarizer') ?? false,
      memoryUseLlmRerank: prefs.getBool('memoryUseLlmRerank') ?? false,
    );
  }

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

  Future<void> setBorderRadius(double r) async {
    await _updateSetting(
      key: 'borderRadius',
      value: r,
      persist: (p, k, v) => p.setDouble(k, v),
      update: (s, v) => s.copyWith(borderRadius: v),
    );
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

  Future<void> setSurfaceOpacity(double value) async {
    await _updateSetting(
      key: 'surfaceOpacity',
      value: value,
      persist: (p, k, v) => p.setDouble(k, v),
      update: (s, v) => s.copyWith(surfaceOpacity: v),
    );
  }

  Future<void> setBackgroundOpacity(double value) async {
    await _updateSetting(
      key: 'backgroundOpacity',
      value: value,
      persist: (p, k, v) => p.setDouble(k, v),
      update: (s, v) => s.copyWith(backgroundOpacity: v),
    );
  }

  Future<void> setSearchEngine(String engine) async {
    await _updateSetting(
      key: 'searchEngine',
      value: engine,
      persist: (p, k, v) => p.setString(k, v),
      update: (s, v) => s.copyWith(searchEngine: v),
    );
  }

  // ── Memory setters ───────────────────────────────────────────────

  Future<void> setMemoryInjectContext(bool v) async {
    await _updateSetting(
      key: 'memoryInjectContext',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) => s.copyWith(memoryInjectContext: val),
    );
  }

  Future<void> setMemoryShortToMidThreshold(double v) async {
    await _updateSetting(
      key: 'memoryShortToMidThreshold',
      value: v,
      persist: (p, k, val) => p.setDouble(k, val),
      update: (s, val) => s.copyWith(memoryShortToMidThreshold: val),
    );
  }

  Future<void> setMemoryMidToLongThreshold(double v) async {
    await _updateSetting(
      key: 'memoryMidToLongThreshold',
      value: v,
      persist: (p, k, val) => p.setDouble(k, val),
      update: (s, val) => s.copyWith(memoryMidToLongThreshold: val),
    );
  }

  Future<void> setMemoryShortMaxAgeDays(int v) async {
    await _updateSetting(
      key: 'memoryShortMaxAgeDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(memoryShortMaxAgeDays: val),
    );
  }

  Future<void> setMemoryMidMaxAgeDays(int v) async {
    await _updateSetting(
      key: 'memoryMidMaxAgeDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(memoryMidMaxAgeDays: val),
    );
  }

  Future<void> setMemoryHebbianCoAccessMinutes(int v) async {
    await _updateSetting(
      key: 'memoryHebbianCoAccessMinutes',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(memoryHebbianCoAccessMinutes: val),
    );
  }

  Future<void> setMemoryHebbianDecayDays(int v) async {
    await _updateSetting(
      key: 'memoryHebbianDecayDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(memoryHebbianDecayDays: val),
    );
  }

  Future<void> setMemoryAutoExportEveryNMessages(int v) async {
    await _updateSetting(
      key: 'memoryAutoExportEveryNMessages',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(memoryAutoExportEveryNMessages: val),
    );
  }

  Future<void> setMemoryDreamingEnabled(bool v) async {
    await _updateSetting(
      key: 'memoryDreamingEnabled',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) => s.copyWith(memoryDreamingEnabled: val),
    );
  }

  Future<void> setMemoryCreatedRecencyHalfLifeDays(int v) async {
    await _updateSetting(
      key: 'memoryCreatedRecencyHalfLifeDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(memoryCreatedRecencyHalfLifeDays: val),
    );
  }

  Future<void> setMemoryAccessRecencyHalfLifeDays(int v) async {
    await _updateSetting(
      key: 'memoryAccessRecencyHalfLifeDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(memoryAccessRecencyHalfLifeDays: val),
    );
  }

  Future<void> setMemoryUseLastAccessForRecency(bool v) async {
    await _updateSetting(
      key: 'memoryUseLastAccessForRecency',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) => s.copyWith(memoryUseLastAccessForRecency: val),
    );
  }

  Future<void> setMemoryContextBudget(int v) async {
    await _updateSetting(
      key: 'memoryContextBudget',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(memoryContextBudget: val),
    );
  }

  Future<void> setMemoryUseLlmSummarizer(bool v) async {
    await _updateSetting(
      key: 'memoryUseLlmSummarizer',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) => s.copyWith(memoryUseLlmSummarizer: val),
    );
  }

  Future<void> setMemoryUseLlmRerank(bool v) async {
    await _updateSetting(
      key: 'memoryUseLlmRerank',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) => s.copyWith(memoryUseLlmRerank: val),
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class AIConfigState {
  final List<AIProvider> providers;
  final List<AIModel> models;
  final ActiveAIConfig? activeConfig;

  AIConfigState({
    this.providers = const [],
    this.models = const [],
    this.activeConfig,
  });

  AIProvider? get activeProvider {
    if (activeConfig == null) return null;
    try {
      return providers.firstWhere((p) => p.id == activeConfig!.providerId);
    } catch (_) {
      return null;
    }
  }

  AIModel? get activeModel {
    if (activeConfig == null) return null;
    try {
      return models.firstWhere(
        (m) =>
            m.id == activeConfig!.modelId &&
            m.providerId == activeConfig!.providerId,
      );
    } catch (_) {
      return null;
    }
  }

  List<AIModel> modelsForProvider(String providerId) =>
      models.where((m) => m.providerId == providerId).toList();

  AIProvider? providerById(String id) {
    try {
      return providers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  AIConfigState copyWith({
    List<AIProvider>? providers,
    List<AIModel>? models,
    ActiveAIConfig? activeConfig,
    bool clearActiveConfig = false,
  }) {
    return AIConfigState(
      providers: providers ?? this.providers,
      models: models ?? this.models,
      activeConfig: clearActiveConfig
          ? null
          : (activeConfig ?? this.activeConfig),
    );
  }
}

class AIConfigNotifier extends Notifier<AIConfigState> with SharedPrefsAware {
  final _secureStorage = const FlutterSecureStorage();

  @override
  AIConfigState build() => AIConfigState();

  Future<void> loadConfig() async {
    final prefs = await ensurePrefs;
    await _loadProviders(prefs);
    await _loadModels(prefs);
    await _loadActiveConfig(prefs);
    await _loadApiKeys();
  }

  Future<void> _loadProviders(SharedPreferences prefs) async {
    final json = prefs.getString('ai_providers');
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        final providers = list
            .map((e) => AIProvider.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(providers: providers);
      } catch (_) {
        debugPrint('AI config: failed to parse providers JSON');
      }
    }
  }

  Future<void> _loadModels(SharedPreferences prefs) async {
    final json = prefs.getString('ai_models');
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        final models = list
            .map((e) => AIModel.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(models: models);
      } catch (_) {
        debugPrint('AI config: failed to parse models JSON');
      }
    }
  }

  Future<void> _loadActiveConfig(SharedPreferences prefs) async {
    final json = prefs.getString('ai_active_config');
    if (json != null) {
      try {
        final config = ActiveAIConfig.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        state = state.copyWith(activeConfig: config);
      } catch (_) {
        debugPrint('AI config: failed to parse active config JSON');
      }
    }
  }

  Future<void> _loadApiKeys() async {
    final updatedProviders = <AIProvider>[];
    for (final provider in state.providers) {
      if (provider.requiresApiKey) {
        final key = await _secureStorage.read(key: 'ai_key_${provider.id}');
        updatedProviders.add(provider.copyWith(apiKey: key));
      } else {
        updatedProviders.add(provider);
      }
    }
    state = state.copyWith(providers: updatedProviders);
  }

  Future<void> _saveProviders() async {
    final prefs = await ensurePrefs;
    final json = jsonEncode(state.providers.map((p) => p.toJson()).toList());
    await prefs.setString('ai_providers', json);
  }

  Future<void> _saveModels() async {
    final prefs = await ensurePrefs;
    final json = jsonEncode(state.models.map((m) => m.toJson()).toList());
    await prefs.setString('ai_models', json);
  }

  Future<void> _saveActiveConfig() async {
    final prefs = await ensurePrefs;
    if (state.activeConfig != null) {
      await prefs.setString(
        'ai_active_config',
        jsonEncode(state.activeConfig!.toJson()),
      );
    } else {
      await prefs.remove('ai_active_config');
    }
  }

  Future<String?> getApiKeyForProvider(String providerId) async {
    return await _secureStorage.read(key: 'ai_key_$providerId');
  }

  Future<void> addProvider(AIProvider provider) async {
    var providers = List<AIProvider>.from(state.providers);
    providers.removeWhere((p) => p.id == provider.id);
    if (provider.requiresApiKey && provider.apiKey != null) {
      await _secureStorage.write(
        key: 'ai_key_${provider.id}',
        value: provider.apiKey,
      );
    }
    providers.add(provider.copyWith(apiKey: null));
    state = state.copyWith(providers: providers);
    await _saveProviders();
  }

  Future<void> updateProvider(AIProvider provider) async {
    final idx = state.providers.indexWhere((p) => p.id == provider.id);
    if (idx >= 0) {
      if (provider.requiresApiKey && provider.apiKey != null) {
        await _secureStorage.write(
          key: 'ai_key_${provider.id}',
          value: provider.apiKey,
        );
      }
      final providers = List<AIProvider>.from(state.providers);
      providers[idx] = provider.copyWith(apiKey: null);
      state = state.copyWith(providers: providers);
      await _saveProviders();
    }
  }

  Future<void> removeProvider(String providerId) async {
    final providers = state.providers.where((p) => p.id != providerId).toList();
    final models = state.models
        .where((m) => m.providerId != providerId)
        .toList();
    try {
      await _secureStorage.delete(key: 'ai_key_$providerId');
    } catch (_) {
      // Secure storage may not be available (e.g., in tests)
    }
    final clearActive = state.activeConfig?.providerId == providerId;
    state = state.copyWith(
      providers: providers,
      models: models,
      clearActiveConfig: clearActive,
    );
    if (clearActive) await _saveActiveConfig();
    await _saveProviders();
    await _saveModels();
  }

  Future<void> setProviderEnabled(String providerId, bool enabled) async {
    final idx = state.providers.indexWhere((p) => p.id == providerId);
    if (idx >= 0) {
      final providers = List<AIProvider>.from(state.providers);
      providers[idx] = providers[idx].copyWith(isEnabled: enabled);
      state = state.copyWith(providers: providers);
      await _saveProviders();
    }
  }

  Future<void> setModelsForProvider(
    String providerId,
    List<AIModel> newModels,
  ) async {
    var models = state.models
        .where((m) => m.providerId != providerId || m.isCustom)
        .toList();
    models.addAll(newModels);
    state = state.copyWith(models: models);
    await _saveModels();
  }

  Future<void> addCustomModel(AIModel model) async {
    var models = List<AIModel>.from(state.models);
    models.removeWhere(
      (m) => m.id == model.id && m.providerId == model.providerId,
    );
    models.add(model);
    state = state.copyWith(models: models);
    await _saveModels();
  }

  Future<void> removeModel(String modelId, String providerId) async {
    final models = state.models
        .where((m) => !(m.id == modelId && m.providerId == providerId))
        .toList();
    final clearActive =
        state.activeConfig?.modelId == modelId &&
        state.activeConfig?.providerId == providerId;
    state = state.copyWith(models: models, clearActiveConfig: clearActive);
    if (clearActive) await _saveActiveConfig();
    await _saveModels();
  }

  Future<void> setActiveConfig(ActiveAIConfig config) async {
    state = state.copyWith(activeConfig: config);
    await _saveActiveConfig();
  }

  Future<void> clearActiveConfig() async {
    state = state.copyWith(clearActiveConfig: true);
    await _saveActiveConfig();
  }
}

final aiConfigProvider = NotifierProvider<AIConfigNotifier, AIConfigState>(
  AIConfigNotifier.new,
);

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models/ai_provider.dart';

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
  final bool isDarkMode;
  final double editorFontSize;
  final bool showLineNumbers;
  final String themePreset;
  final int accentColorValue;
  final AppButtonStyle buttonStyle;
  final ComponentDensity density;
  final int iconSize;
  final double borderRadius;
  final bool alwaysShowWelcomePage;
  final bool highContrastMode;

  AppSettings({
    this.locale = 'system',
    this.isDarkMode = true,
    this.editorFontSize = 14.0,
    this.showLineNumbers = false,
    this.themePreset = 'sky',
    this.accentColorValue = 0xFF0EA5E9,
    this.buttonStyle = AppButtonStyle.rounded,
    this.density = ComponentDensity.comfortable,
    this.iconSize = 18,
    this.borderRadius = 8.0,
    this.alwaysShowWelcomePage = false,
    this.highContrastMode = false,
  });

  Color get accentColor => Color(accentColorValue);

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
    bool? isDarkMode,
    double? editorFontSize,
    bool? showLineNumbers,
    String? themePreset,
    int? accentColorValue,
    AppButtonStyle? buttonStyle,
    ComponentDensity? density,
    int? iconSize,
    double? borderRadius,
    bool? alwaysShowWelcomePage,
    bool? highContrastMode,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      themePreset: themePreset ?? this.themePreset,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      buttonStyle: buttonStyle ?? this.buttonStyle,
      density: density ?? this.density,
      iconSize: iconSize ?? this.iconSize,
      borderRadius: borderRadius ?? this.borderRadius,
      alwaysShowWelcomePage:
          alwaysShowWelcomePage ?? this.alwaysShowWelcomePage,
      highContrastMode: highContrastMode ?? this.highContrastMode,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  AppSettings build() => AppSettings();

  Future<void> loadSettings() async {
    final prefs = await _ensurePrefs;
    final preset = prefs.getString('themePreset') ?? 'sky';
    final savedColor = prefs.getInt('accentColorValue');
    final colorValue = savedColor ?? getPresetColor(preset).toARGB32();
    state = AppSettings(
      locale: prefs.getString('locale') ?? 'system',
      isDarkMode: prefs.getBool('isDarkMode') ?? true,
      editorFontSize: prefs.getDouble('editorFontSize') ?? 14.0,
      showLineNumbers: prefs.getBool('showLineNumbers') ?? false,
      themePreset: preset,
      accentColorValue: colorValue,
      buttonStyle: AppButtonStyle.values[prefs.getInt('buttonStyle') ?? 0],
      density: ComponentDensity.values[prefs.getInt('density') ?? 1],
      iconSize: (prefs.getInt('iconSize') ?? 18).clamp(12, 36),
      borderRadius: prefs.getDouble('borderRadius') ?? 8.0,
      alwaysShowWelcomePage: prefs.getBool('alwaysShowWelcomePage') ?? false,
      highContrastMode: prefs.getBool('highContrastMode') ?? false,
    );
  }

  Future<void> setLocale(String locale) async {
    final prefs = await _ensurePrefs;
    await prefs.setString('locale', locale);
    state = state.copyWith(locale: locale);
  }

  Future<void> toggleDarkMode() async {
    final prefs = await _ensurePrefs;
    await prefs.setBool('isDarkMode', !state.isDarkMode);
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  Future<void> setEditorFontSize(double size) async {
    final prefs = await _ensurePrefs;
    await prefs.setDouble('editorFontSize', size);
    state = state.copyWith(editorFontSize: size);
  }

  Future<void> setThemePreset(String preset) async {
    final color = getPresetColor(preset);
    final prefs = await _ensurePrefs;
    await prefs.setString('themePreset', preset);
    await prefs.setInt('accentColorValue', color.toARGB32());
    state = state.copyWith(
      themePreset: preset,
      accentColorValue: color.toARGB32(),
    );
  }

  Future<void> setAccentColor(Color color) async {
    final prefs = await _ensurePrefs;
    await prefs.setString('themePreset', 'custom');
    await prefs.setInt('accentColorValue', color.toARGB32());
    state = state.copyWith(
      themePreset: 'custom',
      accentColorValue: color.toARGB32(),
    );
  }

  Future<void> setButtonStyle(AppButtonStyle style) async {
    final prefs = await _ensurePrefs;
    await prefs.setInt('buttonStyle', style.index);
    state = state.copyWith(buttonStyle: style);
  }

  Future<void> setDensity(ComponentDensity d) async {
    final prefs = await _ensurePrefs;
    await prefs.setInt('density', d.index);
    state = state.copyWith(density: d);
  }

  Future<void> setIconSize(int size) async {
    final prefs = await _ensurePrefs;
    await prefs.setInt('iconSize', size);
    state = state.copyWith(iconSize: size);
  }

  Future<void> setBorderRadius(double r) async {
    final prefs = await _ensurePrefs;
    await prefs.setDouble('borderRadius', r);
    state = state.copyWith(borderRadius: r);
  }

  Future<void> setAlwaysShowWelcomePage(bool value) async {
    final prefs = await _ensurePrefs;
    await prefs.setBool('alwaysShowWelcomePage', value);
    state = state.copyWith(alwaysShowWelcomePage: value);
  }

  Future<void> setHighContrastMode(bool value) async {
    final prefs = await _ensurePrefs;
    await prefs.setBool('highContrastMode', value);
    state = state.copyWith(highContrastMode: value);
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
      activeConfig: clearActiveConfig ? null : (activeConfig ?? this.activeConfig),
    );
  }
}

class AIConfigNotifier extends Notifier<AIConfigState> {
  final _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  AIConfigState build() => AIConfigState();

  Future<void> loadConfig() async {
    final prefs = await _ensurePrefs;
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
      if (provider.protocol.requiresApiKey) {
        final key = await _secureStorage.read(key: 'ai_key_${provider.id}');
        updatedProviders.add(provider.copyWith(apiKey: key));
      } else {
        updatedProviders.add(provider);
      }
    }
    state = state.copyWith(providers: updatedProviders);
  }

  Future<void> _saveProviders() async {
    final prefs = await _ensurePrefs;
    final json = jsonEncode(state.providers.map((p) => p.toJson()).toList());
    await prefs.setString('ai_providers', json);
  }

  Future<void> _saveModels() async {
    final prefs = await _ensurePrefs;
    final json = jsonEncode(state.models.map((m) => m.toJson()).toList());
    await prefs.setString('ai_models', json);
  }

  Future<void> _saveActiveConfig() async {
    final prefs = await _ensurePrefs;
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
    if (provider.protocol.requiresApiKey && provider.apiKey != null) {
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
      if (provider.protocol.requiresApiKey && provider.apiKey != null) {
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
    final models = state.models.where((m) => m.providerId != providerId).toList();
    await _secureStorage.delete(key: 'ai_key_$providerId');
    final clearActive = state.activeConfig?.providerId == providerId;
    state = state.copyWith(providers: providers, models: models, clearActiveConfig: clearActive);
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
    var models = state.models.where((m) => m.providerId != providerId || m.isCustom).toList();
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
    final models = state.models.where(
      (m) => !(m.id == modelId && m.providerId == providerId),
    ).toList();
    final clearActive = state.activeConfig?.modelId == modelId &&
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';

void main() {
  group('AppSettings', () {
    test('default values', () {
      final settings = AppSettings();
      expect(settings.locale, 'system');
      expect(settings.editorFontSize, 14.0);
      expect(settings.showLineNumbers, false);
      expect(settings.themePreset, 'sky');
      expect(settings.accentColorValue, 0xFF0EA5E9);
      expect(settings.scaffoldBgColorValue, 0xFF0F172A);
      expect(settings.surfaceColorValue, 0xFF1E293B);
      expect(settings.buttonStyle, AppButtonStyle.rounded);
      expect(settings.density, ComponentDensity.comfortable);
      expect(settings.iconSize, 18);
      expect(settings.borderRadius, 8.0);
      expect(settings.alwaysShowWelcomePage, false);
      expect(settings.highContrastMode, false);
      expect(settings.themeTintOpacity, 0.8);
      expect(settings.surfaceOpacity, 1.0);
      expect(settings.backgroundOpacity, 1.0);
      expect(settings.searchEngine, 'bing');
    });

    test('accentColor getter returns Color', () {
      final settings = AppSettings(accentColorValue: 0xFFF43F5E);
      expect(settings.accentColor, const Color(0xFFF43F5E));
    });

    test('scaffoldBgColor getter returns Color', () {
      final settings = AppSettings(scaffoldBgColorValue: 0xFFFFFFFF);
      expect(settings.scaffoldBgColor, const Color(0xFFFFFFFF));
    });

    test('surfaceColor getter returns Color', () {
      final settings = AppSettings(surfaceColorValue: 0xFFCCCCCC);
      expect(settings.surfaceColor, const Color(0xFFCCCCCC));
    });

    test('isDarkMode true when themeMode is dark', () {
      final settings = AppSettings(themeMode: ThemeMode.dark);
      expect(settings.isDarkMode, isTrue);
    });

    test('isDarkMode false when themeMode is light', () {
      final settings = AppSettings(themeMode: ThemeMode.light);
      expect(settings.isDarkMode, isFalse);
    });

    test('effectiveBorderRadius rounded style returns borderRadius', () {
      final settings = AppSettings(
        buttonStyle: AppButtonStyle.rounded,
        borderRadius: 12.0,
      );
      expect(settings.effectiveBorderRadius, 12.0);
    });

    test('effectiveBorderRadius sharp style returns 2.0', () {
      final settings = AppSettings(buttonStyle: AppButtonStyle.sharp);
      expect(settings.effectiveBorderRadius, 2.0);
    });

    test('effectiveBorderRadius pill style returns 100.0', () {
      final settings = AppSettings(buttonStyle: AppButtonStyle.pill);
      expect(settings.effectiveBorderRadius, 100.0);
    });

    test('effectiveVisualDensity compact', () {
      final settings = AppSettings(density: ComponentDensity.compact);
      expect(settings.effectiveVisualDensity, VisualDensity.compact);
    });

    test('effectiveVisualDensity comfortable', () {
      final settings = AppSettings(density: ComponentDensity.comfortable);
      expect(settings.effectiveVisualDensity, VisualDensity.standard);
    });

    test('effectiveVisualDensity spacious', () {
      final settings = AppSettings(density: ComponentDensity.spacious);
      expect(
        settings.effectiveVisualDensity,
        const VisualDensity(horizontal: 0, vertical: 2),
      );
    });

    test('copyWith overrides locale', () {
      final settings = AppSettings(locale: 'system');
      final copied = settings.copyWith(locale: 'zh');
      expect(copied.locale, 'zh');
    });

    test('copyWith overrides editorFontSize', () {
      final settings = AppSettings(editorFontSize: 14.0);
      final copied = settings.copyWith(editorFontSize: 18.0);
      expect(copied.editorFontSize, 18.0);
    });

    test('copyWith overrides showLineNumbers', () {
      final settings = AppSettings(showLineNumbers: false);
      final copied = settings.copyWith(showLineNumbers: true);
      expect(copied.showLineNumbers, isTrue);
    });

    test('copyWith overrides themePreset', () {
      final settings = AppSettings(themePreset: 'sky');
      final copied = settings.copyWith(themePreset: 'violet');
      expect(copied.themePreset, 'violet');
    });

    test('copyWith overrides accentColorValue', () {
      final settings = AppSettings(accentColorValue: 0xFF0EA5E9);
      final copied = settings.copyWith(accentColorValue: 0xFF8B5CF6);
      expect(copied.accentColorValue, 0xFF8B5CF6);
    });

    test('copyWith overrides scaffoldBgColorValue', () {
      final settings = AppSettings(scaffoldBgColorValue: 0xFF0F172A);
      final copied = settings.copyWith(scaffoldBgColorValue: 0xFFFFFFFF);
      expect(copied.scaffoldBgColorValue, 0xFFFFFFFF);
    });

    test('copyWith overrides surfaceColorValue', () {
      final settings = AppSettings(surfaceColorValue: 0xFF1E293B);
      final copied = settings.copyWith(surfaceColorValue: 0xFFEEEEEE);
      expect(copied.surfaceColorValue, 0xFFEEEEEE);
    });

    test('copyWith overrides buttonStyle', () {
      final settings = AppSettings(buttonStyle: AppButtonStyle.rounded);
      final copied = settings.copyWith(buttonStyle: AppButtonStyle.pill);
      expect(copied.buttonStyle, AppButtonStyle.pill);
    });

    test('copyWith overrides density', () {
      final settings = AppSettings(density: ComponentDensity.comfortable);
      final copied = settings.copyWith(density: ComponentDensity.compact);
      expect(copied.density, ComponentDensity.compact);
    });

    test('copyWith overrides iconSize', () {
      final settings = AppSettings(iconSize: 18);
      final copied = settings.copyWith(iconSize: 24);
      expect(copied.iconSize, 24);
    });

    test('copyWith overrides borderRadius', () {
      final settings = AppSettings(borderRadius: 8.0);
      final copied = settings.copyWith(borderRadius: 16.0);
      expect(copied.borderRadius, 16.0);
    });

    test('copyWith overrides alwaysShowWelcomePage', () {
      final settings = AppSettings(alwaysShowWelcomePage: false);
      final copied = settings.copyWith(alwaysShowWelcomePage: true);
      expect(copied.alwaysShowWelcomePage, isTrue);
    });

    test('copyWith overrides highContrastMode', () {
      final settings = AppSettings(highContrastMode: false);
      final copied = settings.copyWith(highContrastMode: true);
      expect(copied.highContrastMode, isTrue);
    });

    test('copyWith overrides themeTintOpacity', () {
      final settings = AppSettings(themeTintOpacity: 0.8);
      final copied = settings.copyWith(themeTintOpacity: 0.5);
      expect(copied.themeTintOpacity, 0.5);
    });

    test('copyWith overrides surfaceOpacity', () {
      final settings = AppSettings(surfaceOpacity: 1.0);
      final copied = settings.copyWith(surfaceOpacity: 0.7);
      expect(copied.surfaceOpacity, 0.7);
    });

    test('copyWith overrides backgroundOpacity', () {
      final settings = AppSettings(backgroundOpacity: 1.0);
      final copied = settings.copyWith(backgroundOpacity: 0.9);
      expect(copied.backgroundOpacity, 0.9);
    });

    test('copyWith overrides searchEngine', () {
      final settings = AppSettings(searchEngine: 'bing');
      final copied = settings.copyWith(searchEngine: 'google');
      expect(copied.searchEngine, 'google');
    });
  });

  group('SettingsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    SettingsNotifier notifier() => container.read(settingsProvider.notifier);
    AppSettings state() => container.read(settingsProvider);

    test('initial state has defaults', () {
      expect(state().themePreset, 'sky');
      expect(state().editorFontSize, 14.0);
    });

    test('loadSettings loads values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'locale': 'zh',
        'editorFontSize': 18.0,
        'showLineNumbers': true,
        'themePreset': 'violet',
        'accentColorValue': 0xFF8B5CF6,
        'scaffoldBgColorValue': 0xFFFFFFFF,
        'surfaceColorValue': 0xFFEEEEEE,
        'buttonStyle': 2,
        'density': 0,
        'iconSize': 24,
        'borderRadius': 12.0,
        'alwaysShowWelcomePage': true,
        'highContrastMode': true,
        'themeTintOpacity': 0.5,
        'surfaceOpacity': 0.8,
        'backgroundOpacity': 0.9,
        'searchEngine': 'google',
      });

      await notifier().loadSettings();

      final s = state();
      expect(s.locale, 'zh');
      expect(s.editorFontSize, 18.0);
      expect(s.showLineNumbers, isTrue);
      expect(s.themePreset, 'violet');
      expect(s.accentColorValue, 0xFF8B5CF6);
      expect(s.scaffoldBgColorValue, 0xFFFFFFFF);
      expect(s.surfaceColorValue, 0xFFEEEEEE);
      expect(s.buttonStyle, AppButtonStyle.pill);
      expect(s.density, ComponentDensity.compact);
      expect(s.iconSize, 24);
      expect(s.borderRadius, 12.0);
      expect(s.alwaysShowWelcomePage, isTrue);
      expect(s.highContrastMode, isTrue);
      expect(s.themeTintOpacity, 0.5);
      expect(s.surfaceOpacity, 0.8);
      expect(s.backgroundOpacity, 0.9);
      expect(s.searchEngine, 'google');
    });

    test(
      'loadSettings uses preset color when accentColorValue not saved',
      () async {
        SharedPreferences.setMockInitialValues({'themePreset': 'rose'});

        await notifier().loadSettings();

        expect(state().themePreset, 'rose');
        expect(state().accentColorValue, getPresetColor('rose').toARGB32());
      },
    );

    test('setLocale persists and updates state', () async {
      await notifier().setLocale('zh');
      expect(state().locale, 'zh');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'zh');
    });

    test('setEditorFontSize persists and updates state', () async {
      await notifier().setEditorFontSize(20.0);
      expect(state().editorFontSize, 20.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('editorFontSize'), 20.0);
    });

    test('setThemePreset updates color and persists', () async {
      await notifier().setThemePreset('rose');
      expect(state().themePreset, 'rose');
      expect(state().accentColorValue, getPresetColor('rose').toARGB32());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themePreset'), 'rose');
    });

    test('setAccentColor sets preset to custom and persists', () async {
      await notifier().setAccentColor(const Color(0xFF123456));
      expect(state().themePreset, 'custom');
      expect(state().accentColorValue, 0xFF123456);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themePreset'), 'custom');
    });

    test('setScaffoldBgColor persists and updates state', () async {
      await notifier().setScaffoldBgColor(const Color(0xFFABCDEF));
      expect(state().scaffoldBgColorValue, 0xFFABCDEF);
    });

    test('setSurfaceColor persists and updates state', () async {
      await notifier().setSurfaceColor(const Color(0xFF223344));
      expect(state().surfaceColorValue, 0xFF223344);
    });

    test('setButtonStyle persists and updates state', () async {
      await notifier().setButtonStyle(AppButtonStyle.sharp);
      expect(state().buttonStyle, AppButtonStyle.sharp);
    });

    test('setDensity persists and updates state', () async {
      await notifier().setDensity(ComponentDensity.spacious);
      expect(state().density, ComponentDensity.spacious);
    });

    test('setIconSize persists and updates state', () async {
      await notifier().setIconSize(28);
      expect(state().iconSize, 28);
    });

    test('setBorderRadius persists and updates state', () async {
      await notifier().setBorderRadius(16.0);
      expect(state().borderRadius, 16.0);
    });

    test('setAlwaysShowWelcomePage persists and updates state', () async {
      await notifier().setAlwaysShowWelcomePage(true);
      expect(state().alwaysShowWelcomePage, isTrue);
    });

    test('setHighContrastMode persists and updates state', () async {
      await notifier().setHighContrastMode(true);
      expect(state().highContrastMode, isTrue);
    });

    test('setThemeTintOpacity persists and updates state', () async {
      await notifier().setThemeTintOpacity(0.3);
      expect(state().themeTintOpacity, 0.3);
    });

    test('setSurfaceOpacity persists and updates state', () async {
      await notifier().setSurfaceOpacity(0.6);
      expect(state().surfaceOpacity, 0.6);
    });

    test('setBackgroundOpacity persists and updates state', () async {
      await notifier().setBackgroundOpacity(0.4);
      expect(state().backgroundOpacity, 0.4);
    });

    test('setSearchEngine persists and updates state', () async {
      await notifier().setSearchEngine('duckduckgo');
      expect(state().searchEngine, 'duckduckgo');
    });
  });

  group('getPresetColor', () {
    test('returns correct color for known id', () {
      expect(getPresetColor('rose'), const Color(0xFFF43F5E));
      expect(getPresetColor('emerald'), const Color(0xFF10B981));
      expect(getPresetColor('slate'), const Color(0xFF64748B));
    });

    test('returns default sky color for unknown id', () {
      expect(getPresetColor('unknown'), const Color(0xFF0EA5E9));
    });
  });

  group('AIConfigState', () {
    test('default state has empty lists', () {
      final state = AIConfigState();
      expect(state.providers, isEmpty);
      expect(state.models, isEmpty);
      expect(state.activeConfig, isNull);
    });

    test('activeProvider returns null when no active config', () {
      final state = AIConfigState();
      expect(state.activeProvider, isNull);
    });

    test('activeProvider returns matching provider', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'MyProvider',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.openai.com',
      );
      final state = AIConfigState(
        providers: [provider],
        activeConfig: const ActiveAIConfig(providerId: 'p1', modelId: 'm1'),
      );
      expect(state.activeProvider, isNotNull);
      expect(state.activeProvider!.id, 'p1');
    });

    test('activeProvider returns null for unknown provider id', () {
      final state = AIConfigState(
        providers: [],
        activeConfig: const ActiveAIConfig(providerId: 'p1', modelId: 'm1'),
      );
      expect(state.activeProvider, isNull);
    });

    test('activeModel returns null when no active config', () {
      final state = AIConfigState();
      expect(state.activeModel, isNull);
    });

    test('activeModel returns matching model', () {
      final model = AIModel(id: 'm1', providerId: 'p1', displayName: 'GPT-4');
      final state = AIConfigState(
        models: [model],
        activeConfig: const ActiveAIConfig(providerId: 'p1', modelId: 'm1'),
      );
      expect(state.activeModel, isNotNull);
      expect(state.activeModel!.id, 'm1');
    });

    test('modelsForProvider filters correctly', () {
      final models = [
        AIModel(id: 'm1', providerId: 'p1', displayName: 'Model 1'),
        AIModel(id: 'm2', providerId: 'p2', displayName: 'Model 2'),
        AIModel(id: 'm3', providerId: 'p1', displayName: 'Model 3'),
      ];
      final state = AIConfigState(models: models);
      final p1Models = state.modelsForProvider('p1');
      expect(p1Models.length, 2);
      expect(p1Models.every((m) => m.providerId == 'p1'), isTrue);
    });

    test('providerById returns matching provider', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        requiresApiKey: false,
      );
      final state = AIConfigState(providers: [provider]);
      expect(state.providerById('p1'), isNotNull);
      expect(state.providerById('p1')!.name, 'Test');
    });

    test('providerById returns null for unknown', () {
      final state = AIConfigState();
      expect(state.providerById('unknown'), isNull);
    });

    test('copyWith overrides all fields', () {
      final state = AIConfigState();
      final providers = [
        AIProvider(
          id: 'p1',
          name: 'P1',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434',
          requiresApiKey: false,
        ),
      ];
      final models = [AIModel(id: 'm1', providerId: 'p1', displayName: 'M1')];
      final config = const ActiveAIConfig(providerId: 'p1', modelId: 'm1');

      final copied = state.copyWith(
        providers: providers,
        models: models,
        activeConfig: config,
      );

      expect(copied.providers.length, 1);
      expect(copied.models.length, 1);
      expect(copied.activeConfig, config);
    });

    test('copyWith clearActiveConfig: true sets activeConfig to null', () {
      final state = AIConfigState(
        activeConfig: ActiveAIConfig(providerId: 'p1', modelId: 'm1'),
      );
      final copied = state.copyWith(clearActiveConfig: true);
      expect(copied.activeConfig, isNull);
    });
  });

  group('AIProvider', () {
    test('modelsEndpoint combines baseUrl and protocol path', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.openai.com',
      );
      expect(provider.modelsEndpoint, 'https://api.openai.com/v1/models');
    });

    test('chatEndpoint for local provider', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        requiresApiKey: false,
      );
      expect(
        provider.chatEndpoint,
        'http://localhost:11434/v1/chat/completions',
      );
    });

    test('authHeaders for openai returns Bearer', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.example.com',
        apiKey: 'sk-123',
      );
      final headers = provider.authHeaders();
      expect(headers['Authorization'], 'Bearer sk-123');
    });

    test('authHeaders for openai without key returns empty', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.example.com',
      );
      final headers = provider.authHeaders();
      expect(headers['Authorization'], isNull);
      expect(headers.isEmpty, isTrue);
    });

    test('authHeaders for anthropic', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Claude',
        protocol: ApiProtocol.anthropic,
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'sk-ant-123',
      );
      final headers = provider.authHeaders();
      expect(headers['x-api-key'], 'sk-ant-123');
      expect(headers['anthropic-version'], '2023-06-01');
    });

    test('authHeaders for local provider without key returns empty', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        requiresApiKey: false,
      );
      final headers = provider.authHeaders();
      expect(headers.isEmpty, isTrue);
    });

    test('toJson excludes apiKey', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        apiKey: 'secret',
        requiresApiKey: false,
      );
      final json = provider.toJson();
      expect(json['id'], 'p1');
      expect(json['name'], 'Test');
      expect(json['apiKey'], isNull);
    });

    test('fromJson creates provider correctly', () {
      final json = {
        'id': 'p1',
        'name': 'Test Provider',
        'protocol': 0,
        'baseUrl': 'https://api.openai.com',
        'isEnabled': false,
      };
      final provider = AIProvider.fromJson(json);
      expect(provider.id, 'p1');
      expect(provider.name, 'Test Provider');
      expect(provider.protocol, ApiProtocol.openaiCompatible);
      expect(provider.isEnabled, false);
    });

    test('copyWith overrides fields', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Original',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        apiKey: 'secret',
        requiresApiKey: false,
      );
      final copied = provider.copyWith(name: 'Renamed');
      expect(copied.id, 'p1');
      expect(copied.name, 'Renamed');
      expect(copied.apiKey, 'secret');
    });

    test('equality based on id', () {
      final a = AIProvider(
        id: 'same',
        name: 'A',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://a',
      );
      final b = AIProvider(
        id: 'same',
        name: 'B',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://b',
      );
      expect(a == b, isTrue);
    });
  });

  group('AIModel', () {
    test('supportsTextOnly true when only text capability', () {
      const model = AIModel(
        id: 'm1',
        providerId: 'p1',
        displayName: 'Text Only',
      );
      expect(model.supportsTextOnly, isTrue);
    });

    test('supportsTextOnly false when has vision', () {
      const model = AIModel(
        id: 'm1',
        providerId: 'p1',
        displayName: 'Vision',
        capabilities: {ModelCapability.text, ModelCapability.vision},
      );
      expect(model.supportsTextOnly, isFalse);
    });

    test('supportsVision returns true when has vision capability', () {
      const model = AIModel(
        id: 'm1',
        providerId: 'p1',
        displayName: 'Vision',
        capabilities: {ModelCapability.vision},
      );
      expect(model.supportsVision, isTrue);
    });

    test('capabilityLabel joins capabilities', () {
      const model = AIModel(
        id: 'm1',
        providerId: 'p1',
        displayName: 'Multi',
        capabilities: {ModelCapability.text, ModelCapability.vision},
      );
      final label = model.capabilityLabel;
      expect(label, contains('Text'));
      expect(label, contains('Vision'));
    });

    test('toJson and fromJson round-trip', () {
      final model = AIModel(
        id: 'm1',
        providerId: 'p1',
        displayName: 'GPT-4',
        capabilities: {ModelCapability.text, ModelCapability.vision},
        contextWindow: 128000,
        isCustom: true,
      );
      final json = model.toJson();
      final restored = AIModel.fromJson(json);
      expect(restored.id, 'm1');
      expect(restored.displayName, 'GPT-4');
      expect(restored.contextWindow, 128000);
      expect(restored.isCustom, isTrue);
      expect(restored.supportsVision, isTrue);
    });
  });

  group('ActiveAIConfig', () {
    test('toJson and fromJson round-trip', () {
      const config = ActiveAIConfig(providerId: 'p1', modelId: 'm1');
      final json = config.toJson();
      final restored = ActiveAIConfig.fromJson(json);
      expect(restored.providerId, 'p1');
      expect(restored.modelId, 'm1');
    });
  });

  group('ApiProtocol enum', () {
    test('label returns correct values', () {
      expect(ApiProtocol.openaiCompatible.label, 'OpenAI Compatible');
      expect(ApiProtocol.anthropic.label, 'Anthropic');
    });

    test('defaultBaseUrl returns correct URLs', () {
      expect(
        ApiProtocol.openaiCompatible.defaultBaseUrl,
        'https://api.openai.com',
      );
      expect(ApiProtocol.anthropic.defaultBaseUrl, 'https://api.anthropic.com');
    });
  });

  group('AIProvider isLocal and requiresApiKey', () {
    test('isLocal returns true for localhost', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        requiresApiKey: false,
      );
      expect(provider.isLocal, isTrue);
      expect(provider.requiresApiKey, isFalse);
    });

    test('isLocal returns true for 127.0.0.1', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://127.0.0.1:1234',
        requiresApiKey: false,
      );
      expect(provider.isLocal, isTrue);
    });

    test('isLocal returns false for remote URL', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Remote',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.openai.com',
      );
      expect(provider.isLocal, isFalse);
    });

    test('requiresApiKey defaults to true for remote', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Remote',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.openai.com',
      );
      expect(provider.requiresApiKey, isTrue);
    });

    test('requiresApiKey can be explicitly set to false for remote', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Custom',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://custom-api.example.com',
        requiresApiKey: false,
      );
      expect(provider.requiresApiKey, isFalse);
    });

    test('displayIcon returns computer for local provider', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        requiresApiKey: false,
      );
      expect(provider.displayIcon, Icons.computer);
    });

    test('embeddingEndpoint returns correct path', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.openai.com',
      );
      expect(
        provider.embeddingEndpoint,
        'https://api.openai.com/v1/embeddings',
      );
    });

    test('embeddingEndpoint handles /v1 suffix', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434/v1',
        requiresApiKey: false,
      );
      expect(
        provider.embeddingEndpoint,
        'http://localhost:11434/v1/embeddings',
      );
    });
  });
}

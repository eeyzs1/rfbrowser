import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Settings Integration', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'SettingsNotifier loadSettings returns defaults when no stored data',
      () async {
        final notifier = container.read(settingsProvider.notifier);
        await notifier.loadSettings();

        final settings = container.read(settingsProvider);
        expect(settings.locale, 'system');
        expect(settings.editorFontSize, 14.0);
        expect(settings.showLineNumbers, false);
        expect(settings.themePreset, 'sky');
        expect(settings.accentColorValue, 0xFF0EA5E9);
        expect(settings.buttonStyle, AppButtonStyle.rounded);
        expect(settings.density, ComponentDensity.comfortable);
        expect(settings.searchEngine, 'bing');
        expect(settings.alwaysShowWelcomePage, false);
        expect(settings.highContrastMode, false);
      },
    );

    test(
      'SettingsNotifier setEditorFontSize persists and reads back',
      () async {
        final notifier = container.read(settingsProvider.notifier);
        await notifier.loadSettings();

        await notifier.setEditorFontSize(18.0);
        expect(container.read(settingsProvider).editorFontSize, 18.0);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('editorFontSize'), 18.0);
      },
    );

    test('SettingsNotifier setThemePreset changes accent color', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setThemePreset('rose');
      final settings = container.read(settingsProvider);
      expect(settings.themePreset, 'rose');
      expect(settings.accentColorValue, 0xFFF43F5E);
    });

    test('SettingsNotifier setAccentColor stores custom color', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setAccentColor(const Color(0xFF123456));
      expect(container.read(settingsProvider).accentColorValue, 0xFF123456);
      expect(container.read(settingsProvider).themePreset, 'custom');
    });

    test(
      'SettingsNotifier setScaffoldBgColor and setSurfaceColor work',
      () async {
        final notifier = container.read(settingsProvider.notifier);
        await notifier.loadSettings();

        await notifier.setScaffoldBgColor(const Color(0xFFFFFFFF));
        await notifier.setSurfaceColor(const Color(0xFFF5F5F5));

        final settings = container.read(settingsProvider);
        expect(settings.scaffoldBgColorValue, 0xFFFFFFFF);
        expect(settings.surfaceColorValue, 0xFFF5F5F5);
        expect(settings.isDarkMode, isFalse);
      },
    );

    test('SettingsNotifier setButtonStyle changes style', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setButtonStyle(AppButtonStyle.pill);
      expect(container.read(settingsProvider).buttonStyle, AppButtonStyle.pill);
      expect(container.read(settingsProvider).effectiveBorderRadius, 100.0);
    });

    test('SettingsNotifier setDensity changes density', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setDensity(ComponentDensity.compact);
      expect(
        container.read(settingsProvider).density,
        ComponentDensity.compact,
      );
    });

    test('SettingsNotifier setLocale changes language', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setLocale('zh');
      expect(container.read(settingsProvider).locale, 'zh');
    });

    test('SettingsNotifier setSearchEngine changes engine', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setSearchEngine('google');
      expect(container.read(settingsProvider).searchEngine, 'google');
    });

    test('SettingsNotifier setHighContrastMode toggles', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setHighContrastMode(true);
      expect(container.read(settingsProvider).highContrastMode, isTrue);
    });

    test(
      'SettingsNotifier setAlwaysShowWelcomePage toggles welcome page',
      () async {
        final notifier = container.read(settingsProvider.notifier);
        await notifier.loadSettings();

        await notifier.setAlwaysShowWelcomePage(true);
        expect(container.read(settingsProvider).alwaysShowWelcomePage, isTrue);
      },
    );

    test('SettingsNotifier theme opacity setters change theme opacity', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setThemeTintOpacity(0.5);
      await notifier.setSurfaceOpacity(0.8);
      await notifier.setBackgroundOpacity(0.9);

      final settings = container.read(settingsProvider);
      expect(settings.themeTintOpacity, 0.5);
      expect(settings.surfaceOpacity, 0.8);
      expect(settings.backgroundOpacity, 0.9);
    });
  });

  group('AI Config Integration', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('AIConfigNotifier loadConfig returns empty defaults', () async {
      final notifier = container.read(aiConfigProvider.notifier);
      await notifier.loadConfig();

      final config = container.read(aiConfigProvider);
      expect(config.providers, isEmpty);
      expect(config.models, isEmpty);
    });

    test('AIConfigNotifier addProvider and save', () async {
      final notifier = container.read(aiConfigProvider.notifier);
      await notifier.loadConfig();

      final provider = AIProvider(
        id: 'test-provider',
        name: 'Test Provider',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.example.com',
      );
      await notifier.addProvider(provider);

      final config = container.read(aiConfigProvider);
      expect(config.providers.length, 1);
      expect(config.providers.first.id, 'test-provider');
      expect(config.providers.first.name, 'Test Provider');
    });

    test('AIConfigNotifier removeProvider deletes provider', () async {
      final notifier = container.read(aiConfigProvider.notifier);
      await notifier.loadConfig();

      await notifier.addProvider(
        AIProvider(
          id: 'p1',
          name: 'Provider 1',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'https://api1.example.com',
        ),
      );
      await notifier.addProvider(
        AIProvider(
          id: 'p2',
          name: 'Provider 2',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'https://api2.example.com',
        ),
      );

      await notifier.removeProvider('p1');
      final config = container.read(aiConfigProvider);
      expect(config.providers.length, 1);
      expect(config.providers.first.id, 'p2');
    });

    test(
      'AIConfigNotifier updateProvider modifies existing provider',
      () async {
        final notifier = container.read(aiConfigProvider.notifier);
        await notifier.loadConfig();

        await notifier.addProvider(
          AIProvider(
            id: 'p1',
            name: 'Original',
            protocol: ApiProtocol.openaiCompatible,
            baseUrl: 'https://api.example.com',
          ),
        );

        await notifier.updateProvider(
          AIProvider(
            id: 'p1',
            name: 'Updated',
            protocol: ApiProtocol.openaiCompatible,
            baseUrl: 'https://api.example.com/v2',
          ),
        );

        final config = container.read(aiConfigProvider);
        expect(config.providers.first.name, 'Updated');
        expect(config.providers.first.baseUrl, 'https://api.example.com/v2');
      },
    );

    test('AIConfigNotifier addCustomModel and removeModel', () async {
      final notifier = container.read(aiConfigProvider.notifier);
      await notifier.loadConfig();

      final model = const AIModel(
        id: 'gpt-4',
        providerId: 'openai',
        displayName: 'GPT-4',
      );
      await notifier.addCustomModel(model);

      expect(container.read(aiConfigProvider).models.length, 1);
      expect(container.read(aiConfigProvider).models.first.id, 'gpt-4');

      await notifier.removeModel('gpt-4', 'openai');
      expect(container.read(aiConfigProvider).models, isEmpty);
    });

    test(
      'AIConfigNotifier setActiveConfig updates active provider and model',
      () async {
        final notifier = container.read(aiConfigProvider.notifier);
        await notifier.loadConfig();

        await notifier.addProvider(
          AIProvider(
            id: 'p1',
            name: 'Provider 1',
            protocol: ApiProtocol.openaiCompatible,
            baseUrl: 'https://api.example.com',
          ),
        );
        await notifier.addCustomModel(
          const AIModel(id: 'm1', providerId: 'p1', displayName: 'Model 1'),
        );

        await notifier.setActiveConfig(
          const ActiveAIConfig(providerId: 'p1', modelId: 'm1'),
        );

        final config = container.read(aiConfigProvider);
        expect(config.activeConfig, isNotNull);
        expect(config.activeConfig!.providerId, 'p1');
        expect(config.activeConfig!.modelId, 'm1');
      },
    );
  });
}

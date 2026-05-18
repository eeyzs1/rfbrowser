import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/settings/theme_settings_section.dart';
import 'package:rfbrowser/services/settings_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Settings', () {
    late _TestSettingsNotifier testNotifier;

    Future<void> pumpThemeSettings(WidgetTester tester) async {
      testNotifier = _TestSettingsNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => testNotifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThemeSettingsSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    tearDown(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accentColorValue');
      await prefs.remove('scaffoldBgColorValue');
      await prefs.remove('surfaceColorValue');
      await prefs.remove('themePreset');
      await prefs.remove('themeTintOpacity');
      await prefs.remove('surfaceOpacity');
      await prefs.remove('backgroundOpacity');
    });

    testWidgets('renders all three color sections', (tester) async {
      await pumpThemeSettings(tester);

      expect(find.text('Theme Color'), findsOneWidget);
      expect(find.text('Background Color'), findsOneWidget);
      expect(find.text('Surface'), findsAtLeast(1));
    });

    testWidgets('renders 10 theme color presets', (tester) async {
      await pumpThemeSettings(tester);

      expect(find.text('Ocean'), findsOneWidget);
      expect(find.text('Violet'), findsOneWidget);
      expect(find.text('Rose'), findsOneWidget);
      expect(find.text('Emerald'), findsOneWidget);
      expect(find.text('Amber'), findsOneWidget);
      expect(find.text('Indigo'), findsOneWidget);
      expect(find.text('Teal'), findsOneWidget);
      expect(find.text('Coral'), findsOneWidget);
      expect(find.text('Mint'), findsOneWidget);
      expect(find.text('Slate'), findsAtLeast(1));
    });

    testWidgets('renders 10 background color presets', (tester) async {
      await pumpThemeSettings(tester);

      expect(find.text('Midnight'), findsOneWidget);
      expect(find.text('Obsidian'), findsOneWidget);
      expect(find.text('Espresso'), findsOneWidget);
      expect(find.text('Deep Sea'), findsOneWidget);
      expect(find.text('Plum'), findsOneWidget);
      expect(find.text('Charcoal'), findsOneWidget);
      expect(find.text('Forest'), findsOneWidget);
      expect(find.text('Linen'), findsOneWidget);
      expect(find.text('Fog'), findsOneWidget);
      expect(find.text('Dune'), findsOneWidget);
    });

    testWidgets('renders 10 surface color presets', (tester) async {
      await pumpThemeSettings(tester);

      expect(find.text('Slate'), findsWidgets);
      expect(find.text('Graphite'), findsOneWidget);
      expect(find.text('Bronze'), findsOneWidget);
      expect(find.text('Steel'), findsOneWidget);
      expect(find.text('Ivory'), findsOneWidget);
      expect(find.text('Mist'), findsOneWidget);
      expect(find.text('Sandstone'), findsOneWidget);
      expect(find.text('Sage'), findsOneWidget);
      expect(find.text('Lavender'), findsOneWidget);
      expect(find.text('Pearl'), findsOneWidget);
    });

    testWidgets('renders custom color button for each section', (tester) async {
      await pumpThemeSettings(tester);

      expect(find.text('Custom Color'), findsNWidgets(3));
    });

    testWidgets('renders opacity sliders section', (tester) async {
      await pumpThemeSettings(tester);

      expect(find.text('Opacity'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(3));
    });

    testWidgets('tapping theme preset updates accent color', (tester) async {
      await pumpThemeSettings(tester);

      await tester.tap(find.text('Violet'));
      await tester.pumpAndSettle();

      final settings = testNotifier.state;
      expect(settings.accentColorValue, equals(const Color(0xFF8B5CF6).toARGB32()));
      expect(settings.themePreset, equals('custom'));
    });

    testWidgets('tapping background preset updates scaffold bg color', (tester) async {
      await pumpThemeSettings(tester);

      await tester.tap(find.text('Obsidian'));
      await tester.pumpAndSettle();

      final settings = testNotifier.state;
      expect(settings.scaffoldBgColorValue, equals(const Color(0xFF000000).toARGB32()));
    });

    testWidgets('tapping surface preset updates surface color', (tester) async {
      await pumpThemeSettings(tester);

      await tester.tap(find.text('Ivory'));
      await tester.pumpAndSettle();

      final settings = testNotifier.state;
      expect(settings.surfaceColorValue, equals(const Color(0xFFE8E0D0).toARGB32()));
    });

    testWidgets('isDarkMode computed from background luminance (A-11)', (tester) async {
      await pumpThemeSettings(tester);

      testNotifier.setScaffoldBgColor(const Color(0xFF0F172A));
      await tester.pumpAndSettle();
      expect(testNotifier.state.isDarkMode, isTrue);

      testNotifier.setScaffoldBgColor(const Color(0xFFD6D3D1));
      await tester.pumpAndSettle();
      expect(testNotifier.state.isDarkMode, isFalse);
    });

    testWidgets('selected preset shows border highlight', (tester) async {
      await pumpThemeSettings(tester);

      final oceanGesture = find.ancestor(
        of: find.text('Ocean'),
        matching: find.byType(AnimatedContainer),
      );
      expect(oceanGesture, findsOneWidget);

      final container = tester.widget<AnimatedContainer>(oceanGesture.first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

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
          overrides: [settingsProvider.overrideWith(() => testNotifier)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: ThemeSettingsSection()),
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

    testWidgets('renders all four color sections', (tester) async {
      await pumpThemeSettings(tester);

      expect(find.text('Theme Color'), findsOneWidget);
      expect(find.text('Background Color'), findsOneWidget);
      // l10n 的 surfaceColor 在 en 中是 'Surface'，不是 'Surface Color'。
      expect(find.text('Surface'), findsOneWidget);
      expect(find.text('Font Color'), findsOneWidget);
    });

    // 4 个色板的 label 全局唯一（参见 theme_settings_section.dart 中
    // _themePresets/_bgPresets/_surfacePresets/_fontPresets 的注释），
    // 所以 findsOneWidget 即可精确定位每个预设。
    testWidgets('renders 16 theme color presets', (tester) async {
      await pumpThemeSettings(tester);

      const labels = [
        'Scarlet',
        'Red',
        'Sunset',
        'Marigold',
        'Yellow',
        'Lime',
        'Emerald',
        'Teal',
        'Cyan',
        'Ocean',
        'Indigo',
        'Violet',
        'Purple',
        'Magenta',
        'Pink',
        'Strawberry',
      ];
      for (final label in labels) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'theme preset: $label',
        );
      }
    });

    testWidgets('renders 16 background color presets', (tester) async {
      await pumpThemeSettings(tester);

      const labels = [
        'Midnight',
        'Obsidian',
        'Mocha',
        'Deep Sea',
        'Onyx',
        'Forest',
        'Wine',
        'Slate Dark',
        'Cream',
        'Mist',
        'Parchment',
        'Sagebrush',
        'Dune',
        'Pearl',
        'Blush',
        'Linen',
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: 'bg preset: $label');
      }
    });

    testWidgets('renders 16 surface color presets', (tester) async {
      await pumpThemeSettings(tester);

      const labels = [
        'Slate Blue',
        'Graphite',
        'Bronze',
        'Cinnamon',
        'Ivory',
        'Sky',
        'Sandstone',
        'Sage',
        'Peach',
        'Lavender',
        'Pearl Surface',
        'Mint',
        'Rose',
        'Amber',
        'Clay',
        'Steel',
      ];
      for (final label in labels) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'surface preset: $label',
        );
      }
    });

    testWidgets('renders 16 font color presets', (tester) async {
      await pumpThemeSettings(tester);

      const labels = [
        'White',
        'Ivory White',
        'Butter',
        'Pearl White',
        'Warm Gray',
        'Gray',
        'Slate',
        'Charcoal',
        'Black',
        'Sepia',
        'Coffee',
        'Caramel',
        'Sand',
        'Honey',
        'Crimson',
        'Navy',
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: 'font preset: $label');
      }
    });

    testWidgets('renders custom color button for each section', (tester) async {
      await pumpThemeSettings(tester);

      expect(find.text('Custom Color'), findsNWidgets(4));
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
      expect(
        settings.accentColorValue,
        equals(const Color(0xFF8B5CF6).toARGB32()),
      );
      expect(settings.themePreset, equals('custom'));
    });

    testWidgets('tapping background preset updates scaffold bg color', (
      tester,
    ) async {
      await pumpThemeSettings(tester);

      await tester.tap(find.text('Obsidian'));
      await tester.pumpAndSettle();

      final settings = testNotifier.state;
      expect(
        settings.scaffoldBgColorValue,
        equals(const Color(0xFF000000).toARGB32()),
      );
    });

    testWidgets('tapping surface preset updates surface color', (tester) async {
      await pumpThemeSettings(tester);

      await tester.tap(find.text('Ivory'));
      await tester.pumpAndSettle();

      final settings = testNotifier.state;
      expect(
        settings.surfaceColorValue,
        equals(const Color(0xFFE8E0D0).toARGB32()),
      );
    });

    testWidgets('isDarkMode controlled by themeMode (A-11)', (tester) async {
      await pumpThemeSettings(tester);

      testNotifier.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(testNotifier.state.isDarkMode, isTrue);

      testNotifier.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(testNotifier.state.isDarkMode, isFalse);
    });

    testWidgets('selected preset shows border highlight', (tester) async {
      await pumpThemeSettings(tester);

      final oceanGesture = find.ancestor(
        of: find.text('Ocean'),
        // 修复 AXTree 时将 AnimatedContainer 改为 Container（避免 200ms 动画
        // 在主题色变化时产生帧序列触发 Windows accessibility_bridge 更新失败）。
        matching: find.byType(Container),
      );
      expect(oceanGesture, findsOneWidget);

      final container = tester.widget<Container>(oceanGesture.first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

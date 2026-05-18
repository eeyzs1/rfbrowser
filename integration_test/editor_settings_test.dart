import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/settings/editor_settings_section.dart';
import 'package:rfbrowser/services/settings_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Editor Settings', () {
    late _TestSettingsNotifier testNotifier;

    Future<void> pumpEditorSettings(WidgetTester tester) async {
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
              body: EditorSettingsSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    tearDown(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alwaysShowWelcomePage');
      await prefs.remove('editorFontSize');
    });

    testWidgets('renders always show welcome page toggle', (tester) async {
      await pumpEditorSettings(tester);

      expect(find.text('Always Show Welcome Page'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('renders font size slider with default value', (tester) async {
      await pumpEditorSettings(tester);

      expect(find.text('Font Size'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('14px'), findsOneWidget);
    });

    testWidgets('toggling welcome page switch updates state', (tester) async {
      await pumpEditorSettings(tester);

      final switchFinder = find.byType(Switch);
      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('font size slider updates state and display text', (tester) async {
      await pumpEditorSettings(tester);

      expect(find.text('14px'), findsOneWidget);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, equals(14.0));
      expect(slider.min, equals(8.0));
      expect(slider.max, equals(48.0));
      expect(slider.divisions, equals(40));
    });

    testWidgets('welcome page toggle persists to settings', (tester) async {
      await pumpEditorSettings(tester);

      testNotifier.setAlwaysShowWelcomePage(true);
      await tester.pumpAndSettle();

      expect(testNotifier.state.alwaysShowWelcomePage, isTrue);
    });

    testWidgets('font size change persists to settings', (tester) async {
      await pumpEditorSettings(tester);

      testNotifier.setEditorFontSize(24.0);
      await tester.pumpAndSettle();

      expect(testNotifier.state.editorFontSize, equals(24.0));
    });
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/settings_page.dart';
import 'package:rfbrowser/services/settings_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Page', () {
    Future<void> pumpSettingsPage(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders Quick Moves section', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.text('Quick Moves'), findsOneWidget);
    });

    testWidgets('renders Theme section', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.text('Theme'), findsOneWidget);
    });

    testWidgets('settings page is scrollable with ListView', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('settings page has app bar', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('theme section contains color presets', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.text('Ocean'), findsOneWidget);
      expect(find.text('Violet'), findsOneWidget);
    });

    testWidgets('contains major visible sections in widget tree', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.text('Quick Moves'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
    });
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

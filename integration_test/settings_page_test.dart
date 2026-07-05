import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/settings_page.dart';
import 'package:rfbrowser/ui/pages/settings/general_settings_page.dart';
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

    testWidgets('renders 3 category tiles', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.byIcon(Icons.settings_suggest), findsOneWidget);
    });

    testWidgets('settings page is scrollable with ListView', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('settings page has app bar', (tester) async {
      await pumpSettingsPage(tester);

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('tapping General tile shows Theme section and color presets', (
      tester,
    ) async {
      await pumpSettingsPage(tester);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.byType(GeneralSettingsPage), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Ocean'), findsOneWidget);
      expect(find.text('Violet'), findsOneWidget);
    });

    testWidgets('General sub-page can scroll to Quick Moves section', (
      tester,
    ) async {
      await pumpSettingsPage(tester);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Quick Moves'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Quick Moves'), findsOneWidget);
    });
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

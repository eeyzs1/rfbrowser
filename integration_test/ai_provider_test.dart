import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/settings/ai_settings_section.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Provider Management', () {
    Future<void> pumpAISettings(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AISettingsSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> addProviderViaDialog(
      WidgetTester tester,
      String name, {
      String baseUrl = 'https://api.test.com',
      String apiKey = 'sk-test-key',
    }) async {
      await tester.tap(find.text('Add Provider'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), name);
      await tester.enterText(textFields.at(1), baseUrl);
      if (find.byType(TextField).evaluate().length > 2) {
        await tester.enterText(textFields.at(2), apiKey);
      }

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    tearDown(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ai_providers');
      await prefs.remove('ai_models');
      await prefs.remove('ai_active_config');
    });

    testWidgets('shows empty state when no providers configured',
        (tester) async {
      await pumpAISettings(tester);

      expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
    });

    testWidgets('can add a provider via dialog and it appears in list',
        (tester) async {
      await pumpAISettings(tester);

      await addProviderViaDialog(tester, 'Test Provider');

      expect(find.text('Test Provider'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(
        find.text('No providers configured. Add one to get started.'),
        findsNothing,
      );
    });

    testWidgets('can add multiple providers', (tester) async {
      await pumpAISettings(tester);

      await addProviderViaDialog(tester, 'Provider A');
      await addProviderViaDialog(tester, 'Provider B');

      expect(find.text('Provider A'), findsOneWidget);
      expect(find.text('Provider B'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNWidgets(2));
    });

    testWidgets('can toggle provider enabled/disabled via Switch',
        (tester) async {
      await pumpAISettings(tester);

      await addProviderViaDialog(tester, 'Toggle Test');

      final tile = find.widgetWithText(ExpansionTile, 'Toggle Test');
      expect(tile, findsOneWidget);

      final switchFinder = find.descendant(
        of: tile,
        matching: find.byType(Switch),
      );

      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('disabled provider shows line-through on name', (tester) async {
      await pumpAISettings(tester);

      await addProviderViaDialog(tester, 'Visual Test');

      final tile = find.widgetWithText(ExpansionTile, 'Visual Test');
      final switchFinder = find.descendant(
        of: tile,
        matching: find.byType(Switch),
      );

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final nameFinder = find.descendant(
        of: tile,
        matching: find.byType(Text),
      );

      bool foundLineThrough = false;
      for (final element in nameFinder.evaluate()) {
        final widget = element.widget as Text;
        if (widget.data == 'Visual Test') {
          expect(widget.style?.decoration, TextDecoration.lineThrough);
          foundLineThrough = true;
          break;
        }
      }
      expect(foundLineThrough, isTrue);
    });

    testWidgets(
        'deleting a provider removes it from list immediately (C-7 regression)',
        (tester) async {
      await pumpAISettings(tester);

      await addProviderViaDialog(tester, 'Delete Target');

      expect(find.text('Delete Target'), findsOneWidget);

      final tile = find.widgetWithText(ExpansionTile, 'Delete Target');
      final menuButton = find.descendant(
        of: tile,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Target'), findsNothing);
      expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
    });

    testWidgets('cancel delete does not remove provider', (tester) async {
      await pumpAISettings(tester);

      await addProviderViaDialog(tester, 'Keep Me');

      final tile = find.widgetWithText(ExpansionTile, 'Keep Me');
      final menuButton = find.descendant(
        of: tile,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Keep Me'), findsOneWidget);
    });

    testWidgets('add provider with empty name does nothing', (tester) async {
      await pumpAISettings(tester);

      await tester.tap(find.text('Add Provider'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
    });

    testWidgets('toggle via popup menu works same as Switch', (tester) async {
      await pumpAISettings(tester);

      await addProviderViaDialog(tester, 'Menu Toggle');

      final tile = find.widgetWithText(ExpansionTile, 'Menu Toggle');
      final menuButton = find.descendant(
        of: tile,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();

      final switchFinder = find.descendant(
        of: tile,
        matching: find.byType(Switch),
      );
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);
    });
  });
}

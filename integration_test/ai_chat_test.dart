import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/ai_chat_panel.dart';
import 'package:rfbrowser/services/ai_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Chat Panel', () {
    Future<void> pumpAIChatPanel(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiProvider.overrideWith(() => _TestAINotifier()),
            aiConfigProvider.overrideWith(() => _TestAIConfigNotifier()),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AIChatPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders chat input field', (tester) async {
      await pumpAIChatPanel(tester);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders send button', (tester) async {
      await pumpAIChatPanel(tester);

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('typing @ triggers autocomplete', (tester) async {
      await pumpAIChatPanel(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello @');
      await tester.pumpAndSettle();

      expect(find.text('@note[...]'), findsOneWidget);
      expect(find.text('@web[current]'), findsOneWidget);
    });

    testWidgets('autocomplete shows clip option', (tester) async {
      await pumpAIChatPanel(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello @');
      await tester.pumpAndSettle();

      expect(find.text('@clip[...]'), findsOneWidget);
    });

    testWidgets('autocomplete hides when @ is not present', (tester) async {
      await pumpAIChatPanel(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello world');
      await tester.pumpAndSettle();

      expect(find.text('@note[...]'), findsNothing);
    });

    testWidgets('shows new conversation button', (tester) async {
      await pumpAIChatPanel(tester);

      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
    });

    testWidgets('shows model selector with provider chip', (tester) async {
      await pumpAIChatPanel(tester);

      expect(find.text('Test Model'), findsOneWidget);
    });

    testWidgets('shows empty state with AI assistant text', (tester) async {
      await pumpAIChatPanel(tester);

      expect(find.byIcon(Icons.psychology), findsOneWidget);
    });

    testWidgets('shows clear chat button', (tester) async {
      await pumpAIChatPanel(tester);

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('shows skill picker button', (tester) async {
      await pumpAIChatPanel(tester);

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('clicking autocomplete item inserts text', (tester) async {
      await pumpAIChatPanel(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello @');
      await tester.pumpAndSettle();

      await tester.tap(find.text('@note[...]'));
      await tester.pumpAndSettle();

      final controller = tester.widget<TextField>(textField).controller;
      expect(controller!.text, contains('@note[]'));
    });
  });
}

class _TestAINotifier extends AINotifier {
  @override
  AIState build() => AIState();
}

class _TestAIConfigNotifier extends AIConfigNotifier {
  @override
  AIConfigState build() => AIConfigState(
    providers: [
      AIProvider(
        id: 'test-provider',
        name: 'Test Provider',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.test.com',
        isEnabled: true,
      ),
    ],
    models: [
      AIModel(
        id: 'test-model',
        providerId: 'test-provider',
        displayName: 'Test Model',
      ),
    ],
    activeConfig: ActiveAIConfig(
      providerId: 'test-provider',
      modelId: 'test-model',
    ),
  );
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

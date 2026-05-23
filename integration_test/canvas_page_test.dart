import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/services/canvas_service.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/ui/pages/canvas_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Canvas Page', () {
    Future<void> pumpCanvasView(
      WidgetTester tester, {
      CanvasData? initialData,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasProvider.overrideWith(
              () => _TestCanvasNotifier(initialData: initialData),
            ),
            knowledgeProvider.overrideWith(() => _TestKnowledgeNotifier()),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            vaultProvider.overrideWith(() => _TestVaultNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Material(child: CanvasView()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('canvas renders toolbar with add card button', (tester) async {
      await pumpCanvasView(tester);

      expect(find.byIcon(Icons.add), findsAtLeast(1));
    });

    testWidgets('canvas renders undo and redo buttons', (tester) async {
      await pumpCanvasView(tester);

      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.redo), findsOneWidget);
    });

    testWidgets('canvas renders auto-connect toggle button', (tester) async {
      await pumpCanvasView(tester);

      expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
    });

    testWidgets('canvas renders CustomPaint for card rendering', (
      tester,
    ) async {
      await pumpCanvasView(tester);

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('tapping add card calls canvasNotifier.addCard', (
      tester,
    ) async {
      final notifier = _TestCanvasNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasProvider.overrideWith(() => notifier),
            knowledgeProvider.overrideWith(() => _TestKnowledgeNotifier()),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            vaultProvider.overrideWith(() => _TestVaultNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Material(child: CanvasView()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(notifier.state.cards.length, 0);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump(const Duration(seconds: 1));

      expect(notifier.state.cards.length, 1);
    });

    testWidgets('canvasNotifier.addCard creates a card with text type', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [vaultProvider.overrideWith(() => _TestVaultNotifier())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(canvasProvider.notifier);
      final card = notifier.createCard(
        CanvasCardType.text,
        const Offset(100, 100),
      );
      await notifier.addCard(card);

      expect(notifier.state.cards.length, 1);
      expect(notifier.state.cards.first.type, CanvasCardType.text);
    });

    testWidgets('canvasNotifier.addConnection creates a connection', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [vaultProvider.overrideWith(() => _TestVaultNotifier())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(canvasProvider.notifier);
      final card1 = notifier.createCard(
        CanvasCardType.note,
        const Offset(0, 0),
      );
      final card2 = notifier.createCard(
        CanvasCardType.note,
        const Offset(200, 0),
      );
      await notifier.addCard(card1);
      await notifier.addCard(card2);

      final conn = notifier.createConnection(card1.id, card2.id);
      await notifier.addConnection(conn);

      expect(notifier.state.connections.length, 1);
      expect(notifier.state.connections.first.fromCardId, card1.id);
      expect(notifier.state.connections.first.toCardId, card2.id);
    });

    testWidgets('canvasNotifier.undo reverts last action', (tester) async {
      final container = ProviderContainer(
        overrides: [vaultProvider.overrideWith(() => _TestVaultNotifier())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(canvasProvider.notifier);
      final card = notifier.createCard(
        CanvasCardType.text,
        const Offset(100, 100),
      );
      await notifier.addCard(card);

      expect(notifier.state.cards.length, 1);

      notifier.undo();

      expect(notifier.state.cards.length, 0);
    });

    testWidgets('canvasWithCards renders both cards and connections', (
      tester,
    ) async {
      final card1 = CanvasCard(
        id: 'card_1',
        type: CanvasCardType.note,
        x: 100,
        y: 100,
        width: 160,
        height: 100,
        title: 'Card 1',
      );
      final card2 = CanvasCard(
        id: 'card_2',
        type: CanvasCardType.note,
        x: 300,
        y: 100,
        width: 160,
        height: 100,
        title: 'Card 2',
      );
      final conn = CanvasConnection(
        id: 'conn_1',
        fromCardId: 'card_1',
        toCardId: 'card_2',
      );
      final initialData = CanvasData(
        cards: [card1, card2],
        connections: [conn],
      );

      await pumpCanvasView(tester, initialData: initialData);

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}

class _TestCanvasNotifier extends CanvasNotifier {
  final CanvasData? _initialData;

  _TestCanvasNotifier({CanvasData? initialData}) : _initialData = initialData;

  @override
  CanvasData build() => _initialData ?? CanvasData();
}

class _TestKnowledgeNotifier extends KnowledgeNotifier {
  @override
  KnowledgeState build() => const KnowledgeState();
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

class _TestVaultNotifier extends VaultNotifier {
  @override
  VaultState build() => VaultState();
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/data/models/quick_move.dart';
import 'package:rfbrowser/data/stores/hnsw_index.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/services/embedding_service.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/services/quick_move_service.dart';
import 'package:rfbrowser/ui/widgets/command_bar.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CommandBar', () {
    late String lastCommand;
    late bool onCloseCalled;

    Future<void> pumpCommandBar(WidgetTester tester) async {
      lastCommand = '';
      onCloseCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(() => _TestKnowledgeNotifier()),
            quickMoveProvider.overrideWith(() => _TestQuickMoveNotifier()),
            hybridSearchProvider.overrideWith((ref) => _TestHybridSearch()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CommandBar(
                onCommand: (cmd) => lastCommand = cmd,
                onClose: () => onCloseCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders with a TextField', (tester) async {
      await pumpCommandBar(tester);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('displays built-in commands initially', (tester) async {
      await pumpCommandBar(tester);

      expect(find.text('New Note'), findsOneWidget);
      expect(find.text('New Tab'), findsOneWidget);
      expect(find.text('Open Daily Note'), findsOneWidget);
      expect(find.text('Switch Theme'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Graph View'), findsOneWidget);
      expect(find.text('Canvas View'), findsOneWidget);
    });

    testWidgets('typing text filters commands', (tester) async {
      await pumpCommandBar(tester);

      expect(find.text('New Note'), findsOneWidget);
      expect(find.text('Graph View'), findsOneWidget);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'graph');
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Graph View'), findsOneWidget);
      expect(find.text('New Note'), findsNothing);
    });

    testWidgets('typing slash enters QuickMove mode', (tester) async {
      await pumpCommandBar(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, '/');
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      final hint = find.text('Quick Move — type command name...');
      expect(hint, findsOneWidget);
    });

    testWidgets('onCommand callback works when a command is selected', (
      tester,
    ) async {
      await pumpCommandBar(tester);

      final commandTile = find.text('New Note');
      await tester.tap(commandTile);
      await tester.pumpAndSettle();

      expect(lastCommand, 'New Note');
    });

    testWidgets('onClose callback works', (tester) async {
      await pumpCommandBar(tester);

      final closeButton = find.byIcon(Icons.close);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(onCloseCalled, isTrue);
    });
  });
}

class _TestKnowledgeNotifier extends KnowledgeNotifier {
  @override
  KnowledgeState build() => KnowledgeState();
}

class _TestQuickMoveNotifier extends QuickMoveNotifier {
  @override
  QuickMoveState build() => QuickMoveState(
    moves: [
      QuickMove(
        id: 'test_translate',
        name: 'translate',
        promptTemplate: 'Translate: {input}',
        type: QuickMoveType.preset,
      ),
    ],
  );
}

class _TestHybridSearch extends HybridSearch {
  _TestHybridSearch() : super(_TestSemanticSearch());

  @override
  Future<List<HybridSearchResult>> search(
    String query, {
    int topK = 20,
  }) async => [];
}

class _TestSemanticSearch extends SemanticSearch {
  _TestSemanticSearch() : super(_TestEmbeddingService());

  @override
  Future<List<SearchResult>> search(String query, {int topK = 20}) async => [];
}

class _TestEmbeddingService extends EmbeddingService {
  @override
  Future<List<double>> embed(
    String text, {
    AIProvider? provider,
    String? apiKey,
    String? modelId,
  }) async => List.filled(128, 0.0);
}

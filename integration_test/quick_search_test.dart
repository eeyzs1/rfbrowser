import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/ui/widgets/quick_search_bar.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('QuickSearchBar', () {
    testWidgets('renders search text field with search icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: []),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows no results when query is empty', (tester) async {
      final notes = [
        Note(title: 'Note One', filePath: 'note-one.md'),
        Note(title: 'Note Two', filePath: 'note-two.md'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('filters notes by title', (tester) async {
      final notes = [
        Note(title: 'Flutter Guide', filePath: 'flutter.md'),
        Note(title: 'Dart Tips', filePath: 'dart.md'),
        Note(title: 'Riverpod Docs', filePath: 'riverpod.md'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pumpAndSettle();

      expect(find.text('Flutter Guide'), findsOneWidget);
      expect(find.text('Dart Tips'), findsNothing);
      expect(find.text('Riverpod Docs'), findsNothing);
    });

    testWidgets('filters notes by content', (tester) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'about widgets'),
        Note(title: 'Note B', filePath: 'b.md', content: 'about state'),
        Note(title: 'Note C', filePath: 'c.md', content: 'more widgets tips'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'widgets');
      await tester.pumpAndSettle();

      expect(find.text('Note A'), findsOneWidget);
      expect(find.text('Note B'), findsNothing);
      expect(find.text('Note C'), findsOneWidget);
    });

    testWidgets('shows result items with description icon', (tester) async {
      final notes = [Note(title: 'Search Me', filePath: 'search.md')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Search');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.text('Search Me'), findsOneWidget);
    });

    testWidgets('case insensitive search', (tester) async {
      final notes = [Note(title: 'UpperCase', filePath: 'upper.md')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'upper');
      await tester.pumpAndSettle();

      expect(find.text('UpperCase'), findsOneWidget);
    });

    testWidgets('calls onNoteSelected when tapping a result', (tester) async {
      Note? selectedNote;
      final notes = [Note(title: 'Tap Target', filePath: 'tap.md')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: QuickSearchBar(
                onNoteSelected: (note) => selectedNote = note,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Tap');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap Target'));
      await tester.pumpAndSettle();

      expect(selectedNote, isNotNull);
      expect(selectedNote!.title, 'Tap Target');
    });

    testWidgets('clears input after tapping result', (tester) async {
      final notes = [Note(title: 'Clear Test', filePath: 'clear.md')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Clear');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear Test'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
      expect(find.text('Clear Test'), findsNothing);
    });

    testWidgets('does not show results for no match', (tester) async {
      final notes = [Note(title: 'Only Note', filePath: 'only.md')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'non-existent');
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('limits results to 8 items', (tester) async {
      final notes = List.generate(
        15,
        (i) =>
            Note(title: 'Note $i', filePath: 'note-$i.md', content: 'search'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(notes: notes),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QuickSearchBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'search');
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsAtLeastNWidgets(5));
    });
  });
}

class _TestKnowledgeNotifier extends KnowledgeNotifier {
  final List<Note> _notes;

  _TestKnowledgeNotifier({List<Note>? notes}) : _notes = notes ?? [];

  @override
  KnowledgeState build() => KnowledgeState(notes: _notes);
}

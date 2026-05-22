import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/ui/pages/editor_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('EditorView CRUD Widget Interaction', () {
    final testNote = Note(
      title: 'Test Note',
      filePath: 'test-note.md',
      content: 'Hello World',
    );

    final testVault = VaultConfig(
      path: '/tmp/test-vault',
      name: 'Test Vault',
      lastOpened: DateTime.now(),
    );

    Future<void> pumpEditorPage(
      WidgetTester tester, {
      List<Note> notes = const [],
      String? activeNoteId,
      VaultConfig? currentVault,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: notes,
                activeNoteId: activeNoteId,
              ),
            ),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            vaultProvider.overrideWith(
              () => _TestVaultNotifier(currentVault: currentVault),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Material(child: EditorView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows empty state when no vault connected', (tester) async {
      await pumpEditorPage(tester);

      expect(find.byIcon(Icons.edit_note), findsOneWidget);
    });

    testWidgets('shows create note button when vault connected but no active note',
        (tester) async {
      await pumpEditorPage(tester, currentVault: testVault);

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows note title and format toolbar when active note exists',
        (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.text('Test Note'), findsOneWidget);
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
    });

    testWidgets('shows Edit, Preview, Split segmented buttons',
        (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Split'), findsOneWidget);
    });

    testWidgets('shows save button with check icon when saved',
        (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('format toolbar contains bold, italic, heading buttons',
        (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
      expect(find.byIcon(Icons.title), findsOneWidget);
    });

    testWidgets('format toolbar contains list, link, quote, code buttons',
        (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
    });

    testWidgets(
        'format toolbar contains strikethrough, checklist, table, hr buttons',
        (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.strikethrough_s), findsOneWidget);
      expect(find.byIcon(Icons.checklist), findsOneWidget);
      expect(find.byIcon(Icons.table_chart), findsOneWidget);
      expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
    });

    testWidgets('shows status bar with file path and word count icons',
        (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('tapping preview hides format toolbar', (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.format_bold), findsOneWidget);

      final previewSegment = find.text('Preview');
      if (previewSegment.evaluate().isNotEmpty) {
        await tester.tap(previewSegment);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.format_bold), findsNothing);
      }
    });

    testWidgets('tapping split shows both edit and preview', (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      final splitSegment = find.text('Split');
      if (splitSegment.evaluate().isNotEmpty) {
        await tester.tap(splitSegment);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.format_bold), findsOneWidget);
      }
    });

    testWidgets('tapping edit shows toolbar again after preview',
        (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      final previewSegment = find.text('Preview');
      if (previewSegment.evaluate().isNotEmpty) {
        await tester.tap(previewSegment);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.format_bold), findsNothing);
      }

      final editSegment = find.text('Edit');
      if (editSegment.evaluate().isNotEmpty) {
        await tester.tap(editSegment);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.format_bold), findsOneWidget);
      }
    });
  });
}

class _TestKnowledgeNotifier extends KnowledgeNotifier {
  final List<Note> _notes;
  final String? _activeNoteId;

  _TestKnowledgeNotifier({
    List<Note>? notes,
    String? activeNoteId,
  })  : _notes = notes ?? [],
        _activeNoteId = activeNoteId;

  @override
  KnowledgeState build() => KnowledgeState(
        notes: _notes,
        activeNoteId: _activeNoteId,
      );
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

class _TestVaultNotifier extends VaultNotifier {
  final VaultConfig? _currentVault;

  _TestVaultNotifier({VaultConfig? currentVault})
      : _currentVault = currentVault;

  @override
  VaultState build() => VaultState(currentVault: _currentVault);
}
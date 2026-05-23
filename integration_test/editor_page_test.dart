import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/editor_page.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/data/models/note.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Editor Page', () {
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
            home: const EditorView(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows no vault connected when no vault', (tester) async {
      await pumpEditorPage(tester);

      expect(find.byIcon(Icons.edit_note), findsOneWidget);
    });

    testWidgets('shows no note selected when vault exists but no active note', (
      tester,
    ) async {
      await pumpEditorPage(tester, currentVault: testVault);

      expect(find.byIcon(Icons.edit_note), findsOneWidget);
    });

    testWidgets('shows new note button when no note selected', (tester) async {
      await pumpEditorPage(tester, currentVault: testVault);

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows note title in header when active note exists', (
      tester,
    ) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.text('Test Note'), findsOneWidget);
    });

    testWidgets('shows format toolbar in edit mode', (tester) async {
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

    testWidgets('format toolbar contains all formatting buttons', (
      tester,
    ) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.title), findsOneWidget);
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
      expect(find.byIcon(Icons.strikethrough_s), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.data_object), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
      expect(find.byIcon(Icons.format_list_numbered), findsOneWidget);
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
      expect(find.byIcon(Icons.checklist), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.add_link), findsOneWidget);
      expect(find.byIcon(Icons.input), findsOneWidget);
      expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
      expect(find.byIcon(Icons.table_chart), findsOneWidget);
    });

    testWidgets('shows status bar with file path', (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('shows save status as saved initially', (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets(
      'shows view mode SegmentedButton with edit and preview labels',
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
      },
    );

    testWidgets('shows save button in header', (tester) async {
      await pumpEditorPage(
        tester,
        notes: [testNote],
        activeNoteId: testNote.id,
        currentVault: testVault,
      );

      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('switching to preview mode hides format toolbar', (
      tester,
    ) async {
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
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.format_bold), findsNothing);
      }
    });
  });
}

class _TestKnowledgeNotifier extends KnowledgeNotifier {
  final List<Note> _notes;
  final String? _activeNoteId;

  _TestKnowledgeNotifier({List<Note>? notes, String? activeNoteId})
    : _notes = notes ?? [],
      _activeNoteId = activeNoteId;

  @override
  KnowledgeState build() =>
      KnowledgeState(notes: _notes, activeNoteId: _activeNoteId);
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

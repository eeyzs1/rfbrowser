import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/data/models/browser_tab.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/services/shortcut_service.dart';
import 'package:rfbrowser/ui/pages/editor_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('User Journey — End-to-End Scenarios', () {
    group('Step 1: Canvas — Infinite Canvas Model', () {
      testWidgets('canvas data serializes cards and connections', (tester) async {
        final data = CanvasData(
          cards: [
            CanvasCard(
              id: 'card1',
              type: CanvasCardType.text,
              title: 'Idea 1',
              x: 100,
              y: 100,
            ),
            CanvasCard(
              id: 'card2',
              type: CanvasCardType.note,
              title: 'Note Card',
              x: 300,
              y: 100,
              noteId: 'note-1',
            ),
          ],
          connections: [
            CanvasConnection(
              id: 'conn1',
              fromCardId: 'card1',
              toCardId: 'card2',
            ),
          ],
        );

        expect(data.cards.length, 2);
        expect(data.connections.length, 1);
      });

      testWidgets('canvas card type labels are meaningful', (tester) async {
        expect(CanvasCardType.text.label, 'Text');
        expect(CanvasCardType.note.label, 'Note');
        expect(CanvasCardType.image.label, 'Image');
        expect(CanvasCardType.link.label, 'Link');
      });

      testWidgets('canvas connection computes sides correctly', (tester) async {
        final from = CanvasCard(id: 'from', type: CanvasCardType.text, x: 0, y: 0);
        final to = CanvasCard(id: 'to', type: CanvasCardType.text, x: 300, y: 0);

        final (fromSide, toSide) = CanvasConnection.computeSides(from, to);
        expect(fromSide, ConnectionSide.right);
        expect(toSide, ConnectionSide.left);
      });

      testWidgets('canvas data serializes to JSON', (tester) async {
        final data = CanvasData(
          cards: [
            CanvasCard(id: 'card1', type: CanvasCardType.text, title: 'Test'),
          ],
        );

        final json = data.toJsonString();
        expect(json, isNotEmpty);
        expect(json, contains('card1'));
      });

      testWidgets('canvas copyWith clearSelectedCardIds works (C-4)', (tester) async {
        final data = CanvasData(
          cards: [
            CanvasCard(id: 'card1', type: CanvasCardType.text, title: 'Card 1'),
          ],
          selectedCardIds: ['card1'],
        );

        final cleared = data.copyWith(clearSelectedCardIds: true);
        expect(cleared.selectedCardIds, isEmpty);
        expect(cleared.cards.length, equals(1));
      });
    });

    group('Step 2: Security — Safe Browsing', () {
      testWidgets('bookmark folder fromJson prevents self-referencing (C-6)', (tester) async {
        final json = {
          'id': 'bookmarks-bar',
          'name': 'Bookmarks',
          'parentId': 'bookmarks-bar',
          'isExpanded': true,
        };
        final folder = BookmarkFolder.fromJson(json);
        expect(folder.parentId, isEmpty);
      });

      testWidgets('non-root bookmark folder keeps its parentId', (tester) async {
        final json = {
          'id': 'sub-folder',
          'name': 'Sub Folder',
          'parentId': 'bookmarks-bar',
          'isExpanded': true,
        };
        final folder = BookmarkFolder.fromJson(json);
        expect(folder.parentId, 'bookmarks-bar');
      });
    });

    group('Step 3: End-to-End Workflow', () {
      testWidgets('complete user journey: vault → note → editor loaded', (tester) async {
        final vault = VaultConfig(
          path: '/vault',
          name: 'Research Vault',
          lastOpened: DateTime.now(),
        );
        final note = Note(
          title: 'AI Research',
          filePath: 'ai-research.md',
          content: 'Notes on artificial intelligence',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              knowledgeProvider.overrideWith(
                () => _TestKnowledgeNotifier(
                  notes: [note],
                  activeNoteId: note.id,
                ),
              ),
              settingsProvider.overrideWith(() => _TestSettingsNotifier()),
              vaultProvider.overrideWith(
                () => _TestVaultNotifier(currentVault: vault),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const EditorView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('AI Research'), findsOneWidget);
        expect(find.byIcon(Icons.format_bold), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Preview'), findsOneWidget);
        expect(find.text('Split'), findsOneWidget);
      });
    });

    group('Step 4: Shortcut Customization', () {
      testWidgets('ShortcutService has scene switching shortcuts registered', (tester) async {
        final service = ShortcutService();
        expect(service.getShortcut('switch_capture'), 'Ctrl+1');
        expect(service.getShortcut('switch_think'), 'Ctrl+2');
        expect(service.getShortcut('switch_connect'), 'Ctrl+3');
      });

      testWidgets('ShortcutService has connect view shortcuts registered', (tester) async {
        final service = ShortcutService();
        expect(service.getShortcut('connect_canvas'), 'Ctrl+4');
        expect(service.getShortcut('connect_graph'), 'Ctrl+5');
      });

      testWidgets('user can customize a shortcut without conflict', (tester) async {
        final service = ShortcutService();
        service.register('switch_capture', 'Ctrl+Shift+1');
        expect(service.getShortcut('switch_capture'), 'Ctrl+Shift+1');
      });

      testWidgets('user cannot assign a conflicting shortcut', (tester) async {
        final service = ShortcutService();
        expect(
          () => service.register('switch_capture', 'Ctrl+S'),
          throwsA(isA<ShortcutConflictError>()),
        );
      });

      testWidgets('user can reset shortcuts to defaults', (tester) async {
        final service = ShortcutService();
        service.register('switch_capture', 'Ctrl+Shift+1');
        expect(service.getShortcut('switch_capture'), 'Ctrl+Shift+1');

        service.resetToDefaults();
        expect(service.getShortcut('switch_capture'), 'Ctrl+1');
      });

      testWidgets('ShortcutService defaults include all actions', (tester) async {
        final service = ShortcutService();
        expect(service.allBindings.length, greaterThanOrEqualTo(20));
      });

      testWidgets('findActionForShortcut reverse lookup works', (tester) async {
        final service = ShortcutService();
        expect(service.findActionForShortcut('Ctrl+1'), 'switch_capture');
        expect(service.findActionForShortcut('Ctrl+5'), 'connect_graph');
        expect(service.findActionForShortcut('Ctrl+Z'), 'canvas_undo');
      });
    });
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

class _TestVaultNotifier extends VaultNotifier {
  final VaultConfig? _currentVault;

  _TestVaultNotifier({VaultConfig? currentVault}) : _currentVault = currentVault;

  @override
  VaultState build() => VaultState(currentVault: _currentVault);
}

class _TestKnowledgeNotifier extends KnowledgeNotifier {
  final List<Note> _notes;
  final String? _activeNoteId;
  final List<Link> _links;

  _TestKnowledgeNotifier({
    List<Note>? notes,
    String? activeNoteId,
    List<Link>? links,
  })  : _notes = notes ?? [],
        _activeNoteId = activeNoteId,
        _links = links ?? [];

  @override
  KnowledgeState build() => KnowledgeState(
        notes: _notes,
        activeNoteId: _activeNoteId,
        links: _links,
      );
}
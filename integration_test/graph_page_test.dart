import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/graph_page.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Graph Page', () {
    Future<void> pumpGraphPage(
      WidgetTester tester, {
      List<Note> notes = const [],
      List<Link> links = const [],
      String? activeNoteId,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: notes,
                links: links,
                activeNoteId: activeNoteId,
              ),
            ),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            vaultProvider.overrideWith(() => _TestVaultNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GraphView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows empty state when no notes', (tester) async {
      await pumpGraphPage(tester);

      expect(find.byIcon(Icons.hub), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows graph canvas when notes exist', (tester) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
        Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
      ];
      final links = [
        Link(
          sourceId: notes[0].id,
          targetId: notes[1].id,
          type: LinkType.wikilink,
        ),
      ];

      await pumpGraphPage(
        tester,
        notes: notes,
        links: links,
        activeNoteId: notes[0].id,
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows toolbar IconButtons when notes exist', (tester) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
        Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
      ];
      final links = [
        Link(
          sourceId: notes[0].id,
          targetId: notes[1].id,
          type: LinkType.wikilink,
        ),
      ];

      await pumpGraphPage(
        tester,
        notes: notes,
        links: links,
        activeNoteId: notes[0].id,
      );

      expect(find.byIcon(Icons.scatter_plot), findsOneWidget);
      expect(find.byIcon(Icons.account_tree), findsOneWidget);
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.byIcon(Icons.legend_toggle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
      expect(find.byIcon(Icons.file_download), findsOneWidget);
    });

    testWidgets(
      'default layout mode is force directed showing scatter_plot icon',
      (tester) async {
        final notes = [
          Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
          Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
        ];
        final links = [
          Link(
            sourceId: notes[0].id,
            targetId: notes[1].id,
            type: LinkType.wikilink,
          ),
        ];

        await pumpGraphPage(
          tester,
          notes: notes,
          links: links,
          activeNoteId: notes[0].id,
        );

        expect(find.byIcon(Icons.scatter_plot), findsOneWidget);
      },
    );

    testWidgets('default view mode is full showing account_tree icon', (
      tester,
    ) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
        Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
      ];
      final links = [
        Link(
          sourceId: notes[0].id,
          targetId: notes[1].id,
          type: LinkType.wikilink,
        ),
      ];

      await pumpGraphPage(
        tester,
        notes: notes,
        links: links,
        activeNoteId: notes[0].id,
      );

      expect(find.byIcon(Icons.account_tree), findsOneWidget);
    });

    testWidgets(
      'toggling layout mode switches icon from scatter_plot to circle',
      (tester) async {
        final notes = [
          Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
          Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
        ];
        final links = [
          Link(
            sourceId: notes[0].id,
            targetId: notes[1].id,
            type: LinkType.wikilink,
          ),
        ];

        await pumpGraphPage(
          tester,
          notes: notes,
          links: links,
          activeNoteId: notes[0].id,
        );

        expect(find.byIcon(Icons.scatter_plot), findsOneWidget);

        await tester.tap(find.byIcon(Icons.scatter_plot));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.circle), findsOneWidget);
        expect(find.byIcon(Icons.scatter_plot), findsNothing);
      },
    );

    testWidgets('toggling view mode switches icon from account_tree to hub', (
      tester,
    ) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
        Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
      ];
      final links = [
        Link(
          sourceId: notes[0].id,
          targetId: notes[1].id,
          type: LinkType.wikilink,
        ),
      ];

      await pumpGraphPage(
        tester,
        notes: notes,
        links: links,
        activeNoteId: notes[0].id,
      );

      expect(find.byIcon(Icons.account_tree), findsOneWidget);

      await tester.tap(find.byIcon(Icons.account_tree));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.hub), findsAtLeast(1));
    });

    testWidgets('zoom in button exists and is tappable', (tester) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
        Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
      ];
      final links = [
        Link(
          sourceId: notes[0].id,
          targetId: notes[1].id,
          type: LinkType.wikilink,
        ),
      ];

      await pumpGraphPage(
        tester,
        notes: notes,
        links: links,
        activeNoteId: notes[0].id,
      );

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    });

    testWidgets('zoom out button exists and is tappable', (tester) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
        Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
      ];
      final links = [
        Link(
          sourceId: notes[0].id,
          targetId: notes[1].id,
          type: LinkType.wikilink,
        ),
      ];

      await pumpGraphPage(
        tester,
        notes: notes,
        links: links,
        activeNoteId: notes[0].id,
      );

      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
    });

    testWidgets('reset view button uses center_focus_strong icon', (
      tester,
    ) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
        Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
      ];
      final links = [
        Link(
          sourceId: notes[0].id,
          targetId: notes[1].id,
          type: LinkType.wikilink,
        ),
      ];

      await pumpGraphPage(
        tester,
        notes: notes,
        links: links,
        activeNoteId: notes[0].id,
      );

      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('export uses PopupMenuButton with file_download icon', (
      tester,
    ) async {
      final notes = [
        Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
        Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
      ];
      final links = [
        Link(
          sourceId: notes[0].id,
          targetId: notes[1].id,
          type: LinkType.wikilink,
        ),
      ];

      await pumpGraphPage(
        tester,
        notes: notes,
        links: links,
        activeNoteId: notes[0].id,
      );

      expect(find.byIcon(Icons.file_download), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets(
      'stats toggle switches between analytics and analytics_outlined',
      (tester) async {
        final notes = [
          Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
          Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
        ];
        final links = [
          Link(
            sourceId: notes[0].id,
            targetId: notes[1].id,
            type: LinkType.wikilink,
          ),
        ];

        await pumpGraphPage(
          tester,
          notes: notes,
          links: links,
          activeNoteId: notes[0].id,
        );

        expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.analytics_outlined));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.analytics), findsAtLeast(1));
      },
    );

    testWidgets(
      'legend toggle switches between legend_toggle and legend_toggle_outlined',
      (tester) async {
        final notes = [
          Note(title: 'Note A', filePath: 'a.md', content: 'Content A'),
          Note(title: 'Note B', filePath: 'b.md', content: 'Content B'),
        ];
        final links = [
          Link(
            sourceId: notes[0].id,
            targetId: notes[1].id,
            type: LinkType.wikilink,
          ),
        ];

        await pumpGraphPage(
          tester,
          notes: notes,
          links: links,
          activeNoteId: notes[0].id,
        );

        expect(find.byIcon(Icons.legend_toggle_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.legend_toggle_outlined));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.legend_toggle), findsOneWidget);
      },
    );
  });
}

class _TestKnowledgeNotifier extends KnowledgeNotifier {
  final List<Note> _notes;
  final List<Link> _links;
  final String? _activeNoteId;

  _TestKnowledgeNotifier({
    List<Note>? notes,
    List<Link>? links,
    String? activeNoteId,
  }) : _notes = notes ?? [],
       _links = links ?? [],
       _activeNoteId = activeNoteId;

  @override
  KnowledgeState build() =>
      KnowledgeState(notes: _notes, links: _links, activeNoteId: _activeNoteId);
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

class _TestVaultNotifier extends VaultNotifier {
  @override
  VaultState build() => VaultState();
}

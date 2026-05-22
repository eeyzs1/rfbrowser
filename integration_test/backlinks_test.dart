import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/unlinked_mention.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/ui/widgets/backlinks_panel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BacklinksPanel', () {
    testWidgets('shows noNoteSelected when no active note', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [],
                activeNoteId: null,
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('shows noBacklinks when active note has no backlinks',
        (tester) async {
      final note = Note(
        title: 'Lonely Note',
        filePath: 'lonely.md',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [note],
                activeNoteId: note.id,
                links: [],
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('shows backlink count badge with zero', (tester) async {
      final note = Note(
        title: 'Count Zero',
        filePath: 'zero.md',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [note],
                activeNoteId: note.id,
                links: [],
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('renders backlink items from source notes', (tester) async {
      final sourceNote = Note(
        title: 'Source Note',
        filePath: 'source.md',
      );
      final targetNote = Note(
        title: 'Target Note',
        filePath: 'target.md',
      );
      final link = Link(
        sourceId: sourceNote.id,
        targetId: targetNote.id,
        type: LinkType.wikilink,
        context: 'see [[Target Note]] for details',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [sourceNote, targetNote],
                activeNoteId: targetNote.id,
                links: [link],
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Source Note'), findsOneWidget);
      expect(find.text('see [[Target Note]] for details'), findsOneWidget);
    });

    testWidgets('renders backlink count badge', (tester) async {
      final sourceNote = Note(
        title: 'Ref Note',
        filePath: 'ref.md',
      );
      final targetNote = Note(
        title: 'Referred Note',
        filePath: 'referred.md',
      );
      final link = Link(
        sourceId: sourceNote.id,
        targetId: targetNote.id,
        type: LinkType.wikilink,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [sourceNote, targetNote],
                activeNoteId: targetNote.id,
                links: [link],
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows multiple backlinks for the same target', (tester) async {
      final source1 = Note(title: 'Linker A', filePath: 'a.md');
      final source2 = Note(title: 'Linker B', filePath: 'b.md');
      final target = Note(title: 'Hub Note', filePath: 'hub.md');

      final links = [
        Link(sourceId: source1.id, targetId: target.id, type: LinkType.wikilink),
        Link(sourceId: source2.id, targetId: target.id, type: LinkType.reference),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [source1, source2, target],
                activeNoteId: target.id,
                links: links,
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Linker A'), findsOneWidget);
      expect(find.text('Linker B'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('embed backlinks show input icon instead of link icon',
        (tester) async {
      final sourceNote = Note(
        title: 'Embedder',
        filePath: 'embedder.md',
      );
      final targetNote = Note(
        title: 'Embedded',
        filePath: 'embedded.md',
      );
      final link = Link(
        sourceId: sourceNote.id,
        targetId: targetNote.id,
        type: LinkType.embed,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [sourceNote, targetNote],
                activeNoteId: targetNote.id,
                links: [link],
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.input), findsOneWidget);
      expect(find.byIcon(Icons.link), findsAtLeast(1));
    });

    testWidgets('shows close button when onClose provided', (tester) async {
      final note = Note(title: 'Test', filePath: 'test.md');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [note],
                activeNoteId: note.id,
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel(onClose: _noop)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('hides close button when onClose is null', (tester) async {
      final note = Note(title: 'Test', filePath: 'test.md');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [note],
                activeNoteId: note.id,
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('close button triggers onClose callback', (tester) async {
      bool closed = false;
      final note = Note(title: 'Test', filePath: 'test.md');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [note],
                activeNoteId: note.id,
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BacklinksPanel(onClose: () => closed = true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets('unlinked mentions section renders with link_off icon',
        (tester) async {
      final sourceNote = Note(
        title: 'Mentioner',
        filePath: 'mentioner.md',
        content: 'I mentioned Unlinked Title here',
      );
      final targetNote = Note(
        title: 'Unlinked Title',
        filePath: 'unlinked.md',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [sourceNote, targetNote],
                activeNoteId: sourceNote.id,
                links: [],
                unlinkedMentions: [
                  UnlinkedMentionResult(
                    sourceNoteId: sourceNote.id,
                    targetTitle: 'Unlinked Title',
                    context: 'I mentioned Unlinked Title here',
                    position: 13,
                  ),
                ],
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.link_off), findsAtLeast(1));
      expect(find.text('Unlinked Title'), findsOneWidget);
      expect(find.byIcon(Icons.add_link), findsOneWidget);
    });

    testWidgets('unlinked mention shows context text', (tester) async {
      final sourceNote = Note(
        title: 'Context Note',
        filePath: 'context.md',
        content: 'Referencing Missing Target in this paragraph',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeProvider.overrideWith(
              () => _TestKnowledgeNotifier(
                notes: [sourceNote],
                activeNoteId: sourceNote.id,
                links: [],
                unlinkedMentions: [
                  UnlinkedMentionResult(
                    sourceNoteId: sourceNote.id,
                    targetTitle: 'Missing Target',
                    context: 'Referencing Missing Target in this paragraph',
                    position: 12,
                  ),
                ],
              ),
            ),
            linkServiceProvider.overrideWith(
              () => _TestLinkNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BacklinksPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Referencing Missing Target in this paragraph'),
        findsOneWidget,
      );
    });
  });
}

void _noop() {}

class _TestKnowledgeNotifier extends KnowledgeNotifier {
  final List<Note> _notes;
  final String? _activeNoteId;
  final List<Link> _links;
  final List<UnlinkedMentionResult>? _unlinkedMentions;

  _TestKnowledgeNotifier({
    List<Note>? notes,
    String? activeNoteId,
    List<Link>? links,
    List<UnlinkedMentionResult>? unlinkedMentions,
  })  : _notes = notes ?? [],
        _activeNoteId = activeNoteId,
        _links = links ?? [],
        _unlinkedMentions = unlinkedMentions;

  @override
  KnowledgeState build() => KnowledgeState(
        notes: _notes,
        activeNoteId: _activeNoteId,
        links: _links,
      );

  @override
  List<UnlinkedMentionResult> getUnlinkedMentions(String noteId) =>
      _unlinkedMentions ?? [];
}

class _TestLinkNotifier extends LinkNotifier {
  @override
  LinkState build() => const LinkState();
}
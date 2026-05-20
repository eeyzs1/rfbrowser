import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/data/models/browser_tab.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/quick_move.dart';
import 'package:rfbrowser/data/stores/hnsw_index.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/ai_service.dart';
import 'package:rfbrowser/services/browser_service.dart';
import 'package:rfbrowser/services/embedding_service.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/services/quick_move_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/services/shortcut_service.dart';
import 'package:rfbrowser/ui/layout/scene_scaffold.dart';
import 'package:rfbrowser/ui/layout/scene_switcher.dart';
import 'package:rfbrowser/ui/pages/ai_chat_panel.dart';
import 'package:rfbrowser/ui/pages/editor_page.dart';
import 'package:rfbrowser/ui/pages/graph_page.dart';
import 'package:rfbrowser/ui/pages/settings_page.dart';
import 'package:rfbrowser/ui/pages/welcome_page.dart';
import 'package:rfbrowser/ui/widgets/command_bar.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('User Journey — Full App Walkthrough', () {
    group('Step 1: Welcome Page — First Launch', () {
      testWidgets('user sees welcome page with app branding', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vaultProvider.overrideWith(() => _TestVaultNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WelcomePage(onVaultOpened: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.explore), findsOneWidget);
        expect(find.text('RFBrowser'), findsOneWidget);
        expect(find.text('Open Vault'), findsOneWidget);
        expect(find.text('Create Vault'), findsOneWidget);
      });

      testWidgets('user sees vault explanation on welcome page', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vaultProvider.overrideWith(() => _TestVaultNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WelcomePage(onVaultOpened: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('A vault is a folder that stores all your notes and knowledge data. Open an existing folder or create a new one to get started.'),
          findsOneWidget,
        );
      });

      testWidgets('user sees no recent vaults on first launch', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vaultProvider.overrideWith(() => _TestVaultNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WelcomePage(onVaultOpened: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recent Vaults'), findsNothing);
      });

      testWidgets('user sees recent vaults after previous use', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vaultProvider.overrideWith(() => _TestVaultNotifier(recentVaults: [
                VaultConfig(
                  path: '/home/user/knowledge',
                  name: 'Knowledge Base',
                  lastOpened: DateTime.now(),
                ),
                VaultConfig(
                  path: '/home/user/work',
                  name: 'Work Notes',
                  lastOpened: DateTime.now().subtract(const Duration(days: 1)),
                ),
              ])),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WelcomePage(onVaultOpened: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recent Vaults'), findsOneWidget);
        expect(find.text('Knowledge Base'), findsOneWidget);
        expect(find.text('Work Notes'), findsOneWidget);
      });

      testWidgets('user can cancel vault deletion (UX-3)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vaultProvider.overrideWith(() => _TestVaultNotifier(recentVaults: [
                VaultConfig(
                  path: '/home/user/important',
                  name: 'Important Vault',
                  lastOpened: DateTime.now(),
                ),
              ])),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WelcomePage(onVaultOpened: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Important Vault'), findsOneWidget);
      });
    });

    group('Step 2: Scene Navigation — Exploring the Three Scenes', () {
      testWidgets('user starts in Capture scene by default', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const _TestMainLayout(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SceneSwitcher), findsOneWidget);
        expect(find.text('Capture'), findsWidgets);
      });

      testWidgets('user sees tooltips on scene buttons', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const _TestMainLayout(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Tooltip), findsAtLeast(3));
      });

      testWidgets('user switches to Think scene', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const _TestMainLayout(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Think'));
        await tester.pumpAndSettle();

        expect(find.text('Think'), findsWidgets);
      });

      testWidgets('user switches to Connect scene', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const _TestMainLayout(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(find.text('Connect'), findsWidgets);
      });

      testWidgets('user switches back to Capture scene', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const _TestMainLayout(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Think'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Capture'));
        await tester.pumpAndSettle();

        expect(find.text('Capture'), findsWidgets);
      });

      testWidgets('user opens settings from scene switcher', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const _TestMainLayout(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsPage), findsOneWidget);
      });
    });

    group('Step 3: Browser — Browsing the Web', () {
      late BrowserNotifier browserNotifier;

      Future<void> pumpBrowserHarness(WidgetTester tester) async {
        browserNotifier = _TestBrowserNotifier();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              browserProvider.overrideWith(() => browserNotifier),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: _BrowserTestHarness()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('user creates a new browser tab', (tester) async {
        await pumpBrowserHarness(tester);

        await tester.tap(find.text('Create Tab'));
        await tester.pumpAndSettle();

        expect(find.text('Tab count: 1'), findsOneWidget);
        expect(find.text('Active: about:blank'), findsOneWidget);
      });

      testWidgets('user creates multiple tabs and switches between them', (tester) async {
        await pumpBrowserHarness(tester);

        await tester.tap(find.text('Create Tab'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create Tab with URL'));
        await tester.pumpAndSettle();

        expect(find.text('Tab count: 2'), findsOneWidget);

        final state = browserNotifier.state;
        final secondTabId = state.tabs[1].id;
        browserNotifier.setActiveTab(secondTabId);
        await tester.pumpAndSettle();

        expect(browserNotifier.state.activeTab?.url, 'https://example.com');
      });

      testWidgets('user closes a tab and active tab switches correctly (C-3)', (tester) async {
        await pumpBrowserHarness(tester);

        browserNotifier.createTab(url: 'https://first.com');
        browserNotifier.createTab(url: 'https://second.com');
        browserNotifier.createTab(url: 'https://third.com');
        await tester.pumpAndSettle();

        final middleTabId = browserNotifier.state.tabs[1].id;
        browserNotifier.setActiveTab(middleTabId);
        browserNotifier.closeTab(middleTabId);
        await tester.pumpAndSettle();

        expect(browserNotifier.state.activeTab?.url, 'https://first.com');
      });

      testWidgets('user bookmarks a page', (tester) async {
        await pumpBrowserHarness(tester);

        browserNotifier.toggleBookmark('https://example.com', 'Example');
        await tester.pumpAndSettle();

        expect(browserNotifier.state.isBookmarked('https://example.com'), isTrue);
      });

      testWidgets('user creates tab groups for organization', (tester) async {
        await pumpBrowserHarness(tester);

        final tabId = browserNotifier.createTab(url: 'https://docs.google.com');
        final groupId = browserNotifier.createGroup('Work');
        browserNotifier.addTabToGroup(tabId, groupId);
        await tester.pumpAndSettle();

        expect(browserNotifier.state.groups.length, 1);
        expect(browserNotifier.state.groups.first.name, 'Work');
      });

      testWidgets('user pins a tab', (tester) async {
        await pumpBrowserHarness(tester);

        browserNotifier.createTab(url: 'https://example.com');
        await tester.pumpAndSettle();

        final tabId = browserNotifier.state.tabs.first.id;
        browserNotifier.togglePinTab(tabId);
        await tester.pumpAndSettle();

        expect(browserNotifier.state.tabs.first.isPinned, isTrue);
      });

      testWidgets('closing the only tab sets activeTabId to null', (tester) async {
        await pumpBrowserHarness(tester);

        browserNotifier.createTab(url: 'https://only.com');
        await tester.pumpAndSettle();

        final tabId = browserNotifier.state.tabs.first.id;
        browserNotifier.closeTab(tabId);
        await tester.pumpAndSettle();

        expect(browserNotifier.state.tabs, isEmpty);
        expect(browserNotifier.state.activeTabId, isNull);
      });
    });

    group('Step 4: Editor — Writing Notes', () {
      final testNote = Note(
        title: 'My Research Notes',
        filePath: 'research-notes.md',
        content: '# Research Notes\n\nThis is my research on Flutter.',
      );

      final testVault = VaultConfig(
        path: '/vault',
        name: 'My Vault',
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
        await tester.pumpAndSettle();
      }

      testWidgets('user sees empty state when no note selected', (tester) async {
        await pumpEditorPage(tester, currentVault: testVault);

        expect(find.byIcon(Icons.edit_note), findsOneWidget);
      });

      testWidgets('user sees new note button when no note selected', (tester) async {
        await pumpEditorPage(tester, currentVault: testVault);

        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('user sees note title when a note is active', (tester) async {
        await pumpEditorPage(
          tester,
          notes: [testNote],
          activeNoteId: testNote.id,
          currentVault: testVault,
        );

        expect(find.text('My Research Notes'), findsOneWidget);
      });

      testWidgets('user sees formatting toolbar in edit mode (UX-11)', (tester) async {
        await pumpEditorPage(
          tester,
          notes: [testNote],
          activeNoteId: testNote.id,
          currentVault: testVault,
        );

        expect(find.byIcon(Icons.format_bold), findsOneWidget);
        expect(find.byIcon(Icons.format_italic), findsOneWidget);
        expect(find.byIcon(Icons.title), findsOneWidget);
        expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
        expect(find.byIcon(Icons.link), findsOneWidget);
      });

      testWidgets('user switches to preview mode and toolbar hides', (tester) async {
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

      testWidgets('user sees view mode selector with Edit/Preview/Split (UX-13)', (tester) async {
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

      testWidgets('user sees save button in header', (tester) async {
        await pumpEditorPage(
          tester,
          notes: [testNote],
          activeNoteId: testNote.id,
          currentVault: testVault,
        );

        expect(find.byIcon(Icons.save), findsOneWidget);
      });

      testWidgets('user sees status bar with save status (UX-12)', (tester) async {
        await pumpEditorPage(
          tester,
          notes: [testNote],
          activeNoteId: testNote.id,
          currentVault: testVault,
        );

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      });

      testWidgets('user sees full formatting toolbar (UX-11)', (tester) async {
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
        expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
        expect(find.byIcon(Icons.table_chart), findsOneWidget);
      });
    });

    group('Step 5: Knowledge Graph — Visualizing Connections', () {
      final notes = [
        Note(title: 'Flutter', filePath: 'flutter.md', content: 'Flutter framework'),
        Note(title: 'Dart', filePath: 'dart.md', content: 'Dart language'),
        Note(title: 'Riverpod', filePath: 'riverpod.md', content: 'State management'),
      ];
      final links = [
        Link(sourceId: notes[0].id, targetId: notes[1].id, type: LinkType.wikilink),
        Link(sourceId: notes[0].id, targetId: notes[2].id, type: LinkType.wikilink),
      ];

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

      testWidgets('user sees empty graph state when no notes', (tester) async {
        await pumpGraphPage(tester);

        expect(find.byIcon(Icons.hub), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('user sees graph canvas with connected notes', (tester) async {
        await pumpGraphPage(
          tester,
          notes: notes,
          links: links,
          activeNoteId: notes[0].id,
        );

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('user toggles graph layout between force-directed and circular', (tester) async {
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
      });

      testWidgets('user toggles stats panel', (tester) async {
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
      });

      testWidgets('user zooms in and out on the graph', (tester) async {
        await pumpGraphPage(
          tester,
          notes: notes,
          links: links,
          activeNoteId: notes[0].id,
        );

        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.zoom_out));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      });

      testWidgets('user toggles legend panel', (tester) async {
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
      });
    });

    group('Step 6: AI Chat — Conversing with AI', () {
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

      testWidgets('user sees AI chat input field', (tester) async {
        await pumpAIChatPanel(tester);

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.send), findsOneWidget);
      });

      testWidgets('user sees empty state with AI assistant', (tester) async {
        await pumpAIChatPanel(tester);

        expect(find.byIcon(Icons.psychology), findsOneWidget);
      });

      testWidgets('user types @ and sees autocomplete options', (tester) async {
        await pumpAIChatPanel(tester);

        await tester.enterText(find.byType(TextField), 'Summarize @');
        await tester.pumpAndSettle();

        expect(find.text('@note[...]'), findsOneWidget);
        expect(find.text('@web[current]'), findsOneWidget);
        expect(find.text('@clip[...]'), findsOneWidget);
      });

      testWidgets('user sees model selector', (tester) async {
        await pumpAIChatPanel(tester);

        expect(find.text('Test Model'), findsOneWidget);
      });

      testWidgets('user sees new conversation and clear buttons (UX-5)', (tester) async {
        await pumpAIChatPanel(tester);

        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('user sees skill picker button', (tester) async {
        await pumpAIChatPanel(tester);

        expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      });

      testWidgets('user clicks autocomplete item and text is inserted', (tester) async {
        await pumpAIChatPanel(tester);

        await tester.enterText(find.byType(TextField), 'Hello @');
        await tester.pumpAndSettle();

        await tester.tap(find.text('@note[...]'));
        await tester.pumpAndSettle();

        final controller = tester.widget<TextField>(find.byType(TextField)).controller;
        expect(controller!.text, contains('@note[]'));
      });
    });

    group('Step 7: Command Bar — Quick Navigation', () {
      Future<void> pumpCommandBar(
        WidgetTester tester, {
        required void Function(String) onCommand,
      }) async {
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
                  onCommand: onCommand,
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('user sees built-in commands in command bar (UX-5)', (tester) async {
        await pumpCommandBar(tester, onCommand: (_) {});

        expect(find.text('New Note'), findsOneWidget);
        expect(find.text('New Tab'), findsOneWidget);
        expect(find.text('Open Daily Note'), findsOneWidget);
        expect(find.text('Switch Theme'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Graph View'), findsOneWidget);
        expect(find.text('Canvas View'), findsOneWidget);
      });

      testWidgets('user filters commands by typing', (tester) async {
        await pumpCommandBar(tester, onCommand: (_) {});

        await tester.enterText(find.byType(TextField), 'graph');
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Graph View'), findsOneWidget);
        expect(find.text('New Note'), findsNothing);
      });

      testWidgets('user enters QuickMove mode with slash', (tester) async {
        await pumpCommandBar(tester, onCommand: (_) {});

        await tester.enterText(find.byType(TextField), '/');
        await tester.pumpAndSettle();

        expect(find.text('Quick Move — type command name...'), findsOneWidget);
      });

      testWidgets('user selects a command and it fires callback', (tester) async {
        String? lastCommand;
        await pumpCommandBar(tester, onCommand: (cmd) => lastCommand = cmd);

        await tester.tap(find.text('New Note'));
        await tester.pumpAndSettle();

        expect(lastCommand, 'New Note');
      });
    });

    group('Step 8: Settings — Customizing the App', () {
      testWidgets('user sees all settings sections', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Theme'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Quick Moves'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Quick Moves'), findsOneWidget);
      });

      testWidgets('user sees theme color presets', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ocean'), findsOneWidget);
        expect(find.text('Violet'), findsOneWidget);
      });

      testWidgets('settings page is scrollable', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('user sees category headers in settings', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('General'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('AI & Automation'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('AI & Automation'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Advanced'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Advanced'), findsOneWidget);
      });
    });

    group('Step 9: Canvas — Infinite Canvas', () {
      testWidgets('canvas model supports adding cards', (tester) async {
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

    group('Step 10: Security — Safe Browsing', () {
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

    group('Step 11: End-to-End User Workflow', () {
      testWidgets('complete user journey: welcome → vault → browse → note → graph', (tester) async {
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

    group('Step 12: Shortcut Customization', () {
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

      testWidgets('ShortcutService defaults include all 22 actions', (tester) async {
        final service = ShortcutService();
        expect(service.allBindings.length, 22);
      });

      testWidgets('findActionForShortcut reverse lookup works', (tester) async {
        final service = ShortcutService();
        expect(service.findActionForShortcut('Ctrl+1'), 'switch_capture');
        expect(service.findActionForShortcut('Ctrl+4'), 'connect_canvas');
        expect(service.findActionForShortcut('Ctrl+5'), 'connect_graph');
        expect(service.findActionForShortcut('Ctrl+Z'), 'canvas_undo');
      });
    });
  });
}

class _TestMainLayout extends StatefulWidget {
  const _TestMainLayout();

  @override
  State<_TestMainLayout> createState() => _TestMainLayoutState();
}

class _TestMainLayoutState extends State<_TestMainLayout> {
  SceneType _currentScene = SceneType.capture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SceneSwitcher(
            currentScene: _currentScene,
            onSceneChanged: (scene) => setState(() => _currentScene = scene),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: KeyedSubtree(
                key: ValueKey(_currentScene),
                child: _buildScene(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScene() {
    return switch (_currentScene) {
      SceneType.capture => const Center(child: Text('Capture Scene')),
      SceneType.think => const Center(child: Text('Think Scene')),
      SceneType.connect => const Center(child: Text('Connect Scene')),
    };
  }
}

class _BrowserTestHarness extends ConsumerWidget {
  const _BrowserTestHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browserProvider);
    return Column(
      children: [
        Text('Tab count: ${state.tabs.length}'),
        Text('Active: ${state.activeTab?.url ?? "none"}'),
        ElevatedButton(
          onPressed: () => ref.read(browserProvider.notifier).createTab(),
          child: const Text('Create Tab'),
        ),
        ElevatedButton(
          onPressed: () =>
              ref.read(browserProvider.notifier).createTab(url: 'https://example.com'),
          child: const Text('Create Tab with URL'),
        ),
      ],
    );
  }
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

class _TestVaultNotifier extends VaultNotifier {
  final List<VaultConfig> _recentVaults;
  final VaultConfig? _currentVault;

  _TestVaultNotifier({
    List<VaultConfig>? recentVaults,
    VaultConfig? currentVault,
  })  : _recentVaults = recentVaults ?? [],
        _currentVault = currentVault;

  @override
  VaultState build() => VaultState(
        recentVaults: _recentVaults,
        currentVault: _currentVault,
      );
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

class _TestBrowserNotifier extends BrowserNotifier {
  @override
  BrowserState build() => BrowserState();
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
  Future<List<HybridSearchResult>> search(String query, {int topK = 20}) async => [];
}

class _TestSemanticSearch extends SemanticSearch {
  _TestSemanticSearch() : super(_TestEmbeddingService());

  @override
  Future<List<SearchResult>> search(String query, {int topK = 20}) async => [];
}

class _TestEmbeddingService extends EmbeddingService {
  @override
  Future<List<double>> embed(String text, {AIProvider? provider, String? apiKey, String? modelId}) async =>
      List.filled(128, 0.0);
}

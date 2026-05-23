import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/services/browser_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Browser Tab Management', () {
    late BrowserNotifier browserNotifier;

    Future<void> pumpBrowserHarness(WidgetTester tester) async {
      browserNotifier = _TestBrowserNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [browserProvider.overrideWith(() => browserNotifier)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: _BrowserTestHarness()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('createTab adds a new tab and sets it active', (tester) async {
      await pumpBrowserHarness(tester);

      await tester.tap(find.text('Create Tab'));
      await tester.pumpAndSettle();

      expect(find.text('Tab count: 1'), findsOneWidget);
      expect(find.text('Active: about:blank'), findsOneWidget);
    });

    testWidgets('createTab with URL sets correct URL', (tester) async {
      await pumpBrowserHarness(tester);

      await tester.tap(find.text('Create Tab with URL'));
      await tester.pumpAndSettle();

      expect(find.text('Tab count: 1'), findsOneWidget);
      expect(find.text('Active: https://example.com'), findsOneWidget);
    });

    testWidgets('closeTab updates activeTabId correctly (C-3)', (tester) async {
      await pumpBrowserHarness(tester);

      await tester.tap(find.text('Create Tab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Tab with URL'));
      await tester.pumpAndSettle();

      expect(find.text('Tab count: 2'), findsOneWidget);

      final state = browserNotifier.state;
      final firstTabId = state.tabs.first.id;

      browserNotifier.closeTab(firstTabId);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.tabs.length, equals(1));
      expect(browserNotifier.state.activeTabId, isNotNull);
      expect(
        browserNotifier.state.activeTab!.url,
        equals('https://example.com'),
      );
    });

    testWidgets('closing the only tab sets activeTabId to null', (
      tester,
    ) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://only.com');
      await tester.pumpAndSettle();

      final tabId = browserNotifier.state.tabs.first.id;
      browserNotifier.closeTab(tabId);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.tabs, isEmpty);
      expect(browserNotifier.state.activeTabId, isNull);
    });

    testWidgets('closing active first tab activates previous index (C-3)', (
      tester,
    ) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://first.com');
      browserNotifier.createTab(url: 'https://second.com');
      browserNotifier.createTab(url: 'https://third.com');
      await tester.pumpAndSettle();

      final firstTabId = browserNotifier.state.tabs[0].id;
      browserNotifier.setActiveTab(firstTabId);
      await tester.pumpAndSettle();

      browserNotifier.closeTab(firstTabId);
      await tester.pumpAndSettle();

      expect(
        browserNotifier.state.activeTab!.url,
        equals('https://second.com'),
      );
    });

    testWidgets('closing active middle tab activates previous tab (C-3)', (
      tester,
    ) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://first.com');
      browserNotifier.createTab(url: 'https://second.com');
      browserNotifier.createTab(url: 'https://third.com');
      await tester.pumpAndSettle();

      final middleTabId = browserNotifier.state.tabs[1].id;
      browserNotifier.setActiveTab(middleTabId);
      browserNotifier.closeTab(middleTabId);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.activeTab!.url, equals('https://first.com'));
    });

    testWidgets('closing non-active tab keeps current active', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://first.com');
      browserNotifier.createTab(url: 'https://second.com');
      browserNotifier.createTab(url: 'https://third.com');
      await tester.pumpAndSettle();

      final firstTabId = browserNotifier.state.tabs[0].id;
      browserNotifier.closeTab(firstTabId);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.activeTab!.url, equals('https://third.com'));
    });

    testWidgets('setActiveTab marks correct tab as active', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://first.com');
      browserNotifier.createTab(url: 'https://second.com');
      await tester.pumpAndSettle();

      final firstTabId = browserNotifier.state.tabs[0].id;
      browserNotifier.setActiveTab(firstTabId);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.activeTabId, equals(firstTabId));
      expect(browserNotifier.state.activeTab!.url, equals('https://first.com'));
    });

    testWidgets('updateTabUrl changes tab URL', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://old.com');
      await tester.pumpAndSettle();

      final tabId = browserNotifier.state.tabs.first.id;
      browserNotifier.updateTabUrl(tabId, 'https://new.com');
      await tester.pumpAndSettle();

      expect(browserNotifier.state.tabs.first.url, equals('https://new.com'));
    });

    testWidgets('updateTabTitle changes tab title', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://example.com');
      await tester.pumpAndSettle();

      final tabId = browserNotifier.state.tabs.first.id;
      browserNotifier.updateTabTitle(tabId, 'Example Site');
      await tester.pumpAndSettle();

      expect(browserNotifier.state.tabs.first.title, equals('Example Site'));
    });

    testWidgets('togglePinTab toggles pinned state', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://example.com');
      await tester.pumpAndSettle();

      final tabId = browserNotifier.state.tabs.first.id;
      expect(browserNotifier.state.tabs.first.isPinned, isFalse);

      browserNotifier.togglePinTab(tabId);
      await tester.pumpAndSettle();
      expect(browserNotifier.state.tabs.first.isPinned, isTrue);

      browserNotifier.togglePinTab(tabId);
      await tester.pumpAndSettle();
      expect(browserNotifier.state.tabs.first.isPinned, isFalse);
    });

    testWidgets('reorderTab changes tab order', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://first.com');
      browserNotifier.createTab(url: 'https://second.com');
      await tester.pumpAndSettle();

      browserNotifier.reorderTab(0, 1);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.tabs[0].url, equals('https://second.com'));
      expect(browserNotifier.state.tabs[1].url, equals('https://first.com'));
    });

    testWidgets('toggleBookmark adds and removes bookmark', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.toggleBookmark('https://example.com', 'Example');
      await tester.pumpAndSettle();
      expect(browserNotifier.state.isBookmarked('https://example.com'), isTrue);

      browserNotifier.toggleBookmark('https://example.com', 'Example');
      await tester.pumpAndSettle();
      expect(
        browserNotifier.state.isBookmarked('https://example.com'),
        isFalse,
      );
    });

    testWidgets('createGroup adds a tab group', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createGroup('Work');
      await tester.pumpAndSettle();

      expect(browserNotifier.state.groups.length, equals(1));
      expect(browserNotifier.state.groups.first.name, equals('Work'));
    });

    testWidgets('addTabToGroup and removeTabFromGroup', (tester) async {
      await pumpBrowserHarness(tester);

      final tabId = browserNotifier.createTab(url: 'https://example.com');
      final groupId = browserNotifier.createGroup('Work');
      browserNotifier.addTabToGroup(tabId, groupId);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.tabs.first.groupId, equals(groupId));
      expect(browserNotifier.state.groups.first.tabIds, contains(tabId));

      browserNotifier.removeTabFromGroup(tabId);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.tabs.first.groupId, isNull);
      expect(browserNotifier.state.groups.first.tabIds, isNot(contains(tabId)));
    });

    testWidgets('canAutoGroup returns true with 3+ tabs', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://a.com');
      browserNotifier.createTab(url: 'https://b.com');
      expect(browserNotifier.canAutoGroup(), isFalse);

      browserNotifier.createTab(url: 'https://c.com');
      expect(browserNotifier.canAutoGroup(), isTrue);
    });

    testWidgets('generateGroupProposal groups by domain', (tester) async {
      await pumpBrowserHarness(tester);

      browserNotifier.createTab(url: 'https://docs.google.com/a');
      browserNotifier.createTab(url: 'https://docs.google.com/b');
      browserNotifier.createTab(url: 'https://github.com/c');
      await tester.pumpAndSettle();

      final proposal = browserNotifier.generateGroupProposal({});
      final groupedNames = proposal.groups.map((g) => g.name).toList();
      expect(groupedNames, contains('google.com'));
    });

    testWidgets('ungroupedTabs returns tabs without group', (tester) async {
      await pumpBrowserHarness(tester);

      final tabId1 = browserNotifier.createTab(url: 'https://a.com');
      browserNotifier.createTab(url: 'https://b.com');
      final groupId = browserNotifier.createGroup('Work');
      browserNotifier.addTabToGroup(tabId1, groupId);
      await tester.pumpAndSettle();

      expect(browserNotifier.state.ungroupedTabs.length, equals(1));
      expect(
        browserNotifier.state.ungroupedTabs.first.url,
        equals('https://b.com'),
      );
    });
  });
}

class _TestBrowserNotifier extends BrowserNotifier {
  @override
  BrowserState build() => BrowserState();
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
          onPressed: () => ref
              .read(browserProvider.notifier)
              .createTab(url: 'https://example.com'),
          child: const Text('Create Tab with URL'),
        ),
      ],
    );
  }
}

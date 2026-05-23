import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/services/browser_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:rfbrowser/data/models/browser_tab.dart';
import 'package:rfbrowser/ui/widgets/browser/browser_bookmark_button.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BrowserBookmarkButton', () {
    final testTab = BrowserTab(
      id: 'tab-1',
      url: 'https://example.com',
      title: 'Example',
    );

    testWidgets('shows unbookmarked icon when page is not bookmarked', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserProvider.overrideWith(
              () => _TestBrowserNotifier(bookmarks: []),
            ),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return BrowserBookmarkButton(
                    activeTab: testTab,
                    l: l,
                    onAddBookmark: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNothing);
    });

    testWidgets('shows bookmarked icon when page is bookmarked', (
      tester,
    ) async {
      final bookmark = Bookmark(
        id: 'bm1',
        url: 'https://example.com',
        title: 'Example',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserProvider.overrideWith(
              () => _TestBrowserNotifier(bookmarks: [bookmark]),
            ),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return BrowserBookmarkButton(
                    activeTab: testTab,
                    l: l,
                    onAddBookmark: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_outlined), findsNothing);
    });

    testWidgets(
      'triggers onAddBookmark callback when unbookmarked page tapped',
      (tester) async {
        bool wasCalled = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              browserProvider.overrideWith(
                () => _TestBrowserNotifier(bookmarks: []),
              ),
              settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    final l = AppLocalizations.of(context)!;
                    return BrowserBookmarkButton(
                      activeTab: testTab,
                      l: l,
                      onAddBookmark: () => wasCalled = true,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(wasCalled, isTrue);
      },
    );

    testWidgets('removes bookmark when already bookmarked page tapped', (
      tester,
    ) async {
      final bookmark = Bookmark(
        id: 'bm1',
        url: 'https://example.com',
        title: 'Example',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserProvider.overrideWith(
              () => _TestBrowserNotifier(bookmarks: [bookmark]),
            ),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return BrowserBookmarkButton(
                    activeTab: testTab,
                    l: l,
                    onAddBookmark: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNothing);
    });

    testWidgets('shows AnimatedSwitcher for icon transition', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserProvider.overrideWith(
              () => _TestBrowserNotifier(bookmarks: []),
            ),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return BrowserBookmarkButton(
                    activeTab: testTab,
                    l: l,
                    onAddBookmark: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });

    testWidgets('only matches exact URL for bookmark state', (tester) async {
      final bookmark = Bookmark(
        id: 'bm1',
        url: 'https://other.com',
        title: 'Other',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserProvider.overrideWith(
              () => _TestBrowserNotifier(bookmarks: [bookmark]),
            ),
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return BrowserBookmarkButton(
                    activeTab: testTab,
                    l: l,
                    onAddBookmark: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNothing);
    });
  });

  group('BrowserNotifier Bookmark Operations', () {
    testWidgets('addBookmark adds to bookmarks list', (tester) async {
      final container = ProviderContainer(
        overrides: [
          browserProvider.overrideWith(
            () => _TestBrowserNotifier(bookmarks: []),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(browserProvider.notifier);

      notifier.addBookmark('https://new.com', 'New Page', 'bookmarks-bar');
      expect(container.read(browserProvider).bookmarks.length, 1);
      expect(
        container.read(browserProvider).bookmarks.first.url,
        'https://new.com',
      );
    });

    testWidgets('removeBookmark removes from bookmarks list', (tester) async {
      final bookmark = Bookmark(
        id: 'bm1',
        url: 'https://example.com',
        title: 'Example',
      );

      final container = ProviderContainer(
        overrides: [
          browserProvider.overrideWith(
            () => _TestBrowserNotifier(bookmarks: [bookmark]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(browserProvider.notifier);

      notifier.removeBookmark('bm1');
      expect(container.read(browserProvider).bookmarks.length, 0);
    });

    testWidgets('toggleBookmark adds then removes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          browserProvider.overrideWith(
            () => _TestBrowserNotifier(bookmarks: []),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(browserProvider.notifier);

      notifier.toggleBookmark('https://example.com', 'Example');
      expect(container.read(browserProvider).bookmarks.length, 1);

      notifier.toggleBookmark('https://example.com', 'Example');
      expect(container.read(browserProvider).bookmarks.length, 0);
    });

    testWidgets('isBookmarked returns true for matching URL', (tester) async {
      final bookmark = Bookmark(
        id: 'bm1',
        url: 'https://example.com',
        title: 'Example',
      );

      final container = ProviderContainer(
        overrides: [
          browserProvider.overrideWith(
            () => _TestBrowserNotifier(bookmarks: [bookmark]),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(browserProvider).isBookmarked('https://example.com'),
        isTrue,
      );
      expect(
        container.read(browserProvider).isBookmarked('https://other.com'),
        isFalse,
      );
    });

    testWidgets('createBookmarkFolder creates a new folder', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(browserProvider.notifier);

      notifier.createBookmarkFolder('Test Folder');
      expect(container.read(browserProvider).bookmarkFolders.length, 2);
      expect(
        container.read(browserProvider).bookmarkFolders.last.name,
        'Test Folder',
      );
    });

    testWidgets('deleteBookmarkFolder removes folder', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(browserProvider.notifier);

      notifier.createBookmarkFolder('To Delete');
      final folderId = container.read(browserProvider).bookmarkFolders.last.id;

      notifier.deleteBookmarkFolder(folderId);
      expect(container.read(browserProvider).bookmarkFolders.length, 1);
    });
  });

  group('Bookmark model', () {
    testWidgets('Bookmark toJson and fromJson roundtrip', (tester) async {
      final bookmark = Bookmark(
        id: 'bm-1',
        url: 'https://flutter.dev',
        title: 'Flutter',
        folderId: 'bookmarks-bar',
      );

      final json = bookmark.toJson();
      final restored = Bookmark.fromJson(json);

      expect(restored.id, bookmark.id);
      expect(restored.url, bookmark.url);
      expect(restored.title, bookmark.title);
      expect(restored.folderId, bookmark.folderId);
    });

    testWidgets('BookmarkFolder toJson and fromJson roundtrip', (tester) async {
      final folder = BookmarkFolder(
        id: 'folder-1',
        name: 'Dev',
        parentId: 'bookmarks-bar',
      );

      final json = folder.toJson();
      final restored = BookmarkFolder.fromJson(json);

      expect(restored.id, folder.id);
      expect(restored.name, folder.name);
      expect(restored.parentId, folder.parentId);
    });

    testWidgets('BookmarkFolder default constructor creates root folder', (
      tester,
    ) async {
      final folder = BookmarkFolder(name: '收藏夹栏');

      expect(folder.parentId, isEmpty);
    });
  });
}

class _TestBrowserNotifier extends BrowserNotifier {
  final List<Bookmark> _bookmarks;

  _TestBrowserNotifier({List<Bookmark>? bookmarks})
    : _bookmarks = bookmarks ?? [];

  @override
  BrowserState build() => BrowserState(bookmarks: _bookmarks);

  @override
  void addBookmark(String url, String title, String folderId) {
    state = state.copyWith(
      bookmarks: [
        ...state.bookmarks,
        Bookmark(id: 'new', url: url, title: title, folderId: folderId),
      ],
    );
  }

  @override
  void removeBookmark(String id) {
    state = state.copyWith(
      bookmarks: state.bookmarks.where((b) => b.id != id).toList(),
    );
  }

  @override
  void toggleBookmark(String url, String title) {
    if (state.isBookmarked(url)) {
      removeBookmark(state.bookmarks.firstWhere((b) => b.url == url).id);
    } else {
      addBookmark(url, title, 'bookmarks-bar');
    }
  }
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

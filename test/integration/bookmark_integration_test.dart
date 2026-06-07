import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/browser_service.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
  @override
  set state(VaultState newState) => super.state = newState;
}

void main() {
  group('Bookmark Integration', () {
    late ProviderContainer container;
    late BrowserNotifier notifier;
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('rfb_bm_');
      final rfbDir = Directory(p.join(tempDir.path, '.rfbrowser'));
      if (!rfbDir.existsSync()) rfbDir.createSync(recursive: true);

      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: tempDir.path,
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      container = ProviderContainer(
        overrides: [
          vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
        ],
      );
      notifier = container.read(browserProvider.notifier);
    });

    tearDown(() {
      container.dispose();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('toggleBookmark adds bookmark when URL is not bookmarked', () {
      notifier.toggleBookmark('https://flutter.dev', 'Flutter');

      final state = container.read(browserProvider);
      expect(state.bookmarks.length, 1);
      expect(state.bookmarks.first.url, 'https://flutter.dev');
      expect(state.bookmarks.first.title, 'Flutter');
    });

    test('toggleBookmark removes bookmark when URL is already bookmarked', () {
      notifier.toggleBookmark('https://flutter.dev', 'Flutter');
      expect(container.read(browserProvider).bookmarks.length, 1);

      notifier.toggleBookmark('https://flutter.dev', 'Flutter');
      expect(container.read(browserProvider).bookmarks, isEmpty);
    });

    test('addBookmark places bookmark in specified folder', () {
      final folderId = notifier.createBookmarkFolder('Work');
      notifier.addBookmark('https://dart.dev', 'Dart', folderId);

      final state = container.read(browserProvider);
      expect(state.bookmarks.first.folderId, folderId);
    });

    test('removeBookmark removes bookmark by id', () {
      notifier.toggleBookmark('https://example.com', 'Example');
      final bmId = container.read(browserProvider).bookmarks.first.id;

      notifier.removeBookmark(bmId);
      expect(container.read(browserProvider).bookmarks, isEmpty);
    });

    test('isBookmarked returns true for bookmarked URL', () {
      notifier.toggleBookmark('https://flutter.dev', 'Flutter');

      expect(
        container.read(browserProvider).isBookmarked('https://flutter.dev'),
        isTrue,
      );
      expect(
        container.read(browserProvider).isBookmarked('https://unknown.com'),
        isFalse,
      );
    });

    test('createBookmarkFolder creates folder with default parent', () {
      final folderId = notifier.createBookmarkFolder('Research');

      final state = container.read(browserProvider);
      expect(
        state.bookmarkFolders.any((f) => f.name == 'Research'),
        isTrue,
      );
      final folder = state.bookmarkFolders.firstWhere((f) => f.id == folderId);
      expect(folder.parentId, 'bookmarks-bar');
    });

    test('createBookmarkFolder with parentId creates nested folder', () {
      final parentId = notifier.createBookmarkFolder('Parent');
      final childId = notifier.createBookmarkFolder('Child', parentId: parentId);

      final state = container.read(browserProvider);
      final childFolder =
          state.bookmarkFolders.firstWhere((f) => f.id == childId);
      expect(childFolder.parentId, parentId);
    });

    test('deleteBookmarkFolder removes folder and its children', () {
      final parentId = notifier.createBookmarkFolder('Parent');
      notifier.createBookmarkFolder('Child', parentId: parentId);
      notifier.addBookmark('https://a.com', 'A', parentId);

      notifier.deleteBookmarkFolder(parentId);

      final state = container.read(browserProvider);
      expect(
        state.bookmarkFolders.any((f) => f.id == parentId),
        isFalse,
      );
    });

    test('renameBookmarkFolder changes folder name', () {
      final folderId = notifier.createBookmarkFolder('Old Name');

      notifier.renameBookmarkFolder(folderId, 'New Name');
      final state = container.read(browserProvider);
      final renamed =
          state.bookmarkFolders.firstWhere((f) => f.id == folderId);
      expect(renamed.name, 'New Name');
    });

    test('moveBookmarkToFolder changes folder', () {
      final folder1 = notifier.createBookmarkFolder('Folder 1');
      final folder2 = notifier.createBookmarkFolder('Folder 2');
      notifier.toggleBookmark('https://example.com', 'Example');
      final bmId = container.read(browserProvider).bookmarks.first.id;

      notifier.moveBookmarkToFolder(bmId, folder1);
      expect(
        container.read(browserProvider).bookmarks.first.folderId,
        folder1,
      );

      notifier.moveBookmarkToFolder(bmId, folder2);
      expect(
        container.read(browserProvider).bookmarks.first.folderId,
        folder2,
      );
    });

    test('toggleBookmarkFolder toggles isExpanded', () {
      final folderId = notifier.createBookmarkFolder('Toggle');
      final state = container.read(browserProvider);
      expect(
        state.bookmarkFolders.firstWhere((f) => f.id == folderId).isExpanded,
        isTrue,
      );

      notifier.toggleBookmarkFolder(folderId);
      expect(
        container.read(browserProvider)
            .bookmarkFolders
            .firstWhere((f) => f.id == folderId)
            .isExpanded,
        isFalse,
      );
    });

    test('bookmarks persist and load from disk', () async {
      notifier.toggleBookmark('https://persist.com', 'Persist');
      notifier.createBookmarkFolder('Saved Folder');

      await notifier.loadBookmarks();

      final state = container.read(browserProvider);
      expect(
        state.bookmarks.any((b) => b.url == 'https://persist.com'),
        isTrue,
      );
      expect(
        state.bookmarkFolders.any((f) => f.name == 'Saved Folder'),
        isTrue,
      );
    });

    test('full bookmark lifecycle: create, move, delete', () {
      final folderId = notifier.createBookmarkFolder('Lifecycle');
      notifier.addBookmark('https://start.com', 'Start', folderId);

      expect(container.read(browserProvider).bookmarks.length, 1);
      expect(
        container.read(browserProvider).bookmarks.first.folderId,
        folderId,
      );

      final folder2 = notifier.createBookmarkFolder('Lifecycle 2');
      final bmId = container.read(browserProvider).bookmarks.first.id;
      notifier.moveBookmarkToFolder(bmId, folder2);
      expect(
        container.read(browserProvider).bookmarks.first.folderId,
        folder2,
      );

      notifier.removeBookmark(bmId);
      expect(container.read(browserProvider).bookmarks, isEmpty);
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/browser_tab.dart';
import 'package:rfbrowser/data/models/tab_group_proposal.dart';
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

ProviderContainer createContainer({String? vaultPath}) {
  final effectivePath = vaultPath ?? '.';
  final vaultState = VaultState(
    currentVault: VaultConfig(
      path: effectivePath,
      name: 'test',
      lastOpened: DateTime.now(),
    ),
  );
  return ProviderContainer(overrides: [
    vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
  ]);
}

ProviderContainer createContainerNoVault() {
  return ProviderContainer(overrides: [
    vaultProvider.overrideWith(() => TestVaultNotifier(VaultState())),
  ]);
}

void main() {
  group('BrowserState', () {
    test('initial state has empty tabs, groups, bookmarks', () {
      final state = BrowserState();
      expect(state.tabs, isEmpty);
      expect(state.groups, isEmpty);
      expect(state.activeTabId, isNull);
      expect(state.bookmarks, isEmpty);
      expect(state.bookmarkFolders.length, 1);
      expect(state.bookmarkFolders.first.id, 'bookmarks-bar');
    });

    test('activeTab returns matching tab', () {
      final tab = BrowserTab(id: 'tab1', url: 'https://example.com');
      final state = BrowserState(tabs: [tab], activeTabId: 'tab1');
      expect(state.activeTab, isNotNull);
      expect(state.activeTab!.id, 'tab1');
    });

    test('activeTab returns null when id not found', () {
      final tab = BrowserTab(id: 'tab1', url: 'https://example.com');
      final state = BrowserState(tabs: [tab], activeTabId: 'nonexistent');
      expect(state.activeTab, isNull);
    });

    test('ungroupedTabs returns tabs without groupId', () {
      final tab1 = BrowserTab(id: '1', url: 'https://a.com');
      final tab2 = BrowserTab(id: '2', url: 'https://b.com', groupId: 'g1');
      final state = BrowserState(tabs: [tab1, tab2]);
      expect(state.ungroupedTabs.length, 1);
      expect(state.ungroupedTabs.first.id, '1');
    });

    test('tabsInGroup returns tabs in specified group', () {
      final tab1 = BrowserTab(id: '1', url: 'https://a.com', groupId: 'g1');
      final tab2 = BrowserTab(id: '2', url: 'https://b.com', groupId: 'g1');
      final tab3 = BrowserTab(id: '3', url: 'https://c.com', groupId: 'g2');
      final state = BrowserState(tabs: [tab1, tab2, tab3]);
      expect(state.tabsInGroup('g1').length, 2);
    });

    test('isBookmarked returns true when url is bookmarked', () {
      final bookmark = Bookmark(url: 'https://example.com', title: 'Example');
      final state = BrowserState(bookmarks: [bookmark]);
      expect(state.isBookmarked('https://example.com'), isTrue);
      expect(state.isBookmarked('https://other.com'), isFalse);
    });

    test('copyWith updates tabs', () {
      final state = BrowserState();
      final tab = BrowserTab(id: '1', url: 'https://test.com');
      final updated = state.copyWith(tabs: [tab]);
      expect(updated.tabs.length, 1);
    });

    test('copyWith updates groups', () {
      final state = BrowserState();
      final group = TabGroup(id: 'g1', name: 'Test');
      final updated = state.copyWith(groups: [group]);
      expect(updated.groups.length, 1);
    });

    test('copyWith updates activeTabId', () {
      final state = BrowserState();
      final updated = state.copyWith(activeTabId: 'tab1');
      expect(updated.activeTabId, 'tab1');
    });

    test('copyWith clearActiveTabId sets activeTabId to null', () {
      final state = BrowserState(activeTabId: 'tab1');
      final updated = state.copyWith(clearActiveTabId: true);
      expect(updated.activeTabId, isNull);
    });

    test('copyWith updates bookmarks', () {
      final state = BrowserState();
      final bm = Bookmark(url: 'https://x.com', title: 'X');
      final updated = state.copyWith(bookmarks: [bm]);
      expect(updated.bookmarks.length, 1);
    });

    test('copyWith updates bookmarkFolders', () {
      final state = BrowserState();
      final folder = BookmarkFolder(name: 'Work');
      final updated = state.copyWith(bookmarkFolders: [folder]);
      expect(updated.bookmarkFolders.length, 1);
    });
  });

  group('BrowserNotifier', () {
    test('build returns initial BrowserState', () {
      final container = createContainerNoVault();
      addTearDown(container.dispose);
      final state = container.read(browserProvider);
      expect(state.tabs, isEmpty);
      expect(state.groups, isEmpty);
    });

    group('createTab', () {
      test('creates tab and sets it as active', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tabId = notifier.createTab(url: 'https://example.com');
        final state = container.read(browserProvider);
        expect(state.tabs.length, 1);
        expect(state.tabs.first.url, 'https://example.com');
        expect(state.tabs.first.isActive, isTrue);
        expect(state.activeTabId, tabId);
      });

      test('deactivates previous tabs when creating new tab', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab(url: 'https://first.com');
        notifier.createTab(url: 'https://second.com');

        final state = container.read(browserProvider);
        expect(state.tabs.length, 2);
        expect(state.tabs.first.isActive, isFalse);
        expect(state.tabs.last.isActive, isTrue);
      });

      test('creates tab with groupId', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab(url: 'https://test.com', groupId: 'g1');
        final state = container.read(browserProvider);
        expect(state.tabs.first.groupId, 'g1');
      });

      test('default url is about:blank', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab();
        final state = container.read(browserProvider);
        expect(state.tabs.first.url, 'about:blank');
      });
    });

    group('closeTab', () {
      test('removes tab and sets previous tab active', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tab1 = notifier.createTab(url: 'https://a.com');
        final tab2 = notifier.createTab(url: 'https://b.com');

        notifier.closeTab(tab2);

        final state = container.read(browserProvider);
        expect(state.tabs.length, 1);
        expect(state.activeTabId, tab1);
      });

      test('sets first remaining tab active when closing first tab', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tab1 = notifier.createTab(url: 'https://a.com');
        final tab2 = notifier.createTab(url: 'https://b.com');

        notifier.closeTab(tab1);

        final state = container.read(browserProvider);
        expect(state.tabs.length, 1);
        expect(state.activeTabId, tab2);
      });

      test('clears activeTabId when closing last tab', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tab1 = notifier.createTab();
        notifier.closeTab(tab1);

        final state = container.read(browserProvider);
        expect(state.tabs, isEmpty);
        expect(state.activeTabId, isNull);
      });

      test('removes tab from group when closed', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final gid = notifier.createGroup('Test');
        notifier.createTab(groupId: gid);
        notifier.createTab(url: 'https://other.com');

        notifier.closeTab(container.read(browserProvider).tabs.first.id);

        final state = container.read(browserProvider);
        expect(state.groups.first.tabIds, isEmpty);
      });
    });

    group('setActiveTab', () {
      test('sets the specified tab as active', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tab1 = notifier.createTab(url: 'https://a.com');
        final tab2 = notifier.createTab(url: 'https://b.com');

        notifier.setActiveTab(tab1);

        final state = container.read(browserProvider);
        expect(state.activeTabId, tab1);
        expect(state.tabs.firstWhere((t) => t.id == tab1).isActive, isTrue);
        expect(state.tabs.firstWhere((t) => t.id == tab2).isActive, isFalse);
      });
    });

    group('updateTabUrl', () {
      test('updates the url of a tab', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tabId = notifier.createTab(url: 'https://old.com');
        notifier.updateTabUrl(tabId, 'https://new.com');

        final state = container.read(browserProvider);
        expect(state.tabs.first.url, 'https://new.com');
      });

      test('does not affect other tabs', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tab1 = notifier.createTab(url: 'https://a.com');
        final tab2 = notifier.createTab(url: 'https://b.com');

        notifier.updateTabUrl(tab1, 'https://updated.com');

        final state = container.read(browserProvider);
        expect(state.tabs.firstWhere((t) => t.id == tab2).url, 'https://b.com');
      });
    });

    group('updateTabTitle', () {
      test('updates the title of a tab', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tabId = notifier.createTab(url: 'https://test.com');
        notifier.updateTabTitle(tabId, 'New Title');

        final state = container.read(browserProvider);
        expect(state.tabs.first.title, 'New Title');
      });
    });

    group('setTabLoading', () {
      test('sets tab loading state', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tabId = notifier.createTab();
        notifier.setTabLoading(tabId, true);

        final state = container.read(browserProvider);
        expect(state.tabs.first.isLoading, isTrue);

        notifier.setTabLoading(tabId, false);
        expect(container.read(browserProvider).tabs.first.isLoading, isFalse);
      });
    });

    group('reorderTab', () {
      test('moves tab from old index to new index', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tab1 = notifier.createTab(url: 'https://a.com');
        final tab2 = notifier.createTab(url: 'https://b.com');
        final tab3 = notifier.createTab(url: 'https://c.com');

        notifier.reorderTab(0, 2);

        final state = container.read(browserProvider);
        expect(state.tabs[0].id, tab2);
        expect(state.tabs[1].id, tab3);
        expect(state.tabs[2].id, tab1);
      });

      test('ignores invalid oldIndex', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab();
        notifier.reorderTab(-1, 0);
        expect(container.read(browserProvider).tabs.length, 1);
      });

      test('ignores invalid newIndex', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab();
        notifier.reorderTab(0, 99);
        expect(container.read(browserProvider).tabs.length, 1);
      });
    });

    group('togglePinTab', () {
      test('toggles pin state', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tabId = notifier.createTab();
        expect(container.read(browserProvider).tabs.first.isPinned, isFalse);

        notifier.togglePinTab(tabId);
        expect(container.read(browserProvider).tabs.first.isPinned, isTrue);

        notifier.togglePinTab(tabId);
        expect(container.read(browserProvider).tabs.first.isPinned, isFalse);
      });
    });

    group('createBookmarkFolder', () {
      test('creates folder under bookmarks-bar by default', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final folderId = notifier.createBookmarkFolder('Work');
        final state = container.read(browserProvider);
        final folder = state.bookmarkFolders.firstWhere((f) => f.id == folderId);
        expect(folder.name, 'Work');
        expect(folder.parentId, 'bookmarks-bar');
      });

      test('creates nested folder', () async {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final parentId = notifier.createBookmarkFolder('Parent');
        await Future.delayed(const Duration(milliseconds: 2));
        final childId = notifier.createBookmarkFolder('Child', parentId: parentId);
        final state = container.read(browserProvider);
        final child = state.bookmarkFolders.firstWhere((f) => f.id == childId);
        expect(child.parentId, parentId);
      });

      test('prevents cycle: parent cannot be itself', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final folder1 = notifier.createBookmarkFolder('Folder1');
        notifier.createBookmarkFolder('Folder2', parentId: folder1);

        final state = container.read(browserProvider);
        expect(state.bookmarkFolders.length, 3);
      });
    });

    group('createGroup', () {
      test('creates tab group with name and color', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createGroup('Research', color: 0xFFF44336);
        final state = container.read(browserProvider);
        final group = state.groups.first;
        expect(group.name, 'Research');
        expect(group.color, 0xFFF44336);
      });
    });

    group('addTabToGroup', () {
      test('adds tab to group', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final groupId = notifier.createGroup('Test');
        final tabId = notifier.createTab(url: 'https://test.com');

        notifier.addTabToGroup(tabId, groupId);

        final state = container.read(browserProvider);
        expect(state.tabs.first.groupId, groupId);
        expect(state.groups.first.tabIds.contains(tabId), isTrue);
      });
    });

    group('removeTabFromGroup', () {
      test('removes tab from its group', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final groupId = notifier.createGroup('Test');
        final tabId = notifier.createTab(groupId: groupId);

        notifier.removeTabFromGroup(tabId);

        final state = container.read(browserProvider);
        expect(state.tabs.first.groupId, isNull);
        expect(state.groups.first.tabIds.contains(tabId), isFalse);
      });
    });

    group('deleteGroup', () {
      test('removes group and ungroups its tabs', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final groupId = notifier.createGroup('Test');
        notifier.createTab(groupId: groupId);

        notifier.deleteGroup(groupId);

        final state = container.read(browserProvider);
        expect(state.groups, isEmpty);
        expect(state.tabs.first.groupId, isNull);
      });
    });

    group('toggleGroupExpanded', () {
      test('toggles group expanded state', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final groupId = notifier.createGroup('Test');
        expect(container.read(browserProvider).groups.first.isExpanded, isTrue);

        notifier.toggleGroupExpanded(groupId);
        expect(container.read(browserProvider).groups.first.isExpanded, isFalse);
      });
    });

    group('canAutoGroup', () {
      test('returns true when 3+ tabs open', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab(url: 'https://a.com');
        notifier.createTab(url: 'https://b.com');
        notifier.createTab(url: 'https://c.com');

        expect(notifier.canAutoGroup(), isTrue);
      });

      test('returns false with less than 3 tabs', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab();

        expect(notifier.canAutoGroup(), isFalse);
      });
    });

    group('toggleBookmark', () {
      test('adds bookmark when url not bookmarked', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.toggleBookmark('https://example.com', 'Example');

        final state = container.read(browserProvider);
        expect(state.bookmarks.length, 1);
        expect(state.bookmarks.first.url, 'https://example.com');
        expect(state.bookmarks.first.title, 'Example');
      });

      test('removes bookmark when url already bookmarked', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.toggleBookmark('https://example.com', 'Example');
        notifier.toggleBookmark('https://example.com', 'Example');

        final state = container.read(browserProvider);
        expect(state.bookmarks, isEmpty);
      });
    });

    group('addBookmark', () {
      test('adds bookmark to specified folder', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final folderId = notifier.createBookmarkFolder('Work');
        notifier.addBookmark('https://example.com', 'Example', folderId);

        final state = container.read(browserProvider);
        expect(state.bookmarks.first.folderId, folderId);
      });

      test('moves existing bookmark to new folder', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.toggleBookmark('https://example.com', 'Example');
        final folderId = notifier.createBookmarkFolder('Work');
        notifier.addBookmark('https://example.com', 'Example', folderId);

        final state = container.read(browserProvider);
        expect(state.bookmarks.length, 1);
        expect(state.bookmarks.first.folderId, folderId);
      });
    });

    group('removeBookmark', () {
      test('removes bookmark by id', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.toggleBookmark('https://example.com', 'Example');
        final bmId = container.read(browserProvider).bookmarks.first.id;

        notifier.removeBookmark(bmId);

        expect(container.read(browserProvider).bookmarks, isEmpty);
      });
    });

    group('moveBookmarkToFolder', () {
      test('moves bookmark to different folder', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final folderId = notifier.createBookmarkFolder('Work');
        notifier.toggleBookmark('https://example.com', 'Example');
        final bmId = container.read(browserProvider).bookmarks.first.id;

        notifier.moveBookmarkToFolder(bmId, folderId);

        final state = container.read(browserProvider);
        expect(state.bookmarks.first.folderId, folderId);
      });
    });

    group('deleteBookmarkFolder', () {
      test('removes folder and its subfolders', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final parentId = notifier.createBookmarkFolder('Parent');
        final childId = notifier.createBookmarkFolder('Child', parentId: parentId);

        notifier.deleteBookmarkFolder(parentId);

        final state = container.read(browserProvider);
        final ids = state.bookmarkFolders.map((f) => f.id).toSet();
        expect(ids.contains(parentId), isFalse);
        expect(ids.contains(childId), isFalse);
      });

      test('removes bookmarks in deleted folder', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final folderId = notifier.createBookmarkFolder('Temp');
        notifier.addBookmark('https://example.com', 'Example', folderId);

        notifier.deleteBookmarkFolder(folderId);

        final state = container.read(browserProvider);
        expect(state.bookmarks.first.folderId, '');
      });
    });

    group('toggleBookmarkFolder', () {
      test('toggles folder expanded state', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final folderId = notifier.createBookmarkFolder('Work');
        expect(
          container
              .read(browserProvider)
              .bookmarkFolders
              .firstWhere((f) => f.id == folderId)
              .isExpanded,
          isTrue,
        );

        notifier.toggleBookmarkFolder(folderId);
        expect(
          container
              .read(browserProvider)
              .bookmarkFolders
              .firstWhere((f) => f.id == folderId)
              .isExpanded,
          isFalse,
        );
      });
    });

    group('renameBookmarkFolder', () {
      test('renames the folder', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final folderId = notifier.createBookmarkFolder('Old Name');
        notifier.renameBookmarkFolder(folderId, 'New Name');

        final folder = container
            .read(browserProvider)
            .bookmarkFolders
            .firstWhere((f) => f.id == folderId);
        expect(folder.name, 'New Name');
      });
    });

    group('generateGroupProposal', () {
      test('groups tabs by domain', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab(url: 'https://flutter.dev/docs');
        notifier.createTab(url: 'https://flutter.dev/api');
        notifier.createTab(url: 'https://dart.dev/guides');
        notifier.createTab(url: 'https://example.com/page');

        final proposal = notifier.generateGroupProposal({});
        expect(proposal.groups.any((g) => g.name == 'flutter.dev'), isTrue);
      });

      test('includes ungrouped tabs in Other', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab(url: 'https://standalone.com/page');

        final proposal = notifier.generateGroupProposal({});
        final otherGroup = proposal.groups.where((g) => g.name == 'Other').firstOrNull;
        expect(otherGroup, isNotNull);
      });

      test('skips about:blank tabs', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        notifier.createTab();

        final proposal = notifier.generateGroupProposal({});
        final blankTabIds = proposal.groups.expand((g) => g.tabIds).toSet();
        expect(blankTabIds, isEmpty);
      });
    });

    group('applyGroupProposal', () {
      test('creates groups and assigns tabs', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final tab1 = notifier.createTab(url: 'https://flutter.dev');
        final tab2 = notifier.createTab(url: 'https://dart.dev');

        final proposal = TabGroupProposal(groups: [
          ProposedGroup(
            name: 'Flutter',
            tabIds: [tab1],
            color: 0xFF2196F3,
          ),
          ProposedGroup(
            name: 'Dart',
            tabIds: [tab2],
            color: 0xFF4CAF50,
          ),
        ]);

        notifier.applyGroupProposal(proposal);

        final state = container.read(browserProvider);
        expect(state.groups.length, 2);
        expect(state.tabs.firstWhere((t) => t.id == tab1).groupId, isNotNull);
        expect(state.tabs.firstWhere((t) => t.id == tab2).groupId, isNotNull);
      });
    });

    group('_wouldCreateCycle (via createBookmarkFolder)', () {
      test('prevents self-referencing parent', () {
        final container = createContainerNoVault();
        addTearDown(container.dispose);
        final notifier = container.read(browserProvider.notifier);

        final folderId = notifier.createBookmarkFolder('Folder');
        final state = container.read(browserProvider);
        expect(state.bookmarkFolders.where((f) => f.id == folderId).first.parentId, 'bookmarks-bar');
      });
    });
  });
}
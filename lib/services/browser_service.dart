import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../core/logging/app_logger.dart';
import '../data/models/browser_tab.dart';
import '../data/models/tab_group_proposal.dart';
import '../data/stores/vault_store.dart';

part 'browser_bookmarks.dart';

class BrowserState {
  final List<BrowserTab> tabs;
  final List<TabGroup> groups;
  final String? activeTabId;
  final List<Bookmark> bookmarks;
  final List<BookmarkFolder> bookmarkFolders;

  BrowserState({
    this.tabs = const [],
    this.groups = const [],
    this.activeTabId,
    this.bookmarks = const [],
    List<BookmarkFolder>? bookmarkFolders,
  }) : bookmarkFolders =
           bookmarkFolders ??
           [BookmarkFolder(id: 'bookmarks-bar', name: '收藏夹栏', parentId: '')];

  BrowserTab? get activeTab =>
      tabs.where((t) => t.id == activeTabId).firstOrNull;

  List<BrowserTab> get ungroupedTabs =>
      tabs.where((t) => t.groupId == null).toList();

  List<BrowserTab> tabsInGroup(String groupId) =>
      tabs.where((t) => t.groupId == groupId).toList();

  bool isBookmarked(String url) => bookmarks.any((b) => b.url == url);

  BrowserState copyWith({
    List<BrowserTab>? tabs,
    List<TabGroup>? groups,
    String? activeTabId,
    bool clearActiveTabId = false,
    List<Bookmark>? bookmarks,
    List<BookmarkFolder>? bookmarkFolders,
  }) {
    return BrowserState(
      tabs: tabs ?? this.tabs,
      groups: groups ?? this.groups,
      activeTabId: clearActiveTabId ? null : (activeTabId ?? this.activeTabId),
      bookmarks: bookmarks ?? this.bookmarks,
      bookmarkFolders: bookmarkFolders ?? this.bookmarkFolders,
    );
  }
}

typedef PageContentFetcher =
    Future<({String html, String text})> Function(String tabId);
typedef SelectedTextFetcher = Future<String> Function(String tabId);
typedef ScreenshotFetcher = Future<Uint8List?> Function(String tabId);

class BrowserNotifier extends Notifier<BrowserState>
    with _BrowserBookmarksMixin {
  PageContentFetcher? _contentFetcher;
  SelectedTextFetcher? _selectedTextFetcher;
  ScreenshotFetcher? _screenshotFetcher;

  void registerContentFetcher(PageContentFetcher fetcher) {
    _contentFetcher = fetcher;
  }

  void registerSelectedTextFetcher(SelectedTextFetcher fetcher) {
    _selectedTextFetcher = fetcher;
  }

  void registerScreenshotFetcher(ScreenshotFetcher fetcher) {
    _screenshotFetcher = fetcher;
  }

  Future<({String html, String text})?> fetchPageContent(String tabId) async {
    if (_contentFetcher == null) return null;
    try {
      return await _contentFetcher!(tabId);
    } catch (e) {
      appLog.error('fetchPageContent error', error: e);
      return null;
    }
  }

  Future<String> fetchSelectedText(String tabId) async {
    if (_selectedTextFetcher == null) return '';
    try {
      return await _selectedTextFetcher!(tabId);
    } catch (e) {
      appLog.error('fetchSelectedText error', error: e);
      return '';
    }
  }

  Future<Uint8List?> takeScreenshot(String tabId) async {
    if (_screenshotFetcher == null) return null;
    try {
      return await _screenshotFetcher!(tabId);
    } catch (e) {
      appLog.error('takeScreenshot error', error: e);
      return null;
    }
  }

  @override
  BrowserState build() => BrowserState();

  String createTab({String url = 'about:blank', String? groupId}) {
    final id = const Uuid().v4();
    final tab = BrowserTab(id: id, url: url, groupId: groupId, isActive: true);
    final updatedTabs = state.tabs
        .map((t) => t.copyWith(isActive: false))
        .toList();
    state = state.copyWith(tabs: [...updatedTabs, tab], activeTabId: id);
    return id;
  }

  void closeTab(String tabId) {
    final tabs = state.tabs.where((t) => t.id != tabId).toList();
    String? newActiveId = state.activeTabId;
    bool shouldClearActive = false;
    if (state.activeTabId == tabId) {
      final idx = state.tabs.indexWhere((t) => t.id == tabId);
      if (tabs.isNotEmpty) {
        if (idx > 0) {
          newActiveId = state.tabs[idx - 1].id;
        } else {
          newActiveId = tabs.first.id;
        }
      } else {
        shouldClearActive = true;
      }
    }
    final groups = state.groups.map((g) {
      return g.copyWith(tabIds: g.tabIds.where((id) => id != tabId).toList());
    }).toList();
    state = state.copyWith(
      tabs: tabs,
      groups: groups,
      activeTabId: newActiveId,
      clearActiveTabId: shouldClearActive,
    );
  }

  void setActiveTab(String tabId) {
    final tabs = state.tabs
        .map((t) => t.copyWith(isActive: t.id == tabId))
        .toList();
    state = state.copyWith(tabs: tabs, activeTabId: tabId);
  }

  void _updateTab<T>(
    String tabId,
    T value,
    BrowserTab Function(BrowserTab, T) updater,
  ) {
    final tabs = state.tabs
        .map((t) => t.id == tabId ? updater(t, value) : t)
        .toList();
    state = state.copyWith(tabs: tabs);
  }

  void updateTabUrl(String tabId, String url) {
    _updateTab(tabId, url, (t, v) => t.copyWith(url: v));
  }

  void updateTabTitle(String tabId, String title) {
    _updateTab(tabId, title, (t, v) => t.copyWith(title: v));
  }

  void setTabLoading(String tabId, bool loading) {
    _updateTab(tabId, loading, (t, v) => t.copyWith(isLoading: v));
  }

  void reorderTab(int oldIndex, int newIndex) {
    final tabs = List<BrowserTab>.from(state.tabs);
    if (oldIndex < 0 || oldIndex >= tabs.length) return;
    if (newIndex < 0 || newIndex >= tabs.length) return;
    final tab = tabs.removeAt(oldIndex);
    tabs.insert(newIndex, tab);
    state = state.copyWith(tabs: tabs);
  }

  void togglePinTab(String tabId) {
    final tabs = state.tabs
        .map((t) => t.id == tabId ? t.copyWith(isPinned: !t.isPinned) : t)
        .toList();
    state = state.copyWith(tabs: tabs);
  }

  String createGroup(String name, {int color = 0xFF2196F3}) {
    final id = const Uuid().v4();
    final group = TabGroup(id: id, name: name, color: color);
    state = state.copyWith(groups: [...state.groups, group]);
    return id;
  }

  void addTabToGroup(String tabId, String groupId) {
    final tabs = state.tabs
        .map((t) => t.id == tabId ? t.copyWithExplicit(groupId: groupId) : t)
        .toList();
    final groups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(tabIds: [...g.tabIds, tabId]);
      }
      return g;
    }).toList();
    state = state.copyWith(tabs: tabs, groups: groups);
  }

  void removeTabFromGroup(String tabId) {
    String? oldGroupId;
    final tabs = state.tabs.map((t) {
      if (t.id == tabId) {
        oldGroupId = t.groupId;
        return t.copyWithExplicit(groupId: null);
      }
      return t;
    }).toList();
    final groups = state.groups.map((g) {
      if (g.id == oldGroupId) {
        return g.copyWith(tabIds: g.tabIds.where((id) => id != tabId).toList());
      }
      return g;
    }).toList();
    state = state.copyWith(tabs: tabs, groups: groups);
  }

  void deleteGroup(String groupId) {
    final tabs = state.tabs.map((t) {
      if (t.groupId == groupId) {
        return t.copyWithExplicit(groupId: null);
      }
      return t;
    }).toList();
    final groups = state.groups.where((g) => g.id != groupId).toList();
    state = state.copyWith(tabs: tabs, groups: groups);
  }

  void toggleGroupExpanded(String groupId) {
    final groups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(isExpanded: !g.isExpanded);
      }
      return g;
    }).toList();
    state = state.copyWith(groups: groups);
  }

  bool canAutoGroup() => state.tabs.length >= 3;

  TabGroupProposal generateGroupProposal(Map<String, String> tabSummaries) {
    final domainGroups = <String, List<String>>{};

    for (final tab in state.tabs) {
      final uri = Uri.tryParse(tab.url);
      String domain;
      if (uri != null && uri.host.isNotEmpty) {
        domain = uri.host.replaceAll('www.', '');
        final parts = domain.split('.');
        if (parts.length > 2) {
          domain = parts.sublist(parts.length - 2).join('.');
        }
      } else if (tab.url == 'about:blank') {
        continue;
      } else {
        domain = 'other';
      }
      domainGroups.putIfAbsent(domain, () => []).add(tab.id);
    }

    final groups = <ProposedGroup>[];
    final groupColors = [
      0xFF2196F3,
      0xFF4CAF50,
      0xFFFF9800,
      0xFF9C27B0,
      0xFFF44336,
      0xFF00BCD4,
    ];
    var colorIdx = 0;

    for (final entry in domainGroups.entries) {
      if (entry.value.length >= 2) {
        groups.add(
          ProposedGroup(
            name: entry.key,
            tabIds: entry.value,
            color: groupColors[colorIdx % groupColors.length],
          ),
        );
        colorIdx++;
      }
    }

    final groupedTabIds = groups.expand((g) => g.tabIds).toSet();
    final ungrouped = state.tabs
        .where((t) => !groupedTabIds.contains(t.id) && t.url != 'about:blank')
        .map((t) => t.id)
        .toList();
    if (ungrouped.isNotEmpty) {
      groups.add(
        ProposedGroup(
          name: 'Other',
          tabIds: ungrouped,
          color: groupColors[colorIdx % groupColors.length],
        ),
      );
    }

    return TabGroupProposal(groups: groups);
  }

  void applyGroupProposal(TabGroupProposal proposal) {
    for (final group in proposal.groups) {
      final groupId = createGroup(group.name, color: group.color);
      for (final tabId in group.tabIds) {
        addTabToGroup(tabId, groupId);
      }
    }
  }
}

final browserProvider = NotifierProvider<BrowserNotifier, BrowserState>(
  BrowserNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/browser_tab.dart';
import '../data/models/tab_group_proposal.dart';

class BrowserState {
  final List<BrowserTab> tabs;
  final List<TabGroup> groups;
  final String? activeTabId;

  BrowserState({
    this.tabs = const [],
    this.groups = const [],
    this.activeTabId,
  });

  BrowserTab? get activeTab =>
      tabs.where((t) => t.id == activeTabId).firstOrNull;

  List<BrowserTab> get ungroupedTabs =>
      tabs.where((t) => t.groupId == null).toList();

  List<BrowserTab> tabsInGroup(String groupId) =>
      tabs.where((t) => t.groupId == groupId).toList();

  BrowserState copyWith({
    List<BrowserTab>? tabs,
    List<TabGroup>? groups,
    String? activeTabId,
  }) {
    return BrowserState(
      tabs: tabs ?? this.tabs,
      groups: groups ?? this.groups,
      activeTabId: activeTabId ?? this.activeTabId,
    );
  }
}

class BrowserNotifier extends Notifier<BrowserState> {
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
    if (state.activeTabId == tabId) {
      final idx = state.tabs.indexWhere((t) => t.id == tabId);
      if (tabs.isNotEmpty) {
        if (idx > 0) {
          newActiveId = state.tabs[idx - 1].id;
        } else {
          newActiveId = tabs.first.id;
        }
      } else {
        newActiveId = null;
      }
    }
    final groups = state.groups.map((g) {
      return g.copyWith(tabIds: g.tabIds.where((id) => id != tabId).toList());
    }).toList();
    state = state.copyWith(
      tabs: tabs,
      groups: groups,
      activeTabId: newActiveId,
    );
  }

  void setActiveTab(String tabId) {
    final tabs = state.tabs
        .map((t) => t.copyWith(isActive: t.id == tabId))
        .toList();
    state = state.copyWith(tabs: tabs, activeTabId: tabId);
  }

  void updateTabUrl(String tabId, String url) {
    final tabs = state.tabs
        .map((t) => t.id == tabId ? t.copyWith(url: url) : t)
        .toList();
    state = state.copyWith(tabs: tabs);
  }

  void updateTabTitle(String tabId, String title) {
    final tabs = state.tabs
        .map((t) => t.id == tabId ? t.copyWith(title: title) : t)
        .toList();
    state = state.copyWith(tabs: tabs);
  }

  void setTabLoading(String tabId, bool loading) {
    final tabs = state.tabs
        .map((t) => t.id == tabId ? t.copyWith(isLoading: loading) : t)
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
    final groupColors = [0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFF9C27B0, 0xFFF44336, 0xFF00BCD4];
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

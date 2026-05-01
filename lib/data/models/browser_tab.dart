class TabGroup {
  final String id;
  final String name;
  final List<String> tabIds;
  final int color;
  final bool isExpanded;

  TabGroup({
    required this.id,
    required this.name,
    this.tabIds = const [],
    this.color = 0xFF2196F3,
    this.isExpanded = true,
  });

  TabGroup copyWith({
    String? name,
    List<String>? tabIds,
    int? color,
    bool? isExpanded,
  }) {
    return TabGroup(
      id: id,
      name: name ?? this.name,
      tabIds: tabIds ?? List.from(this.tabIds),
      color: color ?? this.color,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class BrowserTab {
  final String id;
  final String url;
  final String title;
  final String? groupId;
  final bool isLoading;
  final bool isActive;

  BrowserTab({
    required this.id,
    this.url = 'about:blank',
    this.title = 'New Tab',
    this.groupId,
    this.isLoading = false,
    this.isActive = false,
  });

  BrowserTab copyWith({
    String? url,
    String? title,
    bool? isLoading,
    bool? isActive,
  }) {
    return BrowserTab(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      groupId: groupId,
      isLoading: isLoading ?? this.isLoading,
      isActive: isActive ?? this.isActive,
    );
  }

  BrowserTab copyWithExplicit({
    String? groupId,
  }) {
    return BrowserTab(
      id: id,
      url: url,
      title: title,
      groupId: groupId,
      isLoading: isLoading,
      isActive: isActive,
    );
  }
}

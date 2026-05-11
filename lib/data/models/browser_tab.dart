class BookmarkFolder {
  final String id;
  final String name;
  final String parentId;
  final bool isExpanded;

  BookmarkFolder({
    String? id,
    required this.name,
    this.parentId = 'bookmarks-bar',
    this.isExpanded = true,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  BookmarkFolder copyWith({String? name, String? parentId, bool? isExpanded}) {
    return BookmarkFolder(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'isExpanded': isExpanded,
  };

  factory BookmarkFolder.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return BookmarkFolder(
      id: id,
      name: json['name'] as String,
      parentId: id == 'bookmarks-bar'
          ? ''
          : (json['parentId'] as String? ?? 'bookmarks-bar'),
      isExpanded: json['isExpanded'] as bool? ?? true,
    );
  }
}

class Bookmark {
  final String id;
  final String url;
  final String title;
  final String folderId;
  final DateTime addedAt;

  Bookmark({
    String? id,
    required this.url,
    required this.title,
    String? folderId,
    DateTime? addedAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       folderId = folderId ?? '',
       addedAt = addedAt ?? DateTime.now();

  Bookmark copyWith({String? folderId}) {
    return Bookmark(
      id: id,
      url: url,
      title: title,
      folderId: folderId ?? this.folderId,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'folderId': folderId,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    id: json['id'] as String,
    url: json['url'] as String,
    title: json['title'] as String,
    folderId: json['folderId'] as String? ?? '',
    addedAt: json['addedAt'] != null
        ? DateTime.parse(json['addedAt'] as String)
        : DateTime.now(),
  );
}

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

  BrowserTab copyWithExplicit({String? groupId}) {
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

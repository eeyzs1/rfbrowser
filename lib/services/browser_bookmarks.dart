part of 'browser_service.dart';

/// Mixin providing bookmark and bookmark folder management for [BrowserNotifier].
mixin _BrowserBookmarksMixin on Notifier<BrowserState> {
  String? get bookmarksPath {
    final vault = ref.read(vaultProvider).currentVault;
    if (vault == null) return null;
    return p.join(vault.path, '.rfbrowser', 'bookmarks.json');
  }

  Future<void> loadBookmarks() async {
    final path = bookmarksPath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final folders =
          (json['folders'] as List?)
              ?.map((e) => BookmarkFolder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final bookmarks =
          (json['bookmarks'] as List?)
              ?.map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      state = state.copyWith(bookmarkFolders: folders, bookmarks: bookmarks);
    } catch (e) {
      appLog.error('loadBookmarks error', error: e);
    }
  }

  Future<void> _saveBookmarks() async {
    final path = bookmarksPath;
    if (path == null) return;
    final file = File(path);
    try {
      final dir = Directory(p.dirname(path));
      if (!await dir.exists()) await dir.create(recursive: true);
      final json = jsonEncode({
        'folders': state.bookmarkFolders.map((f) => f.toJson()).toList(),
        'bookmarks': state.bookmarks.map((b) => b.toJson()).toList(),
      });
      await file.writeAsString(json);
    } catch (e) {
      appLog.error('_saveBookmarks error', error: e);
    }
  }

  void _persistBookmarks() {
    _saveBookmarks();
  }

  bool _wouldCreateCycle(
    String folderId,
    String parentId, {
    List<BookmarkFolder>? folders,
  }) {
    if (folderId == parentId) return true;
    var current = parentId;
    final visited = <String>{};
    final bookmarkFolders = folders ?? state.bookmarkFolders;
    while (current.isNotEmpty) {
      if (current == folderId) return true;
      if (!visited.add(current)) return true;
      final parent = bookmarkFolders.where((f) => f.id == current).firstOrNull;
      current = parent?.parentId ?? '';
    }
    return false;
  }

  String createBookmarkFolder(
    String name, {
    String parentId = 'bookmarks-bar',
  }) {
    final folder = BookmarkFolder(name: name, parentId: parentId);
    if (_wouldCreateCycle(folder.id, parentId)) {
      appLog.warning('createBookmarkFolder: cycle detected, using root');
      return createBookmarkFolder(name);
    }
    state = state.copyWith(bookmarkFolders: [...state.bookmarkFolders, folder]);
    _persistBookmarks();
    return folder.id;
  }

  void toggleBookmark(String url, String title) {
    final existing = state.bookmarks.where((b) => b.url == url).firstOrNull;
    if (existing != null) {
      final updated = state.bookmarks.where((b) => b.url != url).toList();
      state = state.copyWith(bookmarks: updated);
    } else {
      final bookmark = Bookmark(
        url: url,
        title: title,
        folderId: 'bookmarks-bar',
      );
      state = state.copyWith(bookmarks: [...state.bookmarks, bookmark]);
    }
    _persistBookmarks();
  }

  void addBookmark(String url, String title, String folderId) {
    final existing = state.bookmarks.where((b) => b.url == url).firstOrNull;
    if (existing != null) {
      final updated = state.bookmarks.map((b) {
        if (b.url == url) return b.copyWith(folderId: folderId);
        return b;
      }).toList();
      state = state.copyWith(bookmarks: updated);
    } else {
      final bookmark = Bookmark(url: url, title: title, folderId: folderId);
      state = state.copyWith(bookmarks: [...state.bookmarks, bookmark]);
    }
    _persistBookmarks();
  }

  void removeBookmark(String id) {
    state = state.copyWith(
      bookmarks: state.bookmarks.where((b) => b.id != id).toList(),
    );
    _persistBookmarks();
  }

  void moveBookmarkToFolder(String bookmarkId, String folderId) {
    final updated = state.bookmarks.map((b) {
      if (b.id == bookmarkId) return b.copyWith(folderId: folderId);
      return b;
    }).toList();
    state = state.copyWith(bookmarks: updated);
    _persistBookmarks();
  }

  void deleteBookmarkFolder(String folderId) {
    final toDelete = <String>[folderId];
    final visited = <String>{folderId};
    var i = 0;
    while (i < toDelete.length) {
      final current = toDelete[i];
      final children = state.bookmarkFolders
          .where((f) => f.parentId == current)
          .map((f) => f.id)
          .where((id) => visited.add(id))
          .toList();
      toDelete.addAll(children);
      i++;
    }
    final updatedBookmarks = state.bookmarks.map((b) {
      if (toDelete.contains(b.folderId)) return b.copyWith(folderId: '');
      return b;
    }).toList();
    state = state.copyWith(
      bookmarkFolders: state.bookmarkFolders
          .where((f) => !toDelete.contains(f.id))
          .toList(),
      bookmarks: updatedBookmarks,
    );
    _persistBookmarks();
  }

  void toggleBookmarkFolder(String folderId) {
    final updated = state.bookmarkFolders.map((f) {
      if (f.id == folderId) return f.copyWith(isExpanded: !f.isExpanded);
      return f;
    }).toList();
    state = state.copyWith(bookmarkFolders: updated);
    _persistBookmarks();
  }

  void renameBookmarkFolder(String folderId, String newName) {
    final updated = state.bookmarkFolders.map((f) {
      if (f.id == folderId) return f.copyWith(name: newName);
      return f;
    }).toList();
    state = state.copyWith(bookmarkFolders: updated);
    _persistBookmarks();
  }
}

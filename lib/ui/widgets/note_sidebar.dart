// ignore_for_file: unused_element, unused_element_parameter
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/logging/app_logger.dart';
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/settings_service.dart';
import '../../data/models/note.dart';
import '../../data/models/link.dart';
import '../../data/models/browser_tab.dart';
import '../../data/stores/vault_store.dart';
import '../theme/design_tokens.dart';
import 'create_note_dialog.dart';

part 'note_sidebar/sidebar_tab_bar.dart';
part 'note_sidebar/sidebar_notes_toolbar.dart';
part 'note_sidebar/sidebar_notes_tree.dart';
part 'note_sidebar/sidebar_notes_tree_widgets.dart';
part 'note_sidebar/sidebar_bookmarks.dart';
part 'note_sidebar/sidebar_bookmark_row.dart';
part 'note_sidebar/sidebar_note_actions.dart';
part 'note_sidebar/sidebar_bookmark_actions.dart';
part 'note_sidebar/sidebar_vault.dart';

enum _SidebarTab { notes, bookmarks }

class NoteSidebar extends ConsumerStatefulWidget {
  final VoidCallback? onNoteOpened;
  final ValueChanged<String>? onNotePreview;
  final ValueChanged<String>? onBookmarkOpened;
  const NoteSidebar({
    super.key,
    this.onNoteOpened,
    this.onNotePreview,
    this.onBookmarkOpened,
  });

  @override
  ConsumerState<NoteSidebar> createState() => _NoteSidebarState();
}

/// Base class holding shared state fields and core infrastructure methods.
/// UI builders and action handlers live in mixins (part files) that use
/// `on _NoteSidebarStateBase`, then are combined in [_NoteSidebarState].
abstract class _NoteSidebarStateBase extends ConsumerState<NoteSidebar> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  // Debounce timer for sidebar search input (120ms). Cancels the previous
  // pending search on each keystroke so we don't scan note content per key.
  Timer? _searchDebounce;
  // True while a [compute] isolate is scanning note content for a large vault.
  bool _isSearching = false;
  // Monotonic generation guard so stale isolate results (from a superseded
  // query) are discarded.
  int _searchGeneration = 0;
  _SidebarTab _activeTab = _SidebarTab.notes;
  final _expandedNoteFolders = <String>{};
  final _expandedBookmarkFolders = <String>{};
  String? _hoveredBookmarkId;
  String? _hoveredBookmarkFolder;
  String? _draggingNoteId;
  String? _draggingBookmarkId;
  List<String> _diskFolders = [];
  double _baseFontSize = 11.0;

  // --- Filtered-notes + trie cache ---
  // The notes tree (trie) depends only on which notes are shown and the
  // disk folder structure — NOT on activeNoteId or note content. Yet
  // knowledgeProvider emits on every note open / keystroke, which used
  // to trigger a full _filterNotes + trie rebuild each time and made
  // opening notes feel frozen. Caching keyed on the actual inputs keeps
  // note opening responsive.
  List<Note>? _cacheSrcNotes;
  NoteFilter? _cacheFilter;
  String? _cacheSearch;
  List<Link>? _cacheLinks;
  List<String>? _cacheDiskFolders;
  List<Note> _cacheFiltered = const [];
  _TrieNode? _cacheTrie;

  @override
  void initState() {
    super.initState();
    _expandedNoteFolders.add('');
    _expandedBookmarkFolders.add('bookmarks-bar');
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanDiskFolders());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanDiskFolders() async {
    final vaultState = ref.read(vaultProvider);
    if (vaultState.currentVault == null) return;
    final vaultPath = vaultState.currentVault!.path;
    final folders = <String>[];
    try {
      await _collectFolders(vaultPath, '', folders);
    } catch (_) {
      appLog.error('NoteSidebar: failed to collect folders');
    }
    if (mounted) {
      setState(() => _diskFolders = folders);
    }
  }

  Future<void> _collectFolders(
    String basePath,
    String relativePath,
    List<String> result,
  ) async {
    final dir = Directory(
      relativePath.isEmpty ? basePath : '$basePath/$relativePath',
    );
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.') || name == 'attachments') continue;
        final path = relativePath.isEmpty ? name : '$relativePath/$name';
        result.add(path);
        await _collectFolders(basePath, path, result);
      }
    }
  }

  List<Note> _filterNotes(List<Note> notes, KnowledgeState knowledgeState) {
    return _applyNoteFilter(
      notes,
      _searchQuery,
      knowledgeState.noteFilter,
      knowledgeState.links,
    );
  }

  /// Returns true when the filtered-notes / trie cache is still valid for
  /// the current [knowledgeState]. Inputs are compared by identity where
  /// the service hands back a new list only when the underlying data
  /// actually changes (note added/removed/renamed), so an activeNoteId
  /// change — which preserves the notes + links references — is a hit.
  bool _cacheValid(KnowledgeState ks) =>
      identical(ks.notes, _cacheSrcNotes) &&
      ks.noteFilter == _cacheFilter &&
      _searchQuery == _cacheSearch &&
      identical(ks.links, _cacheLinks) &&
      identical(_diskFolders, _cacheDiskFolders);

  /// Returns the filtered notes list, reusing the cached result when the
  /// inputs are unchanged (the common case during note opening / typing).
  ///
  /// While an async (isolate) search is running this returns the stale
  /// cached list so [build] never blocks; the isolate completion callback
  /// updates the cache and calls [setState].
  List<Note> _resolvedNotes(KnowledgeState ks) {
    if (_cacheValid(ks)) return _cacheFiltered;
    // Async search in progress — return stale cache until the isolate lands.
    if (_isSearching) return _cacheFiltered;
    // Synchronous path (small vault ≤500 notes, or no content search).
    final filtered = _filterNotes(ks.notes, ks);
    _cacheSrcNotes = ks.notes;
    _cacheFilter = ks.noteFilter;
    _cacheSearch = _searchQuery;
    _cacheLinks = ks.links;
    _cacheDiskFolders = _diskFolders;
    _cacheFiltered = filtered;
    _cacheTrie = null;
    return filtered;
  }

  /// Called by the debounced search handler (see
  /// [_SidebarNotesToolbarMixin]). Sets the query and, for large vaults
  /// (>500 notes) with a non-empty query, runs the content scan in a
  /// worker isolate via [compute] so the UI thread never blocks
  /// (Rule 6.1). For small vaults the synchronous path in
  /// [_resolvedNotes] is fast enough.
  void _applySearchQuery(String q) {
    final ks = ref.read(knowledgeProvider);
    final useIsolate = q.isNotEmpty && ks.notes.length > 500;
    if (!useIsolate) {
      setState(() => _searchQuery = q);
      return;
    }
    // Large vault + content search — offload to isolate.
    _searchGeneration++;
    final gen = _searchGeneration;
    setState(() {
      _searchQuery = q;
      _isSearching = true;
    });
    final input = _FilterIsolateInput(
      notes: ks.notes,
      query: q,
      filter: ks.noteFilter,
      links: ks.links,
    );
    compute(_filterNotesInIsolate, input).then((result) {
      // Stale check: a newer search may have started, or the widget disposed.
      if (gen != _searchGeneration || !mounted) return;
      setState(() {
        _cacheFiltered = result;
        _cacheSrcNotes = ks.notes;
        _cacheFilter = ks.noteFilter;
        _cacheSearch = q;
        _cacheLinks = ks.links;
        _cacheDiskFolders = _diskFolders;
        _cacheTrie = null;
        _isSearching = false;
      });
    });
  }

  // --- Shared UI helper (used by multiple mixins) ---
  Widget _ib(IconData icon, VoidCallback? onPressed, String tooltip) {
    return IconButton(
      icon: Icon(
        icon,
        size: 12,
        color: Theme.of(context).hintColor.withValues(alpha: 0.7),
      ),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      tooltip: tooltip,
    );
  }

  // --- Abstract declarations for cross-mixin method calls ---
  // These are implemented in the respective action mixins but called from
  // UI mixins, so they must be visible on the base type.
  void _createNoteFolder(String parentPath);
  void _createNewNote(String folderPath);
  void _renameNoteFolder(String folderPath);
  void _confirmDeleteNoteFolder(String folderPath);
  void _showMoveNoteDialog(Note note);
  void _confirmDeleteNote(String title, String noteId);
  void _createBookmarkFolder(String parentFolderId);
  void _renameBookmarkFolder(BookmarkFolder folder);
  void _confirmDeleteBookmarkFolder(String name, String folderId);
  void _showMoveBookmarkDialog(Bookmark bookmark);

  /// Implemented by [_SidebarBookmarkRowMixin], called from
  /// [_SidebarBookmarksMixin] during folder-tree rendering.
  Widget _bookmarkRow(Bookmark bookmark, int depth, AppLocalizations l);
}

class _NoteSidebarState extends _NoteSidebarStateBase
    with
        _SidebarTabBarMixin,
        _SidebarNotesToolbarMixin,
        _SidebarNotesTreeMixin,
        _SidebarBookmarksMixin,
        _SidebarBookmarkRowMixin,
        _SidebarNoteActionsMixin,
        _SidebarBookmarkActionsMixin,
        _SidebarVaultMixin {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    _baseFontSize = settings.editorFontSize * 0.75;

    if (vaultState.currentVault == null) {
      return _buildNoVaultPrompt(theme, l);
    }

    final notes = _resolvedNotes(knowledgeState);

    return Column(
      children: [
        _buildTabBar(theme, l),
        if (_activeTab == _SidebarTab.notes)
          _buildNotesToolbar(theme, l)
        else
          _buildBookmarksToolbar(theme, l),
        if (_activeTab == _SidebarTab.notes &&
            knowledgeState.activeNote != null)
          _buildBreadcrumb(theme, knowledgeState.activeNote!, l),
        Expanded(
          child: _activeTab == _SidebarTab.notes
              ? _buildNotesTree(theme, notes, knowledgeState, l)
              : _buildBookmarksTree(theme, l),
        ),
      ],
    );
  }
}

/// Input bundle for [_filterNotesInIsolate]. Must be isolate-Sendable;
/// [Note], [Link], [NoteFilter] are plain data types with no native handles.
class _FilterIsolateInput {
  final List<Note> notes;
  final String query;
  final NoteFilter filter;
  final List<Link> links;

  const _FilterIsolateInput({
    required this.notes,
    required this.query,
    required this.filter,
    required this.links,
  });
}

/// Pure (isolate-safe) note filtering logic shared by the synchronous
/// [_NoteSidebarStateBase._filterNotes] path and the async
/// [_filterNotesInIsolate] worker. Extracted top-level so both can call it
/// without duplicating the filter/search conditions.
List<Note> _applyNoteFilter(
  List<Note> notes,
  String query,
  NoteFilter filter,
  List<Link> links,
) {
  var filtered = notes;
  if (filter == NoteFilter.hasLinks) {
    filtered = notes
        .where(
          (n) => links.any((l) => l.sourceId == n.id || l.targetId == n.id),
        )
        .toList();
  } else if (filter == NoteFilter.hasTags) {
    filtered = notes.where((n) => n.tags.isNotEmpty).toList();
  } else if (filter == NoteFilter.hasAttachments) {
    filtered = notes.where((n) => n.frontMatter.containsKey('attachments')).toList();
  }
  if (query.isEmpty) return filtered;
  final q = query.toLowerCase();
  return filtered
      .where(
        (n) =>
            n.title.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q)) ||
            n.content.toLowerCase().contains(q),
      )
      .toList();
}

/// Worker entry for [compute] (Rule 6.1: >100ms / >2000-char content
/// scans must run in a worker isolate). Runs the same filter logic as
/// the synchronous path but off the UI thread for large vaults.
List<Note> _filterNotesInIsolate(_FilterIsolateInput input) {
  return _applyNoteFilter(input.notes, input.query, input.filter, input.links);
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/editor/highlighted_text_editing_controller.dart';
import '../../data/models/split_pane_node.dart';
import '../../data/stores/split_pane_store.dart';
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../../services/settings_service.dart';
import '../theme/design_tokens.dart';
import 'note_markdown_view.dart';

/// A single note pane rendered inside a [SplitPane] leaf. Displays the
/// note identified by [noteId] according to [viewMode]:
/// - [NoteViewMode.edit]: editable monospace TextField with autosave.
/// - [NoteViewMode.source]: read-only raw markdown source.
/// - [NoteViewMode.rendered]: read-only rendered markdown.
///
/// On focus, the pane reports its [leafId] to the split-pane store and
/// its [noteId] to the knowledge service so that backlinks / AI context
/// follow the focused pane.
class NotePaneView extends ConsumerStatefulWidget {
  final String leafId;
  final String noteId;
  final NoteViewMode viewMode;

  const NotePaneView({
    super.key,
    required this.leafId,
    required this.noteId,
    required this.viewMode,
  });

  @override
  ConsumerState<NotePaneView> createState() => _NotePaneViewState();
}

class _NotePaneViewState extends ConsumerState<NotePaneView> {
  // Above this size, the editor defers setting _controller.text to a
  // post-frame callback so a loading indicator can paint first. Flutter's
  // TextField(maxLines: null, expands: true) lays out the ENTIRE document
  // as one RenderParagraph — for a 50KB file that layout pass freezes the
  // UI thread for seconds. Deferring doesn't fix the layout cost, but it
  // gives the user visible feedback instead of a frozen window on open.
  // VSCode/Obsidian avoid this entirely via viewport rendering (only
  // visible lines are laid out); Flutter's standard TextField does not
  // support that, so a real fix requires a viewport-aware editor widget.
  static const _largeFileThreshold = 20000; // ~20KB

  final _controller = HighlightedTextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  Timer? _autoSaveTimer;
  // Debounce timer for propagating content changes to the knowledge
  // provider. Without this, every keystroke triggers:
  //   1. updateNoteContent → copies the entire notes list
  //   2. knowledgeProvider state change → rebuilds NoteSidebar (rebuilds
  //      the whole trie), BacklinksPanel, all other panes
  //   3. BacklinksPanel recomputes unlinked mentions
  // This made the editor freeze on large vaults. A 400ms debounce keeps
  // the UI responsive; autosave still fires at its own 3s cadence.
  Timer? _contentSyncTimer;
  bool _isDirty = false;
  bool _suppressListener = false;
  String? _lastLoadedNoteId;
  // Last text observed when _onContentChanged fired. The controller's
  // notifyListeners() also fires when only the async markdown highlight
  // (TextSpan) updates — without this guard those no-op notifications
  // would mark the note dirty and schedule autosaves even though the
  // user never edited anything.
  String? _lastSeenText;
  // True while a large file is being loaded into the controller via a
  // deferred post-frame callback. While true, _buildEdit shows a loading
  // indicator instead of the TextField so the user sees immediate
  // feedback instead of a frozen window.
  bool _isLoadingLargeFile = false;
  // Set to true when the user explicitly clicks "Edit anyway" on the
  // large-file notice. While true, _buildBody skips the source-view
  // fallback and builds the real editor (with deferred loading). Reset
  // whenever the displayed note changes.
  bool _forceEditForLargeFile = false;
  // Set to true when the user explicitly clicks "渲染" on the large-file
  // notice in rendered view. While true, the rendered branch skips the
  // source-view fallback and builds NoteMarkdownView with forceRender so
  // its internal guard is also bypassed. Reset whenever the displayed
  // note changes.
  bool _forceRenderForLargeFile = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onContentChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant NotePaneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset the rendered-mode force flag when the displayed note changes,
    // so a new large note doesn't inherit the previous note's forced-render
    // state. (_forceEditForLargeFile is reset inside the edit-mode block
    // below via _lastLoadedNoteId; rendered mode has no such tracking, so
    // we handle it here.)
    if (oldWidget.noteId != widget.noteId) {
      _forceRenderForLargeFile = false;
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _contentSyncTimer?.cancel();
    _controller.removeListener(_onContentChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      ref.read(splitPaneProvider.notifier).setActiveLeaf(widget.leafId);
      ref.read(knowledgeProvider.notifier).setActiveNoteId(widget.noteId);
    }
  }

  void _onContentChanged() {
    final currentText = _controller.text;
    if (_suppressListener) {
      // Still track the text so that the subsequent async-highlight
      // notifyListeners() doesn't mistake the loaded text for an edit.
      _lastSeenText = currentText;
      return;
    }
    if (_lastSeenText == currentText) {
      // Notification not triggered by a text change (e.g. async highlight
      // update). Don't mark dirty or schedule saves.
      return;
    }
    _lastSeenText = currentText;
    if (!_isDirty && _lastLoadedNoteId != null) {
      _isDirty = true;
    }
    // Debounce the knowledge-state propagation so a burst of keystrokes
    // only triggers one notes-list copy + listener rebuild.
    _contentSyncTimer?.cancel();
    _contentSyncTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref
          .read(knowledgeProvider.notifier)
          .updateNoteContent(widget.noteId, _controller.text);
    });
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      if (_isDirty) _saveNote();
    });
  }

  void _saveNote() {
    // Flush any pending debounced content sync so the knowledge service
    // has the latest text before persisting to disk.
    _contentSyncTimer?.cancel();
    ref
        .read(knowledgeProvider.notifier)
        .updateNoteContent(widget.noteId, _controller.text);
    ref.read(knowledgeProvider.notifier).saveNoteById(widget.noteId);
    _isDirty = false;
  }

  @override
  Widget build(BuildContext context) {
    // Select ONLY this pane's note content instead of watching the entire
    // knowledgeProvider state. String has proper == semantics, so the widget
    // only rebuilds when THIS note's content actually changes — not when
    // other notes are edited, created, or deleted. This prevents a cascade
    // of rebuilds across all open tabs when the user types in one tab.
    // Uses byId for O(1) lookup instead of O(n) linear scan — critical with
    // multiple split panes where each pane's select runs per keystroke.
    final noteContent = ref.watch(
      knowledgeProvider.select((s) => s.byId[widget.noteId]?.content),
    );
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    if (noteContent == null) {
      return Center(
        child: Text(
          l.noNoteSelected,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      );
    }

    // (Re)load the controller when the displayed note changes or when
    // external edits arrive while this pane is not dirty.
    if (widget.viewMode == NoteViewMode.edit) {
      if (_lastLoadedNoteId != widget.noteId) {
        _lastLoadedNoteId = widget.noteId;
        _forceEditForLargeFile = false;
        // For large files, skip loading text into the controller unless the
        // user explicitly forced edit mode. _buildBody will fall back to a
        // fast source view with a notice. This avoids the RenderParagraph
        // layout pass that freezes the UI for seconds on large files.
        if (noteContent.length > _largeFileThreshold) {
          _isDirty = false;
          _lastSeenText = '';
          _controller.text = '';
        } else {
          _suppressListener = true;
          _controller.text = noteContent;
          _lastSeenText = noteContent;
          _isDirty = false;
          _suppressListener = false;
        }
      } else if (_forceEditForLargeFile &&
          !_isDirty &&
          !_isLoadingLargeFile &&
          _controller.text != noteContent) {
        _suppressListener = true;
        _controller.text = noteContent;
        _lastSeenText = noteContent;
        _suppressListener = false;
      }
    }

    final bgColor = theme.scaffoldBackgroundColor;
    return GestureDetector(
      onTap: () {
        ref.read(splitPaneProvider.notifier).setActiveLeaf(widget.leafId);
        ref.read(knowledgeProvider.notifier).setActiveNoteId(widget.noteId);
      },
      child: ColoredBox(
        color: bgColor,
        child: _buildBody(theme, noteContent, l),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, String noteContent, AppLocalizations l) {
    // For large files in edit mode, fall back to a fast source view with a
    // notice instead of freezing the UI on a RenderParagraph layout pass.
    // The user can click "Edit anyway" to force the edit mode (which uses
    // deferred loading), or switch to source/rendered view via the tab bar.
    if (widget.viewMode == NoteViewMode.edit &&
        noteContent.length > _largeFileThreshold &&
        !_forceEditForLargeFile) {
      return Column(
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSpacing.lg,
                vertical: DesignSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.largeFileSourceNotice,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _forceEditLargeFile,
                    child: Text(l.edit),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildSource(theme, noteContent)),
        ],
      );
    }
    // For large files in rendered mode, fall back to a fast source view
    // with a notice instead of freezing the UI on flutter_markdown's
    // whole-document AST parse + layout. The user can click "渲染" to
    // force rendered mode (which bypasses NoteMarkdownView's internal
    // guard via the forceRender flag).
    if (widget.viewMode == NoteViewMode.rendered &&
        noteContent.length > _largeFileThreshold &&
        !_forceRenderForLargeFile) {
      return Column(
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSpacing.lg,
                vertical: DesignSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.largeFileRenderNotice,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _forceRenderForLargeFile = true);
                    },
                    child: Text(l.render),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildSource(theme, noteContent)),
        ],
      );
    }
    switch (widget.viewMode) {
      case NoteViewMode.edit:
        return _buildEdit(theme, l);
      case NoteViewMode.source:
        return _buildSource(theme, noteContent);
      case NoteViewMode.rendered:
        // forceRender bypasses NoteMarkdownView's internal large-file guard
        // when the user has already opted in via the "渲染" button above.
        return NoteMarkdownView(
          content: noteContent,
          forceRender: _forceRenderForLargeFile,
        );
    }
  }

  void _forceEditLargeFile() {
    // Start deferred loading: show loading indicator first, then set the
    // text in a post-frame callback. The layout pass will still be slow,
    // but at least the user sees a loading indicator instead of a frozen
    // window, and they explicitly opted in.
    final noteContent = ref.read(
      knowledgeProvider.select((s) => s.byId[widget.noteId]?.content),
    );
    if (noteContent == null) return;
    setState(() {
      _forceEditForLargeFile = true;
      _isLoadingLargeFile = true;
    });
    final contentToLoad = noteContent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastLoadedNoteId != widget.noteId) {
        if (mounted) setState(() => _isLoadingLargeFile = false);
        return;
      }
      _suppressListener = true;
      _controller.text = contentToLoad;
      _lastSeenText = contentToLoad;
      _isDirty = false;
      _suppressListener = false;
      if (mounted) setState(() => _isLoadingLargeFile = false);
    });
  }

  Widget _buildEdit(ThemeData theme, AppLocalizations l) {
    if (_isLoadingLargeFile) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ExcludeSemantics：见 capture_ai_summary_build.dart 同类修复说明。
            // 大文件加载指示器，每帧更新 Semantics(value: '%')，包裹后排除。
            const ExcludeSemantics(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text(
              l.loading,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      );
    }
    final settings = ref.watch(settingsProvider);
    _controller.setTheme(theme);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DesignTypography.maxContentWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignSpacing.lg),
          child: TextField(
            controller: _controller,
            scrollController: _scrollController,
            focusNode: _focusNode,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: 'monospace',
              fontSize: settings.editorFontSize,
              height: 1.6,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: l.startWritingHint,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.hintColor,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSource(ThemeData theme, String noteContent) {
    final settings = ref.watch(settingsProvider);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontFamily: 'monospace',
      fontSize: settings.editorFontSize,
      height: 1.6,
    );
    // Lazy line-by-line rendering: only visible lines are built and laid
    // out. Previously, SelectableText rendered the entire document as one
    // RenderParagraph, which blocked the UI thread for seconds on large
    // files (>50KB). This is the same approach VSCode/Obsidian use — only
    // the viewport is materialized. Opening a 100,000-line file is now as
    // fast as opening a 100-line file.
    final lines = noteContent.split('\n');
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          return Text(lines[index], style: textStyle);
        },
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import '../../core/editor/highlighted_text_editing_controller.dart';
import '../../core/editor/sync_scroll_controller.dart';
import '../../core/ai/request_context.dart';
import '../../data/models/drag_data.dart';
import '../../services/knowledge_service.dart';
import '../../services/quick_move_service.dart';
import '../../services/settings_service.dart';
import '../../data/stores/vault_store.dart';
import '../../data/models/quick_move.dart';
import '../widgets/create_note_dialog.dart';
import '../widgets/note_markdown_view.dart';
import '../../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';

part 'editor/editor_header.dart';
part 'editor/editor_views.dart';
part 'editor/editor_original_view.dart';
part 'editor/editor_toolbar.dart';
part 'editor/editor_markdown.dart';

enum _EditorViewMode { edit, preview, split, original }

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

abstract class _EditorViewStateBase extends ConsumerState<EditorView> {
  final _controller = HighlightedTextEditingController();
  final _editorScrollController = ScrollController();
  final _previewScrollController = ScrollController();
  _EditorViewMode _viewMode = _EditorViewMode.edit;
  bool _isDirty = false;
  bool _isDragOver = false;
  bool _showSavedIndicator = false;
  String? _lastLoadedNoteId;
  final _dropHandler = DropHandler();
  SyncScrollController? _syncScrollController;
  Timer? _autoSaveTimer;
  Timer? _savedIndicatorTimer;
  Timer? _contentSyncTimer;
  // Last text observed when _onContentChanged fired. The controller's
  // notifyListeners() also fires when only the async markdown highlight
  // (TextSpan) updates — without this guard those no-op notifications
  // would mark the note dirty and schedule autosaves even though the
  // user never edited anything.
  String? _lastSeenText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onContentChanged);
    _syncScrollController = SyncScrollController(
      editorController: _editorScrollController,
      previewController: _previewScrollController,
    );
  }

  void _onContentChanged() {
    final currentText = _controller.text;
    if (_lastSeenText == currentText) {
      // Notification not triggered by a text change (e.g. async highlight
      // update or selection-only change). Skip dirty-marking and save
      // scheduling, but still refresh selection-dependent AI context.
      _pushSelectionToContext();
      return;
    }
    _lastSeenText = currentText;
    if (!_isDirty && _lastLoadedNoteId != null) {
      setState(() => _isDirty = true);
    }
    // Debounce the knowledge state update — previously this fired on every
    // keystroke, copying the entire notes list and triggering rebuilds of
    // all widgets watching knowledgeProvider (sidebar, backlinks, etc.).
    // A 400ms debounce keeps the UI responsive while still propagating
    // changes to backlinks/search quickly enough.
    _contentSyncTimer?.cancel();
    _contentSyncTimer = Timer(const Duration(milliseconds: 400), () {
      ref
          .read(knowledgeProvider.notifier)
          .updateActiveNoteContent(_controller.text);
    });
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      if (_isDirty) _saveNote();
    });
    _pushSelectionToContext();
  }

  void _pushSelectionToContext() {
    final notifier = ref.read(requestContextProvider.notifier);
    final sel = _controller.selection;
    if (!sel.isValid || sel.isCollapsed) {
      notifier.updateSelection(null);
      return;
    }
    final selectedText = sel.textInside(_controller.text);
    if (selectedText.trim().isEmpty) {
      notifier.updateSelection(null);
      return;
    }
    notifier.updateSelection(
      SelectionSnapshot(
        text: selectedText.length > 4000
            ? selectedText.substring(0, 4000)
            : selectedText,
        startOffset: sel.start,
        endOffset: sel.end,
      ),
    );
  }

  void _pushActiveNoteToContext(dynamic note) {
    final notifier = ref.read(requestContextProvider.notifier);
    if (note == null) {
      notifier.updateActiveNote(null);
      return;
    }
    notifier.updateActiveNote(
      ActiveNoteSnapshot(
        id: note.id as String,
        title: note.title as String,
        path: note.filePath as String?,
        tags: List<String>.from(note.tags as List<dynamic>),
      ),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _savedIndicatorTimer?.cancel();
    _contentSyncTimer?.cancel();
    _controller.removeListener(_onContentChanged);
    _syncScrollController?.detach();
    _controller.dispose();
    _editorScrollController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  int get _charCount => _controller.text.length;

  int get _wordCount {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    final cjk = RegExp(
      r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]',
    ).allMatches(text).length;
    final withoutCjk = text.replaceAll(
      RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]'),
      ' ',
    );
    final englishWords = withoutCjk
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return cjk + englishWords;
  }

  void _insertFormatting(
    String prefix,
    String suffix, [
    String placeholder = '',
  ]) {
    final text = _controller.text;
    final selection = _controller.selection;
    final selectedText = selection.textInside(text);
    final newText = selectedText.isEmpty ? placeholder : selectedText;
    final insert = '$prefix$newText$suffix';
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    _controller.text = text.substring(0, start) + insert + text.substring(end);
    if (selectedText.isEmpty && placeholder.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + placeholder.length,
      );
    } else {
      _controller.selection = TextSelection.collapsed(
        offset: start + insert.length,
      );
    }
  }

  void _insertLinePrefix(String prefix) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.start >= 0 ? selection.start : text.length;
    int lineStart = text.lastIndexOf('\n', cursorPos - 1) + 1;
    final lineEnd = text.indexOf('\n', cursorPos);
    final currentLine = text.substring(
      lineStart,
      lineEnd >= 0 ? lineEnd : text.length,
    );
    final stripped = currentLine.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    final newLine = '$prefix$stripped';
    _controller.text =
        text.substring(0, lineStart) +
        newLine +
        text.substring(lineEnd >= 0 ? lineEnd : text.length);
    _controller.selection = TextSelection.collapsed(
      offset: lineStart + newLine.length,
    );
  }

  void _cycleHeading() {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.start >= 0 ? selection.start : text.length;
    int lineStart = text.lastIndexOf('\n', cursorPos - 1) + 1;
    final lineEnd = text.indexOf('\n', cursorPos);
    final currentLine = text.substring(
      lineStart,
      lineEnd >= 0 ? lineEnd : text.length,
    );
    final match = RegExp(r'^(#{1,6})\s*').firstMatch(currentLine);
    int currentLevel = match != null ? match.group(1)!.length : 0;
    int nextLevel = currentLevel >= 6 ? 0 : currentLevel + 1;
    final stripped = currentLine.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    final newLine = nextLevel > 0 ? '${'#' * nextLevel} $stripped' : stripped;
    _controller.text =
        text.substring(0, lineStart) +
        newLine +
        text.substring(lineEnd >= 0 ? lineEnd : text.length);
    _controller.selection = TextSelection.collapsed(
      offset: lineStart + newLine.length,
    );
  }

  void _switchViewMode(_EditorViewMode mode) {
    setState(() {
      if (_viewMode == _EditorViewMode.split && mode != _EditorViewMode.split) {
        _syncScrollController?.detach();
      }
      _viewMode = mode;
      if (mode == _EditorViewMode.split) {
        _syncScrollController?.attach();
      }
    });
  }

  void _saveNote() {
    // Flush any pending debounced content sync so the knowledge service
    // has the latest text before saving to disk.
    _contentSyncTimer?.cancel();
    ref
        .read(knowledgeProvider.notifier)
        .updateActiveNoteContent(_controller.text);
    ref.read(knowledgeProvider.notifier).saveActiveNote();
    setState(() {
      _isDirty = false;
      _showSavedIndicator = true;
    });
    _savedIndicatorTimer?.cancel();
    _savedIndicatorTimer = Timer(DesignDuration.saveIndicator, () {
      if (mounted) {
        setState(() => _showSavedIndicator = false);
      }
    });
  }

  void _createNewNote() async {
    final title = await showCreateNoteDialog(context);
    if (title != null && title.isNotEmpty) {
      await ref.read(knowledgeProvider.notifier).createNote(title: title);
    }
  }

  void _updateContext(String content) {
    final selection = _controller.selection;
    String? selectedText;
    if (selection.isValid && !selection.isCollapsed) {
      selectedText = selection.textInside(content);
    }
    final ctx = QuickMoveContext(
      noteContent: content,
      selectedText: selectedText,
    );
    ref.read(quickMoveContextProvider.notifier).update(ctx);
  }

  // Abstract declarations for cross-mixin method calls.
  Widget _buildHeader(ThemeData theme, dynamic note, AppLocalizations l);
  Widget _buildFormatToolbar(ThemeData theme, AppLocalizations l);
  Widget _buildStatusBar(ThemeData theme, dynamic note, AppLocalizations l);
  Widget _buildEditor(ThemeData theme, Color bgColor, AppLocalizations l);
  Widget _buildSplitView(
    ThemeData theme,
    dynamic note,
    Color bgColor,
    AppLocalizations l,
  );
  Widget _buildMarkdownPreview(ThemeData theme, dynamic note, AppLocalizations l);
  Widget _buildOriginalView(
    ThemeData theme,
    dynamic note,
    Color bgColor,
    AppLocalizations l,
  );
  void _showScreenshot(dynamic note);

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    // Push active note to AI context — only when the active note actually
    // changes, not on every rebuild. (Previously this was a
    // addPostFrameCallback inside build() that fired on every rebuild.)
    ref.listen(knowledgeProvider.select((s) => s.activeNote), (_, note) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pushActiveNoteToContext(note);
      });
    });

    if (vaultState.currentVault == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.edit_note,
                size: 32,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(l.noVaultConnected, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(l.openVaultToStart, style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    final note = knowledgeState.activeNote;

    if (note == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 64, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(l.noNoteSelected, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(l.createOrSelectNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _createNewNote(),
              icon: const Icon(Icons.add),
              label: Text(l.newNote),
            ),
          ],
        ),
      );
    }

    // Load note content when switching to a different note.
    // This check ensures the callback is only scheduled once per note switch,
    // not on every rebuild.
    if (_lastLoadedNoteId != note.id) {
      _lastLoadedNoteId = note.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.text = note.content;
        if (_isDirty) {
          _isDirty = false;
        }
        _updateContext(note.content);
      });
    }

    final bgColor = theme.scaffoldBackgroundColor;

    return Column(
      children: [
        _buildHeader(theme, note, l),
        if (_viewMode == _EditorViewMode.edit ||
            _viewMode == _EditorViewMode.split)
          _buildFormatToolbar(theme, l),
        Expanded(
          child: ColoredBox(
            color: bgColor,
            child: _viewMode == _EditorViewMode.original
                ? _buildOriginalView(theme, note, bgColor, l)
                : _viewMode == _EditorViewMode.split
                ? _buildSplitView(theme, note, bgColor, l)
                : _viewMode == _EditorViewMode.preview
                ? _buildMarkdownPreview(theme, note, l)
                : _buildEditor(theme, bgColor, l),
          ),
        ),
        _buildStatusBar(theme, note, l),
      ],
    );
  }
}

class _EditorViewState extends _EditorViewStateBase
    with
        _EditorHeaderMixin,
        _EditorViewsMixin,
        _EditorOriginalViewMixin,
        _EditorToolbarMixin {}

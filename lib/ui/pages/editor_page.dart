import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../core/editor/highlighted_text_editing_controller.dart';
import '../../core/editor/sync_scroll_controller.dart';
import '../../data/models/drag_data.dart';
import '../../services/knowledge_service.dart';
import '../../services/quick_move_service.dart';
import '../../services/settings_service.dart';
import '../../data/stores/vault_store.dart';
import '../../data/models/quick_move.dart';
import '../widgets/create_note_dialog.dart';
import '../../l10n/app_localizations.dart';

enum _EditorViewMode { edit, preview, split }

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
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
    if (!_isDirty && _lastLoadedNoteId != null) {
      setState(() => _isDirty = true);
    }
    ref
        .read(knowledgeProvider.notifier)
        .updateActiveNoteContent(_controller.text);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      if (_isDirty) _saveNote();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _savedIndicatorTimer?.cancel();
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
    final cjk = RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]').allMatches(text).length;
    final withoutCjk = text.replaceAll(RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]'), ' ');
    final englishWords = withoutCjk.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return cjk + englishWords;
  }

  void _insertFormatting(String prefix, String suffix, [String placeholder = '']) {
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
    final currentLine = text.substring(lineStart, lineEnd >= 0 ? lineEnd : text.length);
    final stripped = currentLine.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    final newLine = '$prefix$stripped';
    _controller.text = text.substring(0, lineStart) + newLine + text.substring(lineEnd >= 0 ? lineEnd : text.length);
    _controller.selection = TextSelection.collapsed(offset: lineStart + newLine.length);
  }

  void _cycleHeading() {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.start >= 0 ? selection.start : text.length;
    int lineStart = text.lastIndexOf('\n', cursorPos - 1) + 1;
    final lineEnd = text.indexOf('\n', cursorPos);
    final currentLine = text.substring(lineStart, lineEnd >= 0 ? lineEnd : text.length);
    final match = RegExp(r'^(#{1,6})\s*').firstMatch(currentLine);
    int currentLevel = match != null ? match.group(1)!.length : 0;
    int nextLevel = currentLevel >= 6 ? 0 : currentLevel + 1;
    final stripped = currentLine.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    final newLine = nextLevel > 0 ? '${'#' * nextLevel} $stripped' : stripped;
    _controller.text = text.substring(0, lineStart) + newLine + text.substring(lineEnd >= 0 ? lineEnd : text.length);
    _controller.selection = TextSelection.collapsed(offset: lineStart + newLine.length);
  }

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

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
            Text(
              l.openVaultToStart,
              style: theme.textTheme.bodySmall,
            ),
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
            Text(
              l.createOrSelectNote,
              style: theme.textTheme.bodySmall,
            ),
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
        if (_viewMode == _EditorViewMode.edit || _viewMode == _EditorViewMode.split)
          _buildFormatToolbar(theme, l),
        Expanded(
          child: ColoredBox(
            color: bgColor,
            child: _viewMode == _EditorViewMode.split
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

  Widget _buildHeader(ThemeData theme, dynamic note, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.tags != null && note.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 4,
                      children: note.tags.take(5).map<Widget>((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '#$tag',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
          if (_isDirty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l.unsaved,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_showSavedIndicator)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 10, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(
                      l.saved,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SegmentedButton<_EditorViewMode>(
            segments: [
              ButtonSegment(value: _EditorViewMode.edit, label: Text(l.editMode), icon: Icon(Icons.edit, size: 14)),
              ButtonSegment(value: _EditorViewMode.preview, label: Text(l.previewMode), icon: Icon(Icons.visibility, size: 14)),
              ButtonSegment(value: _EditorViewMode.split, label: Text(l.splitView), icon: Icon(Icons.vertical_split, size: 14)),
            ],
            selected: {_viewMode},
            onSelectionChanged: (modes) => _switchViewMode(modes.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(theme.textTheme.labelSmall),
              padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.save, size: 16),
            onPressed: _isDirty ? _saveNote : null,
            tooltip: l.save,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
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

  Widget _buildFormatToolbar(ThemeData theme, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarBtn(theme, Icons.title, l.heading, _cycleHeading),
            _toolbarBtn(theme, Icons.format_bold, l.bold, () => _insertFormatting('**', '**', 'Bold text')),
            _toolbarBtn(theme, Icons.format_italic, l.italic, () => _insertFormatting('*', '*', 'Italic text')),
            _toolbarBtn(theme, Icons.strikethrough_s, l.strikethrough, () => _insertFormatting('~~', '~~', 'Struck text')),
            _toolbarDivider(theme),
            _toolbarBtn(theme, Icons.code, l.inlineCode, () => _insertFormatting('`', '`', 'code')),
            _toolbarBtn(theme, Icons.data_object, l.codeBlock, () => _insertFormatting('\n```\n', '\n```\n', 'code')),
            _toolbarDivider(theme),
            _toolbarBtn(theme, Icons.format_list_bulleted, l.bulletList, () => _insertLinePrefix('- ')),
            _toolbarBtn(theme, Icons.format_list_numbered, l.numberedList, () => _insertLinePrefix('1. ')),
            _toolbarBtn(theme, Icons.format_quote, l.quote, () => _insertLinePrefix('> ')),
            _toolbarBtn(theme, Icons.checklist, l.taskList, () => _insertLinePrefix('- [ ] ')),
            _toolbarDivider(theme),
            _toolbarBtn(theme, Icons.link, l.link, () => _insertFormatting('[', '](url)', 'link text')),
            _toolbarBtn(theme, Icons.add_link, l.wikiLink, () => _insertFormatting('[[', ']]', 'note title')),
            _toolbarBtn(theme, Icons.input, l.embedNote, () => _insertFormatting('![[', ']]', 'note title')),
            _toolbarDivider(theme),
            _toolbarBtn(theme, Icons.horizontal_rule, l.horizontalRule, () => _insertFormatting('\n---\n', '')),
            _toolbarBtn(theme, Icons.table_chart, l.table, () => _insertFormatting('\n| Col1 | Col2 | Col3 |\n| --- | --- | --- |\n| ', ' | content | content |\n')),
          ],
        ),
      ),
    );
  }

  Widget _toolbarBtn(ThemeData theme, IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 16, color: theme.hintColor),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      splashRadius: 14,
    );
  }

  Widget _toolbarDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: 1,
        height: 16,
        color: theme.dividerColor,
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, dynamic note, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 12, color: theme.hintColor),
          const SizedBox(width: 4),
          Text(
            note.filePath ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.hintColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            l.charCount(_charCount),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l.wordCount(_wordCount),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            _isDirty ? Icons.circle : Icons.check_circle_outline,
            size: 10,
            color: _isDirty ? theme.colorScheme.primary : Colors.green.shade600,
          ),
          const SizedBox(width: 3),
          Text(
            _isDirty ? l.hasUnsavedChanges : l.saved,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: _isDirty ? theme.colorScheme.primary : Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(ThemeData theme, Color bgColor, AppLocalizations l) {
    final settings = ref.watch(settingsProvider);
    return DragTarget<DragData>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isDragOver = true);
        return true;
      },
      onLeave: (data) {
        setState(() => _isDragOver = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        final markdown = _dropHandler.handle(details.data);
        final text = _controller.text;
        final selection = _controller.selection;
        final insertPos = selection.baseOffset.clamp(0, text.length);
        _controller.text = text.substring(0, insertPos) + markdown + text.substring(insertPos);
        _controller.selection = TextSelection.collapsed(offset: insertPos + markdown.length);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildHighlightedEditor(theme, settings, bgColor, l),
            ),
            if (_isDragOver)
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  child: Center(
                    child: Text(
                      l.dropHere,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHighlightedEditor(ThemeData theme, AppSettings settings, Color bgColor, AppLocalizations l) {
    _controller.setTheme(theme);
    return TextField(
      controller: _controller,
      scrollController: _editorScrollController,
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
        fillColor: bgColor,
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
    );
  }

  Widget _buildSplitView(ThemeData theme, dynamic note, Color bgColor, AppLocalizations l) {
    final settings = ref.watch(settingsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            color: bgColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                scrollController: _editorScrollController,
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
                  fillColor: bgColor,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: l.startWritingHint,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: _buildMarkdownPreview(theme, note, l)),
      ],
    );
  }

  Widget _buildMarkdownPreview(ThemeData theme, dynamic note, AppLocalizations l) {
    return Markdown(
      data: note.content,
      padding: const EdgeInsets.all(24),
      selectable: true,
      builders: {
        'wikilink': _WikiLinkBuilder(ref, theme),
        'embed': _EmbedBuilder(ref, theme, l),
      },
      extensionSet: _rfbrowserExtensionSet(),
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
        h1: theme.textTheme.headlineLarge,
        h2: theme.textTheme.headlineMedium,
        h3: theme.textTheme.headlineSmall,
        h4: theme.textTheme.titleLarge,
        h5: theme.textTheme.titleMedium,
        h6: theme.textTheme.titleSmall,
        code: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surface,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        blockquote: theme.textTheme.bodyLarge?.copyWith(
          color: theme.hintColor,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
        ),
        listBullet: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
        a: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _saveNote() {
    ref.read(knowledgeProvider.notifier).saveActiveNote();
    setState(() {
      _isDirty = false;
      _showSavedIndicator = true;
    });
    _savedIndicatorTimer?.cancel();
    _savedIndicatorTimer = Timer(const Duration(seconds: 2), () {
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
}

class _WikiLinkSyntax extends md.InlineSyntax {
  _WikiLinkSyntax()
    : super(r'\[\[([^\]#\|]+)(?:#([^\|\]]+))?(?:\|([^\]]+))?\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final target = match.group(1)?.trim() ?? '';
    final heading = match.group(2)?.trim();
    final alias = match.group(3)?.trim();
    final displayText = alias ?? target;

    final element = md.Element.text('wikilink', displayText);
    element.attributes['target'] = target;
    if (heading != null) element.attributes['heading'] = heading;
    parser.addNode(element);
    return true;
  }
}

class _EmbedSyntax extends md.InlineSyntax {
  _EmbedSyntax() : super(r'!\[\[([^\]#\|]+)(?:#([^\|\]]+))?\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final target = match.group(1)?.trim() ?? '';
    final heading = match.group(2)?.trim();

    final element = md.Element.text('embed', target);
    element.attributes['target'] = target;
    if (heading != null) element.attributes['heading'] = heading;
    parser.addNode(element);
    return true;
  }
}

class _WikiLinkBuilder extends MarkdownElementBuilder {
  final WidgetRef ref;
  final ThemeData theme;

  _WikiLinkBuilder(this.ref, this.theme);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final target = element.attributes['target'] ?? '';
    final displayText = element.textContent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final knowledge = ref.read(knowledgeProvider);
          final note = knowledge.notes.where((n) {
            return n.title.toLowerCase() == target.toLowerCase() ||
                n.aliases.any((a) => a.toLowerCase() == target.toLowerCase());
          }).firstOrNull;
          if (note != null) {
            ref.read(knowledgeProvider.notifier).openNote(note.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 2),
              Text(
                displayText,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmbedBuilder extends MarkdownElementBuilder {
  final WidgetRef ref;
  final ThemeData theme;
  final AppLocalizations l;

  _EmbedBuilder(this.ref, this.theme, this.l);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final target = element.attributes['target'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
        ),
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          children: [
            Icon(Icons.input, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.embedTarget(target),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String?>(
                    future: _getEmbedContent(target),
                    builder: (ctx, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final preview = snapshot.data!;
                        final truncated = preview.length > 200
                            ? '${preview.substring(0, 200)}...'
                            : preview;
                        return Text(
                          truncated,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      return Text(
                        l.loading,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getEmbedContent(String target) async {
    final knowledge = ref.read(knowledgeProvider);
    final note = knowledge.notes.where((n) {
      return n.title.toLowerCase() == target.toLowerCase() ||
          n.aliases.any((a) => a.toLowerCase() == target.toLowerCase());
    }).firstOrNull;
    return note?.content;
  }
}

md.ExtensionSet _rfbrowserExtensionSet() {
  return md.ExtensionSet(md.ExtensionSet.gitHubWeb.blockSyntaxes, [
    ...md.ExtensionSet.gitHubWeb.inlineSyntaxes,
    _WikiLinkSyntax(),
    _EmbedSyntax(),
  ]);
}

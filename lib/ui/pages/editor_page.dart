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

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  final _controller = HighlightedTextEditingController();
  final _editorScrollController = ScrollController();
  final _previewScrollController = ScrollController();
  bool _isPreview = false;
  bool _isSplitView = false;
  bool _isDirty = false;
  bool _isDragOver = false;
  String? _lastLoadedNoteId;
  final _dropHandler = DropHandler();
  SyncScrollController? _syncScrollController;

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
  }

  @override
  void dispose() {
    _controller.removeListener(_onContentChanged);
    _syncScrollController?.detach();
    _controller.dispose();
    _editorScrollController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);

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
            Text('No Vault Connected', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Open a vault to start writing notes',
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
            Text('No note selected', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Create a new note or select one from the sidebar',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _createNewNote(),
              icon: const Icon(Icons.add),
              label: const Text('New Note'),
            ),
          ],
        ),
      );
    }

    if (_lastLoadedNoteId != note.id) {
      _controller.text = note.content;
      _lastLoadedNoteId = note.id;
      if (_isDirty) {
        _isDirty = false;
      }
      _updateContext(note.content);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  note.title,
                  style: theme.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isDirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(
                  _isSplitView
                      ? Icons.vertical_split
                      : _isPreview
                          ? Icons.edit
                          : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => setState(() {
                  if (_isSplitView) {
                    _isSplitView = false;
                    _isPreview = false;
                    _syncScrollController?.detach();
                  } else if (_isPreview) {
                    _isPreview = false;
                    _isSplitView = true;
                    _syncScrollController?.attach();
                  } else {
                    _isPreview = true;
                  }
                }),
                tooltip: _isSplitView
                    ? 'Edit'
                    : _isPreview
                        ? 'Edit'
                        : 'Split View',
              ),
              IconButton(
                icon: const Icon(Icons.save, size: 18),
                onPressed: _saveNote,
                tooltip: 'Save',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isSplitView
              ? _buildSplitView(theme, note)
              : _isPreview
                  ? _buildMarkdownPreview(theme, note)
                  : _buildEditor(theme),
        ),
      ],
    );
  }

  Widget _buildEditor(ThemeData theme) {
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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: _isDragOver
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildHighlightedEditor(theme, settings),
              ),
              if (_isDragOver)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'Drop here',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighlightedEditor(ThemeData theme, AppSettings settings) {
    _controller.setTheme(theme);
    return TextField(
      controller: _controller,
      scrollController: _editorScrollController,
      maxLines: null,
      expands: true,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontFamily: 'monospace',
        fontSize: settings.editorFontSize,
        height: 1.6,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Start writing... Use [[link]] to link notes',
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.hintColor,
        ),
      ),
    );
  }

  Widget _buildSplitView(ThemeData theme, dynamic note) {
    final settings = ref.watch(settingsProvider);
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildHighlightedEditor(theme, settings),
            ),
          ),
        ),
        Expanded(
          child: _buildMarkdownPreview(theme, note),
        ),
      ],
    );
  }

  Widget _buildMarkdownPreview(ThemeData theme, dynamic note) {
    return Markdown(
      data: note.content,
      padding: const EdgeInsets.all(24),
      selectable: true,
      builders: {
        'wikilink': _WikiLinkBuilder(ref, theme),
        'embed': _EmbedBuilder(ref, theme),
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
    setState(() => _isDirty = false);
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
            ref.read(knowledgeProvider.notifier).openNote(note.filePath);
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

  _EmbedBuilder(this.ref, this.theme);

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
                    'Embed: $target',
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
                        'Loading...',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../../services/settings_service.dart';
import '../theme/design_tokens.dart';

/// Cache the extension set — it's immutable and never changes, so creating
/// it once avoids allocating new syntax regex objects on every build.
final _cachedExtensionSet = md.ExtensionSet(
  md.ExtensionSet.gitHubWeb.blockSyntaxes,
  [
    ...md.ExtensionSet.gitHubWeb.inlineSyntaxes,
    WikiLinkSyntax(),
    EmbedSyntax(),
  ],
);

/// Public, reusable markdown renderer for notes. Supports wikilinks and
/// embeds the same way the editor's preview does, so it can be shared
/// between the single-note editor and the multi-pane split views.
///
/// Converted to [ConsumerStatefulWidget] so the style sheet and builders
/// are cached across rebuilds — only re-created when the theme actually
/// changes. This avoids re-parsing overhead when switching view modes.
class NoteMarkdownView extends ConsumerStatefulWidget {
  final String content;
  final EdgeInsets padding;
  final bool selectable;

  /// When true, skips the internal large-file guard (the caller has already
  /// handled the fallback). Used by note_pane_view's rendered branch, which
  /// has its own notice bar + "渲染" button — without this, NoteMarkdownView
  /// would show a second notice on top of the caller's.
  final bool forceRender;

  const NoteMarkdownView({
    super.key,
    required this.content,
    this.padding = const EdgeInsets.all(DesignSpacing.xl),
    this.selectable = true,
    this.forceRender = false,
  });

  @override
  ConsumerState<NoteMarkdownView> createState() => _NoteMarkdownViewState();
}

class _NoteMarkdownViewState extends ConsumerState<NoteMarkdownView> {
  // Above this size, rendering via flutter_markdown is skipped because it
  // parses the entire document into an AST and lays out all nodes at once,
  // freezing the UI thread for seconds. Instead, a fast Source view
  // (SelectionArea + ListView.builder) is shown with a notice bar offering
  // a "渲染" button to manually enter rendered mode. Mirrors the same
  // threshold/pattern used by note_pane_view.dart for Edit mode.
  static const _largeFileThreshold = 20000; // ~20KB

  MarkdownStyleSheet? _cachedStyleSheet;
  ThemeData? _cachedThemeForStyleSheet;
  Map<String, MarkdownElementBuilder>? _cachedBuilders;
  ThemeData? _cachedThemeForBuilders;
  AppLocalizations? _cachedL10nForBuilders;
  // Set to true when the user explicitly clicks "渲染" on the large-file
  // notice. While true, the build skips the source-view fallback and
  // renders via flutter_markdown (which may be slow, but the user opted in).
  // Reset whenever the displayed content changes.
  bool _forceRenderForLargeFile = false;

  @override
  void didUpdateWidget(covariant NoteMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _forceRenderForLargeFile = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    // Cache style sheet — only rebuild when theme identity changes.
    if (_cachedStyleSheet == null ||
        !identical(_cachedThemeForStyleSheet, theme)) {
      _cachedStyleSheet = noteMarkdownStyleSheet(theme);
      _cachedThemeForStyleSheet = theme;
    }

    // Cache builders — only rebuild when theme or l10n identity changes.
    if (_cachedBuilders == null ||
        !identical(_cachedThemeForBuilders, theme) ||
        !identical(_cachedL10nForBuilders, l)) {
      _cachedBuilders = {
        'wikilink': WikiLinkBuilder(ref, theme),
        'embed': EmbedBuilder(ref, theme, l),
      };
      _cachedThemeForBuilders = theme;
      _cachedL10nForBuilders = l;
    }

    // Large file guard: flutter_markdown parses the whole doc into an AST
    // and lays out all nodes at once, freezing the UI for >20KB notes.
    // Fall back to a fast Source view (viewport-based lazy rendering) with
    // a notice bar; the user can click "渲染" to force rendered mode.
    if (widget.content.length > _largeFileThreshold &&
        !_forceRenderForLargeFile &&
        !widget.forceRender) {
      return Column(
        children: [
          _buildLargeFileNotice(theme, l),
          Expanded(child: _buildSource(theme)),
        ],
      );
    }

    return RepaintBoundary(
      // ExcludeSemantics: The Markdown widget generates a large number of
      // semantic nodes (one per text element). When note content changes,
      // all these nodes are removed and recreated, which triggers
      // "Failed to update ui::AXTree" errors on Windows desktop. The editor's
      // TextField already provides full accessibility for the content; the
      // preview pane is for visual reading only.
      child: ExcludeSemantics(
        child: Markdown(
          data: widget.content,
          padding: widget.padding,
          selectable: widget.selectable,
          builders: _cachedBuilders!,
          extensionSet: _cachedExtensionSet,
          styleSheet: _cachedStyleSheet!,
        ),
      ),
    );
  }

  Widget _buildLargeFileNotice(ThemeData theme, AppLocalizations l) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
    );
  }

  Widget _buildSource(ThemeData theme) {
    final settings = ref.watch(settingsProvider);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontFamily: 'monospace',
      fontSize: settings.editorFontSize,
      height: 1.6,
    );
    // Lazy line-by-line rendering: only visible lines are built and laid
    // out. This is the same pattern used by note_pane_view's Source view,
    // so a 100,000-line file opens as fast as a 100-line file.
    final lines = widget.content.split('\n');
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

MarkdownStyleSheet noteMarkdownStyleSheet(ThemeData theme) {
  return MarkdownStyleSheet(
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
  );
}

class WikiLinkSyntax extends md.InlineSyntax {
  WikiLinkSyntax()
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

class EmbedSyntax extends md.InlineSyntax {
  EmbedSyntax() : super(r'!\[\[([^\]#\|]+)(?:#([^\|\]]+))?\]\]');

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

class WikiLinkBuilder extends MarkdownElementBuilder {
  final WidgetRef ref;
  final ThemeData theme;

  WikiLinkBuilder(this.ref, this.theme);

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
          // O(1) lookup via byTitleLower (covers both title and aliases).
          final note = knowledge.byTitleLower[target.toLowerCase()];
          if (note != null) {
            ref.read(knowledgeProvider.notifier).openNote(note.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.xs,
            vertical: 1,
          ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmbedBuilder extends MarkdownElementBuilder {
  final WidgetRef ref;
  final ThemeData theme;
  final AppLocalizations l;

  EmbedBuilder(this.ref, this.theme, this.l);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final target = element.attributes['target'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: DesignSpacing.sm),
      padding: const EdgeInsets.all(DesignSpacing.md),
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
    // O(1) lookup via byTitleLower (covers both title and aliases).
    final note = knowledge.byTitleLower[target.toLowerCase()];
    return note?.content;
  }
}

md.ExtensionSet rfbrowserExtensionSet() => _cachedExtensionSet;

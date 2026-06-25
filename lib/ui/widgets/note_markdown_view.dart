import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
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

  const NoteMarkdownView({
    super.key,
    required this.content,
    this.padding = const EdgeInsets.all(DesignSpacing.xl),
    this.selectable = true,
  });

  @override
  ConsumerState<NoteMarkdownView> createState() => _NoteMarkdownViewState();
}

class _NoteMarkdownViewState extends ConsumerState<NoteMarkdownView> {
  MarkdownStyleSheet? _cachedStyleSheet;
  ThemeData? _cachedThemeForStyleSheet;
  Map<String, MarkdownElementBuilder>? _cachedBuilders;
  ThemeData? _cachedThemeForBuilders;
  AppLocalizations? _cachedL10nForBuilders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    // Cache style sheet — only rebuild when theme identity changes.
    if (_cachedStyleSheet == null || !identical(_cachedThemeForStyleSheet, theme)) {
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
          final note = knowledge.notes.where((n) {
            return n.title.toLowerCase() == target.toLowerCase() ||
                n.aliases.any((a) => a.toLowerCase() == target.toLowerCase());
          }).firstOrNull;
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
    final note = knowledge.notes.where((n) {
      return n.title.toLowerCase() == target.toLowerCase() ||
          n.aliases.any((a) => a.toLowerCase() == target.toLowerCase());
    }).firstOrNull;
    return note?.content;
  }
}

md.ExtensionSet rfbrowserExtensionSet() => _cachedExtensionSet;

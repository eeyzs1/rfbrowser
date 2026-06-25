// ignore_for_file: unused_element, unused_element_parameter

part of '../editor_page.dart';

mixin _EditorToolbarMixin on _EditorViewStateBase {
  @override
  Widget _buildFormatToolbar(ThemeData theme, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.sm,
        vertical: DesignSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarBtn(theme, Icons.title, l.heading, _cycleHeading),
            _toolbarBtn(
              theme,
              Icons.format_bold,
              l.bold,
              () => _insertFormatting('**', '**', 'Bold text'),
            ),
            _toolbarBtn(
              theme,
              Icons.format_italic,
              l.italic,
              () => _insertFormatting('*', '*', 'Italic text'),
            ),
            _toolbarBtn(
              theme,
              Icons.strikethrough_s,
              l.strikethrough,
              () => _insertFormatting('~~', '~~', 'Struck text'),
            ),
            _toolbarDivider(theme),
            _toolbarBtn(
              theme,
              Icons.code,
              l.inlineCode,
              () => _insertFormatting('`', '`', 'code'),
            ),
            _toolbarBtn(
              theme,
              Icons.data_object,
              l.codeBlock,
              () => _insertFormatting('\n```\n', '\n```\n', 'code'),
            ),
            _toolbarDivider(theme),
            _toolbarBtn(
              theme,
              Icons.format_list_bulleted,
              l.bulletList,
              () => _insertLinePrefix('- '),
            ),
            _toolbarBtn(
              theme,
              Icons.format_list_numbered,
              l.numberedList,
              () => _insertLinePrefix('1. '),
            ),
            _toolbarBtn(
              theme,
              Icons.format_quote,
              l.quote,
              () => _insertLinePrefix('> '),
            ),
            _toolbarBtn(
              theme,
              Icons.checklist,
              l.taskList,
              () => _insertLinePrefix('- [ ] '),
            ),
            _toolbarDivider(theme),
            _toolbarBtn(
              theme,
              Icons.link,
              l.link,
              () => _insertFormatting('[', '](url)', 'link text'),
            ),
            _toolbarBtn(
              theme,
              Icons.add_link,
              l.wikiLink,
              () => _insertFormatting('[[', ']]', 'note title'),
            ),
            _toolbarBtn(
              theme,
              Icons.input,
              l.embedNote,
              () => _insertFormatting('![[', ']]', 'note title'),
            ),
            _toolbarDivider(theme),
            _toolbarBtn(
              theme,
              Icons.horizontal_rule,
              l.horizontalRule,
              () => _insertFormatting('\n---\n', ''),
            ),
            _toolbarBtn(
              theme,
              Icons.table_chart,
              l.table,
              () => _insertFormatting(
                '\n| Col1 | Col2 | Col3 |\n| --- | --- | --- |\n| ',
                ' | content | content |\n',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarBtn(
    ThemeData theme,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 16, color: theme.hintColor),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.xs),
      constraints: const BoxConstraints(
        minWidth: DesignTouchTarget.iconButtonSize,
        minHeight: DesignTouchTarget.iconButtonSize,
      ),
    );
  }

  Widget _toolbarDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.xs),
      child: Container(width: 1, height: 16, color: theme.dividerColor),
    );
  }

  @override
  Widget _buildStatusBar(ThemeData theme, dynamic note, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.md,
        vertical: DesignSpacing.xs - 1,
      ),
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
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            l.charCount(_charCount),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(width: 12),
          Text(
            l.wordCount(_wordCount),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(width: 12),
          Icon(
            _isDirty ? Icons.circle : Icons.check_circle_outline,
            size: 10,
            color: _isDirty
                ? DesignColors.semanticWarning
                : DesignColors.semanticSuccess,
          ),
          const SizedBox(width: 3),
          Text(
            _isDirty ? l.hasUnsavedChanges : l.saved,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _isDirty
                  ? DesignColors.semanticWarning
                  : DesignColors.semanticSuccess,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: unused_element, unused_element_parameter

part of '../editor_page.dart';

mixin _EditorViewsMixin on _EditorViewStateBase {
  @override
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
        _controller.text =
            text.substring(0, insertPos) + markdown + text.substring(insertPos);
        _controller.selection = TextSelection.collapsed(
          offset: insertPos + markdown.length,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: DesignTypography.maxContentWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(DesignSpacing.lg),
                    child: _buildHighlightedEditor(theme, settings, bgColor, l),
                  ),
                ),
              ),
              if (_isDragOver)
                Positioned.fill(
                  child: Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    child: Center(
                      child: Text(
                        l.dropHere,
                        style: TextStyle(
                          color: theme.hintColor,
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

  Widget _buildHighlightedEditor(
    ThemeData theme,
    AppSettings settings,
    Color bgColor,
    AppLocalizations l,
  ) {
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
        hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget _buildSplitView(
    ThemeData theme,
    dynamic note,
    Color bgColor,
    AppLocalizations l,
  ) {
    final settings = ref.watch(settingsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            color: bgColor,
            child: Padding(
              padding: const EdgeInsets.all(DesignSpacing.lg),
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
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor,
                  ),
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

  @override
  Widget _buildMarkdownPreview(
    ThemeData theme,
    dynamic note,
    AppLocalizations l,
  ) {
    return RepaintBoundary(
      child: NoteMarkdownView(content: note.content as String),
    );
  }
}

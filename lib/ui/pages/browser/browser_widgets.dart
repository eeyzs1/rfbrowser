// ignore_for_file: unused_element, unused_element_parameter

part of '../browser_page.dart';

class _ClosedTabInfo {
  final String id;
  final String url;
  final String title;
  final String? groupId;
  _ClosedTabInfo({
    required this.id,
    required this.url,
    required this.title,
    this.groupId,
  });
}

class _BookmarkDialogResult {
  final String selectedFolderId;
  final String editedTitle;
  final String? newFolderName;
  _BookmarkDialogResult({
    required this.selectedFolderId,
    required this.editedTitle,
    this.newFolderName,
  });
}

class _ClipDialogResult {
  final String format;
  final String editedTitle;
  _ClipDialogResult({required this.format, required this.editedTitle});
}

class _ClipDialog extends StatefulWidget {
  final BrowserTab tab;
  final AppLocalizations l;
  const _ClipDialog({required this.tab, required this.l});

  @override
  State<_ClipDialog> createState() => _ClipDialogState();
}

class _ClipDialogState extends State<_ClipDialog> {
  String _format = 'markdown';
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.tab.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.l;
    return AlertDialog(
      title: Text(l.clipPage),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bookmarkTitle, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _titleController,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.clipFormat, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'markdown', label: Text(l.formatMarkdown)),
              ButtonSegment(value: 'html', label: Text(l.formatHtml)),
              ButtonSegment(value: 'text', label: Text(l.formatPlainText)),
            ],
            selected: {_format},
            onSelectionChanged: (v) => setState(() => _format = v.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ClipDialogResult(
              format: _format,
              editedTitle: _titleController.text.isNotEmpty
                  ? _titleController.text
                  : widget.tab.title,
            ),
          ),
          child: Text(l.clipPage),
        ),
      ],
    );
  }
}

class _LinuxBrowserPlaceholder extends StatefulWidget {
  final BrowserTab tab;
  final VoidCallback onOpenExternal;
  final ValueChanged<String> onNavigate;
  final VoidCallback onClip;

  const _LinuxBrowserPlaceholder({
    required this.tab,
    required this.onOpenExternal,
    required this.onNavigate,
    required this.onClip,
  });

  @override
  State<_LinuxBrowserPlaceholder> createState() =>
      _LinuxBrowserPlaceholderState();
}

class _LinuxBrowserPlaceholderState extends State<_LinuxBrowserPlaceholder> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.tab.url);
  }

  @override
  void didUpdateWidget(covariant _LinuxBrowserPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab.url != widget.tab.url) {
      _urlController.text = widget.tab.url;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.open_in_browser_outlined,
            size: 48,
            color: theme.hintColor,
          ),
          const SizedBox(height: 16),
          Text(
            l?.searchEngineBing ?? 'Embedded browser is not available on Linux',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 500,
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: l?.searchOrEnterUrl ?? 'Enter URL',
                prefixIcon: const Icon(Icons.language_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_outlined),
                  onPressed: () => widget.onNavigate(_urlController.text),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: widget.onNavigate,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: widget.onOpenExternal,
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(l?.openInBrowser ?? 'Open in System Browser'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onClip,
                icon: const Icon(Icons.content_cut_outlined),
                label: Text(l?.clipPage ?? 'Clip Page to Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddBookmarkDialog extends StatefulWidget {
  final List<BookmarkFolder> folders;
  final String pageTitle;
  final String pageUrl;
  final AppLocalizations l;

  const _AddBookmarkDialog({
    required this.folders,
    required this.pageTitle,
    required this.pageUrl,
    required this.l,
  });

  @override
  State<_AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<_AddBookmarkDialog> {
  String _selectedFolderId = 'bookmarks-bar';
  late TextEditingController _titleController;
  bool _showNewFolder = false;
  final _newFolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.pageTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _newFolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.l;
    return AlertDialog(
      title: Text(l.addBookmark),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bookmarkTitle, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          TextField(
            controller: _titleController,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.pageUrl,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Text(l.bookmarkTo, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _selectedFolderId,
            onChanged: (String? value) {
              if (value != null) setState(() => _selectedFolderId = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.folders
                  .map(
                    (f) => ListTile(
                      leading: Icon(
                        f.isExpanded
                            ? Icons.folder_open_outlined
                            : Icons.folder_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(f.name),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      trailing: Radio<String>(value: f.id),
                      onTap: () => setState(() => _selectedFolderId = f.id),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (!_showNewFolder)
            TextButton.icon(
              onPressed: () => setState(() => _showNewFolder = true),
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              label: Text(l.newFolder),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFolderController,
                    decoration: InputDecoration(
                      hintText: l.folderName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    autofocus: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check_outlined, size: 16),
                  onPressed: () {
                    if (_newFolderController.text.isNotEmpty) {
                      Navigator.pop(
                        context,
                        _BookmarkDialogResult(
                          selectedFolderId: '',
                          editedTitle: _titleController.text.isNotEmpty
                              ? _titleController.text
                              : widget.pageTitle,
                          newFolderName: _newFolderController.text,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _BookmarkDialogResult(
              selectedFolderId: _selectedFolderId,
              editedTitle: _titleController.text.isNotEmpty
                  ? _titleController.text
                  : widget.pageTitle,
            ),
          ),
          child: Text(l.bookmark),
        ),
      ],
    );
  }
}

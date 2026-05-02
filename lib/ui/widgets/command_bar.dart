import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/knowledge_service.dart';

class CommandBar extends ConsumerStatefulWidget {
  final ValueChanged<String> onCommand;
  final VoidCallback onClose;

  const CommandBar({super.key, required this.onCommand, required this.onClose});

  @override
  ConsumerState<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends ConsumerState<CommandBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<_SearchResult> _results = [];
  bool _isSearching = false;
  int _selectedIndex = 0;

  static const _commands = [
    _CommandDef('New Note', Icons.add, 'note'),
    _CommandDef('New Tab', Icons.language, 'tab'),
    _CommandDef('Open Daily Note', Icons.today, 'daily'),
    _CommandDef('Toggle Theme', Icons.dark_mode, 'theme'),
    _CommandDef('Settings', Icons.settings, 'settings'),
    _CommandDef('Graph View', Icons.hub, 'graph'),
    _CommandDef('Canvas View', Icons.dashboard, 'canvas'),
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _selectedIndex = 0;
      });
      return;
    }

    setState(() => _isSearching = true);
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    await ref.read(knowledgeProvider.notifier).search(query);
    if (!mounted) return;
    final knowledge = ref.read(knowledgeProvider);
    final notes = knowledge.notes;
    final results = <_SearchResult>[];

    for (final result in knowledge.searchResults) {
      final noteId = result['id'] as String? ?? '';
      final title = result['title'] as String? ?? '';
      final filePath = result['file_path'] as String? ?? '';
      final note = notes.where((n) => n.id == noteId).firstOrNull;
      results.add(_SearchResult(
        title: title,
        filePath: filePath,
        tags: note?.tags ?? [],
        sourceUrl: note?.sourceUrl,
      ));
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
        _selectedIndex = 0;
      });
    }
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_results.isNotEmpty && _selectedIndex < _results.length) {
      ref.read(knowledgeProvider.notifier).openNote(_results[_selectedIndex].filePath);
      widget.onClose();
      return;
    }

    final matchingCommand = _commands.where(
      (c) => c.label.toLowerCase().contains(text.toLowerCase()),
    );
    if (matchingCommand.length == 1) {
      widget.onCommand(matchingCommand.first.label);
      return;
    }

    widget.onCommand(text);
    widget.onClose();
  }

  void _selectItem(int index) {
    final totalItems = _commandResults.length + _results.length;
    if (index < 0 || index >= totalItems) return;
    setState(() => _selectedIndex = index);

    if (index < _commandResults.length) {
      widget.onCommand(_commandResults[index].label);
      widget.onClose();
    } else {
      final resultIndex = index - _commandResults.length;
      ref.read(knowledgeProvider.notifier).openNote(_results[resultIndex].filePath);
      widget.onClose();
    }
  }

  List<_CommandDef> get _commandResults {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return _commands;
    return _commands.where((c) => c.label.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commands = _commandResults;
    final showCommands = _controller.text.trim().isEmpty || commands.isNotEmpty;

    return Center(
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 480),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search notes, commands...',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      onSubmitted: (_) => _handleSubmit(),
                    ),
                  ),
                  if (_isSearching)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: (showCommands ? commands.length : 0) + _results.length,
                itemBuilder: (context, index) {
                  if (showCommands && index < commands.length) {
                    final cmd = commands[index];
                    final globalIndex = index;
                    return _buildCommandTile(
                      theme,
                      cmd,
                      globalIndex == _selectedIndex,
                      () => _selectItem(globalIndex),
                    );
                  }
                  final resultIndex = showCommands ? index - commands.length : index;
                  final globalIndex = index;
                  if (resultIndex < _results.length) {
                    final result = _results[resultIndex];
                    return _buildNoteTile(
                      theme,
                      result,
                      globalIndex == _selectedIndex,
                      () => _selectItem(globalIndex),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandTile(
    ThemeData theme,
    _CommandDef cmd,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      leading: Icon(cmd.icon, size: 16, color: theme.hintColor),
      title: Text(cmd.label, style: theme.textTheme.bodyMedium),
      trailing: Text(
        'Command',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.hintColor,
          fontSize: 10,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildNoteTile(
    ThemeData theme,
    _SearchResult result,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      leading: Icon(Icons.description, size: 16, color: theme.colorScheme.primary),
      title: Row(
        children: [
          Expanded(
            child: Text(
              result.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: result.tags.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 4,
                children: result.tags.take(3).map((tag) => Text(
                  '#$tag',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                  ),
                )).toList(),
              ),
            )
          : null,
      trailing: result.sourceUrl != null
          ? Icon(Icons.language, size: 12, color: theme.hintColor)
          : null,
      onTap: onTap,
    );
  }
}

class _CommandDef {
  final String label;
  final IconData icon;
  final String category;
  const _CommandDef(this.label, this.icon, this.category);
}

class _SearchResult {
  final String title;
  final String filePath;
  final List<String> tags;
  final String? sourceUrl;
  const _SearchResult({
    required this.title,
    required this.filePath,
    this.tags = const [],
    this.sourceUrl,
  });
}

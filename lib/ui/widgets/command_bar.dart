import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/embedding_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/quick_move_service.dart';
import '../../data/models/quick_move.dart';
import 'create_quick_move_dialog.dart';

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
  List<QuickMove> _quickMoves = [];
  bool _isSearching = false;
  bool _isQuickMoveMode = false;
  int _selectedIndex = 0;
  Timer? _debounceTimer;

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
    _debounceTimer?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isSlashMode => _controller.text.trim().startsWith('/');

  String get _slashQuery {
    final text = _controller.text.trim();
    if (!text.startsWith('/')) return '';
    return text.substring(1);
  }

  void _onQueryChanged() {
    _debounceTimer?.cancel();
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _quickMoves = [];
        _isSearching = false;
        _isQuickMoveMode = false;
        _selectedIndex = 0;
      });
      return;
    }

    if (_isSlashMode) {
      _updateQuickMoves();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _isSearching = true);
      _performSearch(query);
    });
  }

  void _updateQuickMoves() {
    final quickMoveState = ref.read(quickMoveProvider);
    final prefix = _slashQuery.split(' ').first;
    final matches = quickMoveState.matching(prefix);

    setState(() {
      _quickMoves = matches;
      _results = [];
      _isQuickMoveMode = true;
      _isSearching = false;
      _selectedIndex = 0;
    });
  }

  Future<void> _performSearch(String query) async {
    final hybridSearch = ref.read(hybridSearchProvider);
    final hybridResults = await hybridSearch.search(query);
    if (!mounted) return;

    final knowledge = ref.read(knowledgeProvider);
    final notes = knowledge.notes;
    final results = <_SearchResult>[];

    for (final hr in hybridResults) {
      final note = notes.where((n) => n.id == hr.id).firstOrNull;
      final title = (hr.metadata['title'] as String?) ?? note?.title ?? '';
      final filePath =
          (hr.metadata['file_path'] as String?) ?? note?.filePath ?? '';
      results.add(
        _SearchResult(
          title: title,
          filePath: filePath,
          tags: note?.tags ?? [],
          sourceUrl: note?.sourceUrl,
          source: hr.source,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _results = results;
        _quickMoves = [];
        _isQuickMoveMode = false;
        _isSearching = false;
        _selectedIndex = 0;
      });
    }
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_isQuickMoveMode) {
      if (_quickMoves.isNotEmpty && _selectedIndex < _quickMoves.length) {
        final move = _quickMoves[_selectedIndex];
        _selectQuickMove(move);
        return;
      }

      if (_quickMoves.isEmpty) {
        final cmdName = _slashQuery.split(' ').first;
        if (cmdName.isNotEmpty) {
          _promptCreateQuickMove(cmdName);
          return;
        }
      }

      widget.onCommand(text);
      widget.onClose();
      return;
    }

    if (_results.isNotEmpty && _selectedIndex < _results.length) {
      ref
          .read(knowledgeProvider.notifier)
          .openNote(_results[_selectedIndex].filePath);
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

  void _selectQuickMove(QuickMove move) {
    _controller.text = '/${move.name} ';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _updateQuickMoves();
    _focusNode.requestFocus();
  }

  void _promptCreateQuickMove(String cmdName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('命令不存在'),
        content: Text('命令 "/$cmdName" 不存在，是否创建？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateQuickMoveDialog(cmdName);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showCreateQuickMoveDialog(String cmdName) {
    showCreateQuickMoveDialog(
      context,
      ref,
      prefillName: cmdName,
    );
  }

  void _selectItem(int index) {
    if (_isQuickMoveMode) {
      if (index < _quickMoves.length) {
        final move = _quickMoves[index];
        _selectQuickMove(move);
      }
      return;
    }

    final totalItems = _commandResults.length + _results.length;
    if (index < 0 || index >= totalItems) return;
    setState(() => _selectedIndex = index);

    if (index < _commandResults.length) {
      widget.onCommand(_commandResults[index].label);
      widget.onClose();
    } else {
      final resultIndex = index - _commandResults.length;
      ref
          .read(knowledgeProvider.notifier)
          .openNote(_results[resultIndex].filePath);
      widget.onClose();
    }
  }

  List<_CommandDef> get _commandResults {
    if (_isQuickMoveMode) return [];
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return _commands;
    return _commands
        .where((c) => c.label.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commands = _commandResults;
    final showCommands =
        !_isQuickMoveMode && (_controller.text.trim().isEmpty || commands.isNotEmpty);

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
                    _isQuickMoveMode ? Icons.bolt : Icons.search,
                    color: _isQuickMoveMode
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration.collapsed(
                        hintText: _isQuickMoveMode
                            ? 'Quick Move — type command name...'
                            : 'Search notes, commands...',
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
                itemCount: _isQuickMoveMode
                    ? _quickMoves.length
                    : (showCommands ? commands.length : 0) + _results.length,
                itemBuilder: (context, index) {
                  if (_isQuickMoveMode) {
                    final move = _quickMoves[index];
                    return _buildQuickMoveTile(
                      theme,
                      move,
                      index == _selectedIndex,
                      () {
                        setState(() => _selectedIndex = index);
                        _selectQuickMove(move);
                      },
                    );
                  }
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
                  final resultIndex =
                      showCommands ? index - commands.length : index;
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

  Widget _buildQuickMoveTile(
    ThemeData theme,
    QuickMove move,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      leading: Icon(
        move.icon,
        size: 16,
        color: move.color,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '/${move.name}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: move.promptTemplate.length > 60
          ? Text(
              '${move.promptTemplate.substring(0, 60)}...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        move.type == QuickMoveType.preset ? 'Preset' : 'Quick Move',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.hintColor,
          fontSize: 10,
        ),
      ),
      onTap: onTap,
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
      leading: Icon(
        Icons.description,
        size: 16,
        color: theme.colorScheme.primary,
      ),
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
                children: result.tags
                    .take(3)
                    .map(
                      (tag) => Text(
                        '#$tag',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.source.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                result.source == 'semantic' ? 'semantic' : 'keyword',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (result.sourceUrl != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.language, size: 12, color: theme.hintColor),
          ],
        ],
      ),
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
  final String source;
  const _SearchResult({
    required this.title,
    required this.filePath,
    this.tags = const [],
    this.sourceUrl,
    this.source = '',
  });
}

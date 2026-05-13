import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/embedding_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/quick_move_service.dart';
import '../../data/models/quick_move.dart';
import '../../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
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
  final _scrollController = ScrollController();
  List<_SearchResult> _results = [];
  List<QuickMove> _quickMoves = [];
  bool _isSearching = false;
  bool _isQuickMoveMode = false;
  int _selectedIndex = 0;
  Timer? _debounceTimer;

  List<_CommandDef> _buildCommands(AppLocalizations l) => [
    _CommandDef(l.cmdNewNote, Icons.add, 'note'),
    _CommandDef(l.cmdNewTab, Icons.language, 'tab'),
    _CommandDef(l.cmdOpenDailyNote, Icons.today, 'daily'),
    _CommandDef(l.cmdSwitchTheme, Icons.dark_mode, 'theme'),
    _CommandDef(l.cmdSettings, Icons.settings, 'settings'),
    _CommandDef(l.cmdGraphView, Icons.hub, 'graph'),
    _CommandDef(l.cmdCanvasView, Icons.dashboard, 'canvas'),
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
    _scrollController.dispose();
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
      final selected = _results[_selectedIndex];
      final knowledge = ref.read(knowledgeProvider);
      final noteMatch = knowledge.notes
          .where(
            (n) => n.filePath == selected.filePath || n.id == selected.filePath,
          )
          .firstOrNull;
      if (noteMatch != null) {
        ref.read(knowledgeProvider.notifier).openNote(noteMatch.id);
      }
      widget.onClose();
      return;
    }

    final l = AppLocalizations.of(context);
    if (l == null) {
      widget.onCommand(text);
      widget.onClose();
      return;
    }
    final matchingCommand = _buildCommands(
      l,
    ).where((c) => c.label.toLowerCase().contains(text.toLowerCase()));
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
        title: const Text('Command not found'),
        content: Text('Command "/$cmdName" does not exist. Create it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateQuickMoveDialog(cmdName);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateQuickMoveDialog(String cmdName) {
    showCreateQuickMoveDialog(context, ref, prefillName: cmdName);
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
      if (resultIndex < _results.length) {
        final selected = _results[resultIndex];
        final knowledge = ref.read(knowledgeProvider);
        final noteMatch = knowledge.notes
            .where(
              (n) =>
                  n.filePath == selected.filePath || n.id == selected.filePath,
            )
            .firstOrNull;
        if (noteMatch != null) {
          ref.read(knowledgeProvider.notifier).openNote(noteMatch.id);
        }
      }
      widget.onClose();
    }
  }

  List<_CommandDef> get _commandResults {
    if (_isQuickMoveMode) return [];
    final l = AppLocalizations.of(context);
    if (l == null) return [];
    final commands = _buildCommands(l);
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return commands;
    return commands
        .where((c) => c.label.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commands = _commandResults;
    final showCommands =
        !_isQuickMoveMode &&
        (_controller.text.trim().isEmpty || commands.isNotEmpty);
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = screenWidth < 600 ? screenWidth * 0.9 : 560.0;

    return Center(
      child: Container(
        width: barWidth,
        constraints: const BoxConstraints(
          minWidth: 360,
          maxWidth: 560,
          maxHeight: 480,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(DesignRadius.lg),
          boxShadow: [
            DesignShadow.lg,
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    _isQuickMoveMode ? Icons.bolt : Icons.search,
                    color: _isQuickMoveMode
                        ? DesignColors.semanticWarning
                        : theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: DesignSpacing.md),
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
                  const SizedBox(width: DesignSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Flexible(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: DesignSpacing.xs),
                itemCount: _isQuickMoveMode
                    ? _quickMoves.length
                    : (showCommands ? commands.length : 0) + _results.length,
                itemBuilder: (context, index) {
                  final child = _isQuickMoveMode
                      ? _buildQuickMoveTile(
                          theme,
                          _quickMoves[index],
                          index == _selectedIndex,
                          () {
                            setState(() => _selectedIndex = index);
                            _selectQuickMove(_quickMoves[index]);
                          },
                        )
                      : _buildListItem(
                          context,
                          theme,
                          commands,
                          showCommands,
                          index,
                        );

                  return _StaggeredListItem(
                    key: ValueKey('item_$index'),
                    index: index,
                    child: child,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    ThemeData theme,
    List<_CommandDef> commands,
    bool showCommands,
    int index,
  ) {
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
  }

  Widget _buildQuickMoveTile(
    ThemeData theme,
    QuickMove move,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: DesignColors.primarySubtle,
      leading: Icon(move.icon, size: 18, color: move.color),
      onTap: onTap,
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
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        move.type == QuickMoveType.preset ? 'Preset' : 'Quick Move',
        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
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
      selected: isSelected,
      selectedTileColor: DesignColors.primarySubtle,
      leading: Icon(cmd.icon, size: 18, color: theme.hintColor),
      title: Text(cmd.label, style: theme.textTheme.bodyMedium),
      trailing: Text(
        'Command',
        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
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
      selected: isSelected,
      selectedTileColor: DesignColors.primarySubtle,
      leading: Icon(
        Icons.description,
        size: 18,
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
              padding: const EdgeInsets.only(top: DesignSpacing.xs),
              child: Wrap(
                spacing: DesignSpacing.xs,
                children: result.tags
                    .take(3)
                    .map(
                      (tag) => Text(
                        '#$tag',
                        style: theme.textTheme.labelSmall?.copyWith(
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
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSpacing.xs,
                vertical: DesignSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: DesignColors.primarySubtle,
                borderRadius: BorderRadius.circular(DesignRadius.sm),
              ),
              child: Text(
                result.source == 'semantic' ? 'semantic' : 'keyword',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (result.sourceUrl != null) ...[
            const SizedBox(width: DesignSpacing.xs),
            Icon(Icons.language, size: 12, color: theme.hintColor),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

class _StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredListItem({super.key, required this.index, required this.child});

  @override
  State<_StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<_StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    final delay = Duration(
      milliseconds: widget.index * DesignDuration.staggerItem.inMilliseconds,
    );
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
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

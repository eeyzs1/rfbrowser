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

part 'command_bar/command_bar_search.dart';
part 'command_bar/command_bar_tiles.dart';
part 'command_bar/command_bar_models.dart';

class CommandBar extends ConsumerStatefulWidget {
  final ValueChanged<String> onCommand;
  final VoidCallback onClose;

  const CommandBar({super.key, required this.onCommand, required this.onClose});

  @override
  ConsumerState<CommandBar> createState() => _CommandBarState();
}

abstract class _CommandBarStateBase extends ConsumerState<CommandBar> {
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

  // Abstract methods implemented by mixins
  void _onQueryChanged();
  void _selectItem(int index);
}

class _CommandBarState extends _CommandBarStateBase
    with _CommandBarSearchMixin, _CommandBarTilesMixin {
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
          boxShadow: [DesignShadow.lg],
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
              child: Material(
                type: MaterialType.transparency,
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    vertical: DesignSpacing.xs,
                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}

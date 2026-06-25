part of '../command_bar.dart';

/// Search, query handling, and selection logic for CommandBar.
mixin _CommandBarSearchMixin on _CommandBarStateBase {
  @override
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
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.commandNotFound),
        content: Text(l.commandDoesNotExist(cmdName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateQuickMoveDialog(cmdName);
            },
            child: Text(l.create),
          ),
        ],
      ),
    );
  }

  void _showCreateQuickMoveDialog(String cmdName) {
    showCreateQuickMoveDialog(context, ref, prefillName: cmdName);
  }

  @override
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
}

part of '../canvas_page.dart';

mixin _CanvasInputHandlersMixin on _CanvasViewStateBase {
  @override
  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      final notifier = ref.read(canvasProvider.notifier);
      final matched = notifier.searchCards(query);
      setState(() {
        _searchQuery = query;
        _searchMatchedIds = matched.map((c) => c.id).toList();
        _searchActiveIndex = 0;
      });
    });
  }

  @override
  void _onSearchSubmit(String query) {
    final notifier = ref.read(canvasProvider.notifier);
    final matched = notifier.searchCards(query);
    setState(() {
      _searchQuery = query;
      _searchMatchedIds = matched.map((c) => c.id).toList();
      _searchActiveIndex = 0;
    });
    _panToFirstMatch();
  }

  @override
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchMatchedIds = [];
      _searchActiveIndex = 0;
    });
  }

  @override
  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _clearSearch();
      }
    });
  }

  @override
  void _searchNext() {
    if (_searchMatchedIds.isEmpty) return;
    setState(() {
      _searchActiveIndex = (_searchActiveIndex + 1) % _searchMatchedIds.length;
    });
    _panToMatch(_searchActiveIndex);
  }

  @override
  void _searchPrev() {
    if (_searchMatchedIds.isEmpty) return;
    setState(() {
      _searchActiveIndex =
          (_searchActiveIndex - 1 + _searchMatchedIds.length) %
          _searchMatchedIds.length;
    });
    _panToMatch(_searchActiveIndex);
  }

  @override
  void _panToFirstMatch() => _panToMatch(0);

  @override
  void _panToMatch(int index) {
    if (index < 0 || index >= _searchMatchedIds.length) return;
    final cardId = _searchMatchedIds[index];
    final canvasData = ref.read(canvasProvider);
    final card = canvasData.cards.where((c) => c.id == cardId).firstOrNull;
    if (card == null) return;
    final targetScale = math
        .min(_viewW / (card.width + 200), _viewH / (card.height + 200))
        .clamp(0.1, 2.0);
    _cameraX = card.x + card.width / 2;
    _cameraY = card.y + card.height / 2;
    _scale = targetScale;
    _cameraNotifier.notify();
    ref.read(canvasProvider.notifier).selectCard(card.id);
  }

  @override
  void _deleteSelectedCards() {
    final selectedIds = _selectedCardIds;
    if (selectedIds.isEmpty) return;
    if (selectedIds.length == 1) {
      ref.read(canvasProvider.notifier).removeCard(selectedIds.first);
    } else {
      ref.read(canvasProvider.notifier).batchDeleteCards(selectedIds);
    }
    ref.read(canvasProvider.notifier).selectCard(null);
  }

  @override
  void _undo() => ref.read(canvasProvider.notifier).undo();
  @override
  void _redo() => ref.read(canvasProvider.notifier).redo();

  @override
  void _selectAll() => ref.read(canvasProvider.notifier).selectAll();

  @override
  void _groupSelected() {
    final ids = _selectedCardIds;
    if (ids.length < 2) return;
    ref.read(canvasProvider.notifier).groupCards(ids);
  }

  @override
  void _ungroupSelected() {
    final ids = _selectedCardIds;
    if (ids.isEmpty) return;
    final notifier = ref.read(canvasProvider.notifier);
    for (final id in ids) {
      final group = notifier.groupForCard(id);
      if (group != null) {
        notifier.ungroupCards(group.id);
        return;
      }
    }
  }
}

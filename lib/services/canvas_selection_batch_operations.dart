part of 'canvas_service.dart';

/// Selection, inline editing, batch operations, and grouping.
mixin CanvasSelectionBatchOperations on CanvasNotifierBase {
  void selectCard(String? cardId, {bool additive = false}) {
    if (cardId == null) {
      state = state.copyWith(clearSelectedCardIds: true);
    } else if (additive) {
      final ids = List<String>.from(state.selectedCardIds);
      if (ids.contains(cardId)) {
        ids.remove(cardId);
      } else {
        ids.add(cardId);
      }
      state = state.copyWith(
        selectedCardIds: ids,
        clearSelectedConnectionId: true,
      );
    } else {
      state = state.copyWith(
        selectedCardIds: [cardId],
        clearSelectedConnectionId: true,
      );
    }
  }

  void selectCards(List<String> cardIds) {
    state = state.copyWith(
      selectedCardIds: cardIds,
      clearSelectedConnectionId: true,
    );
  }

  void addToSelection(String cardId) {
    final ids = List<String>.from(state.selectedCardIds);
    if (!ids.contains(cardId)) ids.add(cardId);
    state = state.copyWith(selectedCardIds: ids);
  }

  void removeFromSelection(String cardId) {
    final ids = List<String>.from(state.selectedCardIds);
    ids.remove(cardId);
    state = state.copyWith(selectedCardIds: ids);
  }

  void selectAll() {
    state = state.copyWith(
      selectedCardIds: state.cards.map((c) => c.id).toList(),
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedCardIds: true,
      clearSelectedConnectionId: true,
    );
  }

  void selectConnection(String? connId) {
    if (connId == null) {
      state = state.copyWith(clearSelectedConnectionId: true);
    } else {
      state = state.copyWith(
        selectedConnectionId: connId,
        clearSelectedCardIds: true,
      );
    }
  }

  void startInlineEditing(String cardId) {
    state = state.copyWith(
      selectedCardIds: [cardId],
      inlineEditingCardId: cardId,
    );
  }

  void finishInlineEditing() {
    state = state.copyWith(clearInlineEditingCardId: true);
  }

  Future<void> batchDeleteCards(List<String> cardIds) async {
    if (cardIds.isEmpty) return;
    final cardIdSet = cardIds.toSet();
    await _mutateAndPersist(
      () => state.copyWith(
        cards: state.cards.where((c) => !cardIdSet.contains(c.id)).toList(),
        connections: state.connections
            .where(
              (c) =>
                  !cardIdSet.contains(c.fromCardId) &&
                  !cardIdSet.contains(c.toCardId),
            )
            .toList(),
        groups: state.groups
            .map((g) {
              final remaining = g.cardIds
                  .where((id) => !cardIdSet.contains(id))
                  .toList();
              return g.copyWith(cardIds: remaining);
            })
            .where((g) => g.cardIds.isNotEmpty)
            .toList(),
        clearSelectedCardIds: true,
      ),
    );
  }

  void batchUpdateCardColor(List<String> cardIds, int colorValue) {
    _mutateAndDebounce(
      () => _styleService.withBatchCardColor(state, cardIds, colorValue),
    );
  }

  void batchMoveCards(Map<String, (double, double)> moves) {
    final newCards = state.cards.map((c) {
      final move = moves[c.id];
      if (move != null) {
        return c.copyWith(x: move.$1, y: move.$2);
      }
      return c;
    }).toList();
    state = state.copyWith(cards: newCards);
    _debouncedSave();
  }

  Future<void> groupCards(List<String> cardIds, {String? name}) async {
    if (cardIds.length < 2) return;
    final group = CanvasGroup(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Group ${state.groups.length + 1}',
      cardIds: cardIds,
    );
    await _mutateAndPersist(
      () => state.copyWith(groups: [...state.groups, group]),
    );
  }

  Future<void> ungroupCards(String groupId) async {
    await _mutateAndPersist(
      () => state.copyWith(
        groups: state.groups.where((g) => g.id != groupId).toList(),
      ),
    );
  }

  Future<void> renameGroup(String groupId, String name) async {
    _mutateAndDebounce(() {
      final groups = state.groups.map((g) {
        if (g.id == groupId) return g.copyWith(name: name);
        return g;
      }).toList();
      return state.copyWith(groups: groups);
    });
  }

  void alignCards(List<String> cardIds, AlignmentType type) {
    if (cardIds.length < 2) return;
    _mutateAndDebounce(
      () => state.copyWith(
        cards: _layoutService.alignCards(state.cards, cardIds, type),
      ),
    );
  }

  void distributeCards(List<String> cardIds, DistributeType type) {
    if (cardIds.length < 3) return;
    _mutateAndDebounce(
      () => state.copyWith(
        cards: _layoutService.distributeCards(state.cards, cardIds, type),
      ),
    );
  }
}

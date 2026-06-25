part of 'canvas_service.dart';

/// Card CRUD, tags, card factory, card style/metadata, and card style setters.
mixin CanvasCardOperations on CanvasNotifierBase {
  Future<void> addCard(CanvasCard card) async {
    await _mutateAndPersist(
      () => state.copyWith(cards: [...state.cards, card]),
    );
  }

  Future<void> updateCard(CanvasCard card) async {
    await _mutateAndPersist(() {
      final cards = state.cards.map((c) => c.id == card.id ? card : c).toList();
      return state.copyWith(cards: cards);
    });
  }

  Future<void> removeCard(String cardId) async {
    await _mutateAndPersist(
      () => state.copyWith(
        cards: state.cards.where((c) => c.id != cardId).toList(),
        connections: state.connections
            .where((c) => c.fromCardId != cardId && c.toCardId != cardId)
            .toList(),
        groups: state.groups
            .map((g) {
              final remaining = g.cardIds.where((id) => id != cardId).toList();
              return g.copyWith(cardIds: remaining);
            })
            .where((g) => g.cardIds.isNotEmpty)
            .toList(),
      ),
    );
  }

  void addTag(String cardId, String tag) {
    final card = cardById(cardId);
    if (card == null) return;
    if (card.tags.contains(tag)) return;
    updateCardInMemory(card.copyWith(tags: [...card.tags, tag]));
    _debouncedSave();
  }

  void removeTag(String cardId, String tag) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(
      card.copyWith(tags: card.tags.where((t) => t != tag).toList()),
    );
    _debouncedSave();
  }

  CanvasCard createCard(
    CanvasCardType type,
    Offset position, {
    String? title,
    String? noteId,
  }) {
    final defaultStyle = state.settings.defaultCardStyle;
    return CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      x: position.dx,
      y: position.dy,
      width: type.defaultWidth,
      height: type.defaultHeight,
      title: title ?? type.label,
      noteId: noteId,
      style: defaultStyle,
    );
  }

  CanvasConnection createConnection(
    String fromId,
    String toId, {
    String? label,
  }) {
    final from = cardById(fromId);
    final to = cardById(toId);
    if (from == null || to == null) {
      return CanvasConnection(id: '', fromCardId: fromId, toCardId: toId);
    }
    final (fromSide, toSide) = CanvasConnection.computeSides(from, to);
    final defaultStyle = state.settings.defaultConnectionStyle;
    return CanvasConnection(
      id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
      fromCardId: fromId,
      toCardId: toId,
      fromSide: fromSide,
      toSide: toSide,
      label: label ?? '',
      style: defaultStyle,
    );
  }

  void setMetadata(String cardId, CanvasCardMetadata metadata) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withMetadata(card, metadata));
    _debouncedSave();
  }

  void setHyperlink(String cardId, String? url) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withHyperlink(card, url));
    _debouncedSave();
  }

  void setTextAlign(String cardId, {TextAlignH? h, TextAlignV? v}) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withTextAlign(card, h: h, v: v));
    _debouncedSave();
  }

  void setRichContent(String cardId, List<RichTextSegment> segments) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withRichContent(card, segments));
    _debouncedSave();
  }

  void toggleAutoNumber(String cardId) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withToggledAutoNumber(card));
    _debouncedSave();
  }

  void setFreehandPoints(String cardId, List<Offset> points) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withFreehandPoints(card, points));
    _debouncedSave();
  }

  void setTableSize(String cardId, int rows, int cols) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withTableSize(card, rows, cols));
    _debouncedSave();
  }

  void setTableCell(String cardId, int row, int col, String text) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withTableCell(card, row, col, text));
    _debouncedSave();
  }

  void toggleVerticalText(String cardId) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withToggledVerticalText(card));
    _debouncedSave();
  }

  void enumerateAllCards() {
    state = _styleService.withEnumeratedCards(state);
    _debouncedSave();
  }

  void setFontFamily(String cardId, String family) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withFontFamily(card, family));
    _debouncedSave();
  }

  void setTextColor(String cardId, int colorValue) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withTextColor(card, colorValue));
    _debouncedSave();
  }

  void setLatexFormula(String cardId, String? formula) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withLatexFormula(card, formula));
    _debouncedSave();
  }

  void setHtmlContent(String cardId, String? html) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withHtmlContent(card, html));
    _debouncedSave();
  }

  void setCustomSvg(String cardId, String? svgData) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withCustomSvg(card, svgData));
    _debouncedSave();
  }

  void addSvgAsCustomShape(String cardId, String svgData) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(_styleService.withCustomSvg(card, svgData));
    _debouncedSave();
  }

  void setConnectionPointOffset(String cardId, double offsetX, double offsetY) {
    final card = cardById(cardId);
    if (card == null) return;
    updateCardInMemory(
      _styleService.withConnectionPointOffset(card, offsetX, offsetY),
    );
    _debouncedSave();
  }
}

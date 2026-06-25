part of 'canvas_service.dart';

/// Layer operations: add/remove/rename/visibility/lock/reorder/move cards.
mixin CanvasLayerOperations on CanvasNotifierBase {
  Future<void> addLayer(String name) async {
    _pushUndo();
    final layer = _layersService.createLayer(name, state.layers.length);
    state = state.copyWith(layers: [...state.layers, layer]);
    await _save();
  }

  Future<void> removeLayer(String layerId) async {
    _pushUndo();
    final newLayers = _layersService.removeLayer(state.layers, layerId);
    final cleanedCards = state.cards.map((c) {
      if (c.layerId == layerId) return c.copyWith(clearLayerId: true);
      return c;
    }).toList();
    state = state.copyWith(layers: newLayers, cards: cleanedCards);
    await _save();
  }

  void renameLayer(String layerId, String name) {
    final layers = _layersService.renameLayer(state.layers, layerId, name);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void toggleLayerVisibility(String layerId) {
    final layers = state.layers.map((l) {
      if (l.id == layerId) return l.copyWith(visible: !l.visible);
      return l;
    }).toList();
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void setLayerVisible(String layerId, bool visible) {
    final layers = state.layers.map((l) {
      if (l.id == layerId) return l.copyWith(visible: visible);
      return l;
    }).toList();
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void toggleLayerLock(String layerId) {
    final layers = state.layers.map((l) {
      if (l.id == layerId) return l.copyWith(locked: !l.locked);
      return l;
    }).toList();
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void setLayerLocked(String layerId, bool locked) {
    final layers = state.layers.map((l) {
      if (l.id == layerId) return l.copyWith(locked: locked);
      return l;
    }).toList();
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void moveCardToLayer(String cardId, String? layerId) {
    final cards = _layersService.moveCardToLayer(state.cards, cardId, layerId);
    state = state.copyWith(cards: cards);
    _debouncedSave();
  }

  void setSelectedLayer(String? layerId) {
    state = state.copyWith(
      selectedLayerId: layerId,
      clearSelectedLayerId: layerId == null,
    );
    _debouncedSave();
  }

  bool isLayerLocked(String cardId) {
    return false;
  }

  bool isLayerVisible(String cardId) {
    return true;
  }

  void reorderLayer(String layerId, int newOrder) {
    final layers = _layersService.reorderLayer(state.layers, layerId, newOrder);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void moveLayerUp(String layerId) {
    final layers = _layersService.moveLayerUp(state.layers, layerId);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  void moveLayerDown(String layerId) {
    final layers = _layersService.moveLayerDown(state.layers, layerId);
    state = state.copyWith(layers: layers);
    _debouncedSave();
  }

  int cardCountForLayer(String layerId) {
    return _layersService.cardCountForLayer(state.cards, layerId);
  }
}

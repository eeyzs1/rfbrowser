part of '../canvas_service.dart';

mixin CanvasLayersMixin on _CanvasNotifierBase {
    Future<void> addLayer(String name) async {
      _pushUndo();
      final layer = CanvasLayer(
        id: 'layer_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        order: state.layers.length,
      );
      state = state.copyWith(layers: [...state.layers, layer]);
      await _save();
    }

    Future<void> removeLayer(String layerId) async {
      _pushUndo();
      final newLayers = state.layers.where((l) => l.id != layerId).toList();
      final newCards = state.cards.map((c) {
        if (c.layerId == layerId) return c.copyWith(clearLayerId: true);
        return c;
      }).toList();
      state = state.copyWith(layers: newLayers, cards: newCards);
      await _save();
    }

    @override
    void renameLayer(String layerId, String name) {
      final layers = state.layers.map((l) {
        if (l.id == layerId) return l.copyWith(name: name);
        return l;
      }).toList();
      state = state.copyWith(layers: layers);
      _debouncedSave();
    }

    @override
    void toggleLayerVisibility(String layerId) {
      final layers = state.layers.map((l) {
        if (l.id == layerId) return l.copyWith(visible: !l.visible);
        return l;
      }).toList();
      state = state.copyWith(layers: layers);
      _debouncedSave();
    }

    @override
    void toggleLayerLock(String layerId) {
      final layers = state.layers.map((l) {
        if (l.id == layerId) return l.copyWith(locked: !l.locked);
        return l;
      }).toList();
      state = state.copyWith(layers: layers);
      _debouncedSave();
    }

    @override
    void moveCardToLayer(String cardId, String? layerId) {
      final cards = state.cards.map((c) {
        if (c.id == cardId) {
          return layerId != null
              ? c.copyWith(layerId: layerId)
              : c.copyWith(clearLayerId: true);
        }
        return c;
      }).toList();
      state = state.copyWith(cards: cards);
      _debouncedSave();
    }

    @override
    bool isLayerLocked(String cardId) {
      final card = cardById(cardId);
      if (card == null || card.layerId == null) return false;
      final layer = state.layers.where((l) => l.id == card.layerId).firstOrNull;
      return layer?.locked ?? false;
    }

    @override
    bool isLayerVisible(String cardId) {
      final card = cardById(cardId);
      if (card == null || card.layerId == null) return true;
      final layer = state.layers.where((l) => l.id == card.layerId).firstOrNull;
      return layer?.visible ?? true;
    }

    @override
    void reorderLayer(String layerId, int newOrder) {
      final sortedLayers = List<CanvasLayer>.from(state.layers)
        ..sort((a, b) => a.order.compareTo(b.order));
      sortedLayers.removeWhere((l) => l.id == layerId);
      final targetLayer = state.layers.where((l) => l.id == layerId).firstOrNull;
      if (targetLayer == null) return;
      newOrder = newOrder.clamp(0, sortedLayers.length);
      sortedLayers.insert(newOrder, targetLayer);
      final reordered = <CanvasLayer>[];
      for (int i = 0; i < sortedLayers.length; i++) {
        reordered.add(sortedLayers[i].copyWith(order: i));
      }
      state = state.copyWith(layers: reordered);
      _debouncedSave();
    }

    @override
    void moveLayerUp(String layerId) {
      final sortedLayers = List<CanvasLayer>.from(state.layers)
        ..sort((a, b) => a.order.compareTo(b.order));
      final idx = sortedLayers.indexWhere((l) => l.id == layerId);
      if (idx <= 0) return;
      final temp = sortedLayers[idx];
      sortedLayers[idx] = sortedLayers[idx - 1];
      sortedLayers[idx - 1] = temp;
      final reordered = <CanvasLayer>[];
      for (int i = 0; i < sortedLayers.length; i++) {
        reordered.add(sortedLayers[i].copyWith(order: i));
      }
      state = state.copyWith(layers: reordered);
      _debouncedSave();
    }

    @override
    void moveLayerDown(String layerId) {
      final sortedLayers = List<CanvasLayer>.from(state.layers)
        ..sort((a, b) => a.order.compareTo(b.order));
      final idx = sortedLayers.indexWhere((l) => l.id == layerId);
      if (idx < 0 || idx >= sortedLayers.length - 1) return;
      final temp = sortedLayers[idx];
      sortedLayers[idx] = sortedLayers[idx + 1];
      sortedLayers[idx + 1] = temp;
      final reordered = <CanvasLayer>[];
      for (int i = 0; i < sortedLayers.length; i++) {
        reordered.add(sortedLayers[i].copyWith(order: i));
      }
      state = state.copyWith(layers: reordered);
      _debouncedSave();
    }

    @override
    int cardCountForLayer(String layerId) {
      return state.cards.where((c) => c.layerId == layerId).length;
    }

    // === Auto Layout ===


}

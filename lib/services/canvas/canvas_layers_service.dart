import 'package:uuid/uuid.dart';
import '../../data/models/canvas_model.dart';

class CanvasLayersService {
  const CanvasLayersService();

  CanvasLayer createLayer(String name, int order) {
    return CanvasLayer(
      id: 'layer_${const Uuid().v4()}',
      name: name,
      order: order,
    );
  }

  List<CanvasLayer> removeLayer(List<CanvasLayer> layers, String layerId) {
    return layers.where((l) => l.id != layerId).toList();
  }

  List<CanvasLayer> renameLayer(List<CanvasLayer> layers, String layerId, String name) {
    return layers.map((l) {
      if (l.id == layerId) return l.copyWith(name: name);
      return l;
    }).toList();
  }

  List<CanvasLayer> toggleLayerVisibility(List<CanvasLayer> layers, String layerId) {
    return layers.map((l) {
      if (l.id == layerId) return l.copyWith(visible: !l.visible);
      return l;
    }).toList();
  }

  List<CanvasLayer> toggleLayerLock(List<CanvasLayer> layers, String layerId) {
    return layers.map((l) {
      if (l.id == layerId) return l.copyWith(locked: !l.locked);
      return l;
    }).toList();
  }

  List<CanvasCard> moveCardToLayer(List<CanvasCard> cards, String cardId, String? layerId) {
    return cards.map((c) {
      if (c.id == cardId) {
        return layerId != null
            ? c.copyWith(layerId: layerId)
            : c.copyWith(clearLayerId: true);
      }
      return c;
    }).toList();
  }

  bool isLayerLocked(List<CanvasLayer> layers, CanvasCard? card) {
    if (card == null || card.layerId == null) return false;
    final layer = layers.where((l) => l.id == card.layerId).firstOrNull;
    return layer?.locked ?? false;
  }

  bool isLayerVisible(List<CanvasLayer> layers, CanvasCard? card) {
    if (card == null || card.layerId == null) return true;
    final layer = layers.where((l) => l.id == card.layerId).firstOrNull;
    return layer?.visible ?? true;
  }

  List<CanvasLayer> reorderLayer(List<CanvasLayer> layers, String layerId, int newOrder) {
    final sortedLayers = List<CanvasLayer>.from(layers)
      ..sort((a, b) => a.order.compareTo(b.order));
    sortedLayers.removeWhere((l) => l.id == layerId);
    final targetLayer = layers.where((l) => l.id == layerId).firstOrNull;
    if (targetLayer == null) return layers;
    newOrder = newOrder.clamp(0, sortedLayers.length);
    sortedLayers.insert(newOrder, targetLayer);
    final reordered = <CanvasLayer>[];
    for (int i = 0; i < sortedLayers.length; i++) {
      reordered.add(sortedLayers[i].copyWith(order: i));
    }
    return reordered;
  }

  List<CanvasLayer> moveLayerUp(List<CanvasLayer> layers, String layerId) {
    final sortedLayers = List<CanvasLayer>.from(layers)
      ..sort((a, b) => a.order.compareTo(b.order));
    final idx = sortedLayers.indexWhere((l) => l.id == layerId);
    if (idx <= 0) return layers;
    final temp = sortedLayers[idx];
    sortedLayers[idx] = sortedLayers[idx - 1];
    sortedLayers[idx - 1] = temp;
    final reordered = <CanvasLayer>[];
    for (int i = 0; i < sortedLayers.length; i++) {
      reordered.add(sortedLayers[i].copyWith(order: i));
    }
    return reordered;
  }

  List<CanvasLayer> moveLayerDown(List<CanvasLayer> layers, String layerId) {
    final sortedLayers = List<CanvasLayer>.from(layers)
      ..sort((a, b) => a.order.compareTo(b.order));
    final idx = sortedLayers.indexWhere((l) => l.id == layerId);
    if (idx < 0 || idx >= sortedLayers.length - 1) return layers;
    final temp = sortedLayers[idx];
    sortedLayers[idx] = sortedLayers[idx + 1];
    sortedLayers[idx + 1] = temp;
    final reordered = <CanvasLayer>[];
    for (int i = 0; i < sortedLayers.length; i++) {
      reordered.add(sortedLayers[i].copyWith(order: i));
    }
    return reordered;
  }

  int cardCountForLayer(List<CanvasCard> cards, String layerId) {
    return cards.where((c) => c.layerId == layerId).length;
  }
}

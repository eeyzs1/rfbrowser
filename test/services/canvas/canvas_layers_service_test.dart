import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/services/canvas/canvas_layers_service.dart';

void main() {
  group('CanvasLayersService', () {
    late CanvasLayersService service;

    setUp(() {
      service = const CanvasLayersService();
    });

    group('createLayer', () {
      test('creates a layer with name and order', () {
        final layer = service.createLayer('Background', 0);
        expect(layer.name, 'Background');
        expect(layer.order, 0);
        expect(layer.id, startsWith('layer_'));
        expect(layer.visible, isTrue);
        expect(layer.locked, isFalse);
      });

      test('creates layers with unique ids', () {
        final layer1 = service.createLayer('A', 0);
        final layer2 = service.createLayer('B', 1);
        expect(layer1.id, isNot(layer2.id));
      });
    });

    group('removeLayer', () {
      test('removes layer by id', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0),
          CanvasLayer(id: 'l2', name: 'B', order: 1),
        ];
        final result = service.removeLayer(layers, 'l1');
        expect(result.length, 1);
        expect(result.first.id, 'l2');
      });

      test('returns empty list when removing last layer', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0)];
        final result = service.removeLayer(layers, 'l1');
        expect(result, isEmpty);
      });

      test('returns unchanged list when id not found', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0)];
        final result = service.removeLayer(layers, 'nonexistent');
        expect(result.length, 1);
      });
    });

    group('renameLayer', () {
      test('renames the specified layer', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0),
          CanvasLayer(id: 'l2', name: 'B', order: 1),
        ];
        final result = service.renameLayer(layers, 'l1', 'Renamed');
        expect(result[0].name, 'Renamed');
        expect(result[0].id, 'l1');
        expect(result[1].name, 'B');
      });

      test('returns unchanged list when id not found', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0)];
        final result = service.renameLayer(layers, 'nope', 'X');
        expect(result[0].name, 'A');
      });
    });

    group('toggleLayerVisibility', () {
      test('toggles visibility from true to false', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, visible: true)];
        final result = service.toggleLayerVisibility(layers, 'l1');
        expect(result[0].visible, isFalse);
      });

      test('toggles visibility from false to true', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, visible: false)];
        final result = service.toggleLayerVisibility(layers, 'l1');
        expect(result[0].visible, isTrue);
      });

      test('does not affect other layers', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0, visible: true),
          CanvasLayer(id: 'l2', name: 'B', order: 1, visible: true),
        ];
        final result = service.toggleLayerVisibility(layers, 'l1');
        expect(result[0].visible, isFalse);
        expect(result[1].visible, isTrue);
      });
    });

    group('toggleLayerLock', () {
      test('toggles lock from false to true', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, locked: false)];
        final result = service.toggleLayerLock(layers, 'l1');
        expect(result[0].locked, isTrue);
      });

      test('toggles lock from true to false', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, locked: true)];
        final result = service.toggleLayerLock(layers, 'l1');
        expect(result[0].locked, isFalse);
      });
    });

    group('moveCardToLayer', () {
      test('assigns card to a layer', () {
        final cards = [CanvasCard(id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50)];
        final result = service.moveCardToLayer(cards, 'c1', 'l1');
        expect(result[0].layerId, 'l1');
      });

      test('clears layerId when target is null', () {
        final cards = [
          CanvasCard(id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l1'),
        ];
        final result = service.moveCardToLayer(cards, 'c1', null);
        expect(result[0].layerId, isNull);
      });

      test('does not affect other cards', () {
        final cards = [
          CanvasCard(id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50),
          CanvasCard(id: 'c2', type: CanvasCardType.rectangle, x: 100, y: 0, width: 100, height: 50),
        ];
        final result = service.moveCardToLayer(cards, 'c1', 'l1');
        expect(result[0].layerId, 'l1');
        expect(result[1].layerId, isNull);
      });
    });

    group('isLayerLocked', () {
      test('returns false when card is null', () {
        expect(service.isLayerLocked([], null), isFalse);
      });

      test('returns false when card has no layerId', () {
        final card = CanvasCard(id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50);
        expect(service.isLayerLocked([], card), isFalse);
      });

      test('returns false when layer is not locked', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, locked: false)];
        final card = CanvasCard(
          id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l1',
        );
        expect(service.isLayerLocked(layers, card), isFalse);
      });

      test('returns true when layer is locked', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, locked: true)];
        final card = CanvasCard(
          id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l1',
        );
        expect(service.isLayerLocked(layers, card), isTrue);
      });

      test('returns false when layer not found', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, locked: true)];
        final card = CanvasCard(
          id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l2',
        );
        expect(service.isLayerLocked(layers, card), isFalse);
      });
    });

    group('isLayerVisible', () {
      test('returns true when card is null', () {
        expect(service.isLayerVisible([], null), isTrue);
      });

      test('returns true when card has no layerId', () {
        final card = CanvasCard(id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50);
        expect(service.isLayerVisible([], card), isTrue);
      });

      test('returns true when layer is visible', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, visible: true)];
        final card = CanvasCard(
          id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l1',
        );
        expect(service.isLayerVisible(layers, card), isTrue);
      });

      test('returns false when layer is not visible', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, visible: false)];
        final card = CanvasCard(
          id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l1',
        );
        expect(service.isLayerVisible(layers, card), isFalse);
      });

      test('returns true when layer not found', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0, visible: false)];
        final card = CanvasCard(
          id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l2',
        );
        expect(service.isLayerVisible(layers, card), isTrue);
      });
    });

    group('reorderLayer', () {
      test('moves layer to new order position', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0),
          CanvasLayer(id: 'l2', name: 'B', order: 1),
          CanvasLayer(id: 'l3', name: 'C', order: 2),
        ];
        final result = service.reorderLayer(layers, 'l3', 0);
        expect(result[0].id, 'l3');
        expect(result[0].order, 0);
        expect(result[1].id, 'l1');
        expect(result[1].order, 1);
        expect(result[2].id, 'l2');
        expect(result[2].order, 2);
      });

      test('clamps order to valid range', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0),
          CanvasLayer(id: 'l2', name: 'B', order: 1),
        ];
        final clampedLow = service.reorderLayer(layers, 'l1', -5);
        expect(clampedLow[0].id, 'l1');

        final clampedHigh = service.reorderLayer(layers, 'l1', 100);
        expect(clampedHigh.last.id, 'l1');
      });

      test('returns unchanged list when layer not found', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0)];
        final result = service.reorderLayer(layers, 'nope', 0);
        expect(result[0].id, 'l1');
      });
    });

    group('moveLayerUp', () {
      test('moves second layer up to first', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0),
          CanvasLayer(id: 'l2', name: 'B', order: 1),
        ];
        final result = service.moveLayerUp(layers, 'l2');
        expect(result[0].id, 'l2');
        expect(result[0].order, 0);
        expect(result[1].id, 'l1');
        expect(result[1].order, 1);
      });

      test('does not move first layer up', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0),
          CanvasLayer(id: 'l2', name: 'B', order: 1),
        ];
        final result = service.moveLayerUp(layers, 'l1');
        expect(result[0].id, 'l1');
        expect(result[1].id, 'l2');
      });

      test('returns unchanged when single layer', () {
        final layers = [CanvasLayer(id: 'l1', name: 'A', order: 0)];
        final result = service.moveLayerUp(layers, 'l1');
        expect(result.length, 1);
      });
    });

    group('moveLayerDown', () {
      test('moves first layer down to second', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0),
          CanvasLayer(id: 'l2', name: 'B', order: 1),
        ];
        final result = service.moveLayerDown(layers, 'l1');
        expect(result[0].id, 'l2');
        expect(result[0].order, 0);
        expect(result[1].id, 'l1');
        expect(result[1].order, 1);
      });

      test('does not move last layer down', () {
        final layers = [
          CanvasLayer(id: 'l1', name: 'A', order: 0),
          CanvasLayer(id: 'l2', name: 'B', order: 1),
        ];
        final result = service.moveLayerDown(layers, 'l2');
        expect(result[0].id, 'l1');
        expect(result[1].id, 'l2');
      });
    });

    group('cardCountForLayer', () {
      test('counts cards assigned to a layer', () {
        final cards = [
          CanvasCard(id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l1'),
          CanvasCard(id: 'c2', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l1'),
          CanvasCard(id: 'c3', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l2'),
        ];
        expect(service.cardCountForLayer(cards, 'l1'), 2);
        expect(service.cardCountForLayer(cards, 'l2'), 1);
      });

      test('returns 0 when no cards in layer', () {
        final cards = [CanvasCard(id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50, layerId: 'l1')];
        expect(service.cardCountForLayer(cards, 'l2'), 0);
      });

      test('returns 0 when cards with null layerId present', () {
        final cards = [CanvasCard(id: 'c1', type: CanvasCardType.rectangle, x: 0, y: 0, width: 100, height: 50)];
        expect(service.cardCountForLayer(cards, 'l1'), 0);
      });
    });
  });
}
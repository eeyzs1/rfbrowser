import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/services/canvas/canvas_export_service.dart';
import 'package:rfbrowser/services/canvas/canvas_layers_service.dart';
import 'package:rfbrowser/services/canvas/canvas_layout_service.dart';
import 'package:rfbrowser/services/canvas/canvas_scratchpad_service.dart';
import 'package:rfbrowser/services/canvas/canvas_templates_service.dart';

void main() {
  group('Canvas Export Service Integration', () {
    test('exportToSvg generates valid SVG with cards', () {
      final data = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            title: 'Hello',
            content: 'World',
            x: 100,
            y: 100,
            width: 200,
            height: 100,
          ),
        ],
        connections: [],
      );

      const exporter = CanvasExportService();
      final svg = exporter.exportToSvg(data, 'Test Canvas');

      expect(svg, contains('<?xml version="1.0"'));
      expect(svg, contains('<svg'));
      expect(svg, contains('</svg>'));
      expect(svg, contains('Hello'));
    });

    test('exportToSvg generates SVG with connections', () {
      final data = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            title: 'A',
            content: '',
            x: 0,
            y: 0,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            title: 'B',
            content: '',
            x: 200,
            y: 0,
            width: 100,
            height: 100,
          ),
        ],
        connections: [
          CanvasConnection(
            id: 'conn1',
            fromCardId: 'c1',
            toCardId: 'c2',
            label: 'relates to',
          ),
        ],
      );

      const exporter = CanvasExportService();
      final svg = exporter.exportToSvg(data, 'Connected');

      expect(svg, contains('<line'));
      expect(svg, contains('relates to'));
    });

    test('exportToSvg handles empty canvas', () {
      final data = CanvasData(cards: [], connections: []);

      const exporter = CanvasExportService();
      final svg = exporter.exportToSvg(data, 'Empty');

      expect(svg, contains('<?xml'));
      expect(svg, contains('<svg'));
      expect(svg, contains('</svg>'));
    });
  });

  group('Canvas Layers Service Integration', () {
    test('createLayer creates new layer', () {
      const service = CanvasLayersService();
      final layer = service.createLayer('Layer 1', 0);

      expect(layer.id, isNotEmpty);
      expect(layer.name, 'Layer 1');
    });

    test('removeLayer deletes layer', () {
      const service = CanvasLayersService();
      final layer = service.createLayer('Temp', 0);
      final layers = [layer];

      final result = service.removeLayer(layers, layer.id);
      expect(result.any((l) => l.id == layer.id), isFalse);
    });

    test('renameLayer changes layer name', () {
      const service = CanvasLayersService();
      final layer = service.createLayer('Old', 0);
      final layers = [layer];

      final result = service.renameLayer(layers, layer.id, 'New');
      expect(result.firstWhere((l) => l.id == layer.id).name, 'New');
    });

    test('reorderLayer changes layer order', () {
      const service = CanvasLayersService();
      final layer1 = service.createLayer('Layer 1', 0);
      final layer2 = service.createLayer('Layer 2', 1);
      final layers = [layer1, layer2];

      final result = service.reorderLayer(layers, layer1.id, 1);
      expect(result[0].id, layer2.id);
      expect(result[1].id, layer1.id);
    });

    test('moveCardToLayer assigns card to layer', () {
      const service = CanvasLayersService();
      final cards = [
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Card', content: ''),
      ];

      final result = service.moveCardToLayer(cards, 'c1', 'layer1');
      expect(result.first.layerId, 'layer1');
    });
  });

  group('Canvas Layout Service Integration', () {
    test('computeLayout grid positions cards', () {
      final cards = [
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'A', content: '',
            x: 0, y: 0),
        CanvasCard(id: 'c2', type: CanvasCardType.text, title: 'B', content: '',
            x: 0, y: 0),
        CanvasCard(id: 'c3', type: CanvasCardType.text, title: 'C', content: '',
            x: 0, y: 0),
        CanvasCard(id: 'c4', type: CanvasCardType.text, title: 'D', content: '',
            x: 0, y: 0),
      ];

      const service = CanvasLayoutService();
      final positions = service.computeLayout(cards, [], AutoLayoutType.grid);

      expect(positions.length, 4);
      for (final pos in positions.values) {
        expect(pos.dx, isNot(0));
        expect(pos.dy, isNot(0));
      }
    });

    test('computeLayout grid handles empty list', () {
      const service = CanvasLayoutService();
      final positions = service.computeLayout([], [], AutoLayoutType.grid);

      expect(positions, isEmpty);
    });

    test('computeLayout force directed positions cards', () {
      final cards = [
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'A', content: '',
            x: 0, y: 0),
        CanvasCard(id: 'c2', type: CanvasCardType.text, title: 'B', content: '',
            x: 0, y: 0),
      ];

      const service = CanvasLayoutService();
      final positions = service.computeLayout(cards, [], AutoLayoutType.forceDirected);

      expect(positions.length, 2);
      for (final pos in positions.values) {
        expect(pos.dx, isNot(0));
        expect(pos.dy, isNot(0));
      }
    });
  });

  group('Canvas Scratchpad Service Integration', () {
    test('createCardFromScratchpad creates card from item', () {
      const service = CanvasScratchpadService();
      final item = ScratchpadItem(
        id: 'si1',
        name: 'Brainstorm',
        type: CanvasCardType.roundedRect,
        width: 240,
        height: 160,
      );

      final card = service.createCardFromScratchpad(item, Offset.zero);

      expect(card.title, 'Brainstorm');
      expect(card.type, CanvasCardType.roundedRect);
      expect(card.width, 240);
      expect(card.height, 160);
    });
  });

  group('Canvas Templates Service Integration', () {
    test('builtInTemplates contains templates', () {
      final templates = CanvasTemplatesService.builtInTemplates;

      expect(templates, isNotEmpty);
      expect(templates.containsKey('mindmap'), isTrue);
      expect(templates.containsKey('flowchart'), isTrue);
    });

    test('builtInTemplates mindmap has cards and connections', () {
      final mindmap = CanvasTemplatesService.builtInTemplates['mindmap']!;

      expect(mindmap.cards, isNotEmpty);
      expect(mindmap.connections, isNotEmpty);
    });

    test('builtInTemplates shape library has categories', () {
      final categories = CanvasTemplatesService.shapeLibraryCategories;

      expect(categories, isNotEmpty);
      expect(categories.containsKey('General'), isTrue);
      expect(categories.containsKey('UML'), isTrue);
    });
  });
}
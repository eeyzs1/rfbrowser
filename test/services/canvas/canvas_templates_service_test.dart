import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/services/canvas/canvas_templates_service.dart';

void main() {
  group('shapeLibraryCategories', () {
    test('has expected top-level categories', () {
      expect(
        CanvasTemplatesService.shapeLibraryCategories.keys,
        unorderedEquals([
          'General',
          'Flowchart',
          'UML',
          'Network',
          'Tables',
          'Containers',
          'Decorative',
        ]),
      );
    });

    test('General category contains Basic shapes', () {
      final general = CanvasTemplatesService.shapeLibraryCategories['General']!;
      expect(general.keys, contains('Basic'));
      expect(general['Basic'], isNotEmpty);
    });

    test('Flowchart category contains Flow shapes', () {
      final flowchart =
          CanvasTemplatesService.shapeLibraryCategories['Flowchart']!;
      expect(flowchart.keys, contains('Flow'));
      expect(flowchart['Flow'], isNotEmpty);
    });

    test('all shape values are valid CanvasCardType', () {
      for (final category
          in CanvasTemplatesService.shapeLibraryCategories.values) {
        for (final shapes in category.values) {
          for (final shape in shapes) {
            expect(CanvasCardType.values, contains(shape));
          }
        }
      }
    });
  });

  group('builtInTemplates', () {
    test('has expected template keys', () {
      expect(
        CanvasTemplatesService.builtInTemplates.keys,
        unorderedEquals([
          'flowchart',
          'uml_class',
          'swimlane',
          'mindmap',
          'network',
          'er_diagram',
          'kanban',
          'org_chart',
          'state_machine',
          'venn',
          'timeline',
          'gantt',
          'decision_tree',
        ]),
      );
    });

    test('flowchart template has cards and connections', () {
      final flowchart =
          CanvasTemplatesService.builtInTemplates['flowchart']!;
      expect(flowchart.cards, isNotEmpty);
      expect(flowchart.connections, isNotEmpty);
    });

    test('flowchart template has Start and End cards', () {
      final flowchart =
          CanvasTemplatesService.builtInTemplates['flowchart']!;
      final titles = flowchart.cards.map((c) => c.title).toSet();
      expect(titles, containsAll(['Start', 'End']));
    });

    test('mindmap template has Central Topic card', () {
      final mindmap =
          CanvasTemplatesService.builtInTemplates['mindmap']!;
      final titles = mindmap.cards.map((c) => c.title).toSet();
      expect(titles, contains('Central Topic'));
    });

    test('network template has Cloud/Internet card', () {
      final network =
          CanvasTemplatesService.builtInTemplates['network']!;
      final titles = network.cards.map((c) => c.title).toSet();
      expect(titles, contains('Cloud / Internet'));
    });

    test('all templates have at least one card', () {
      for (final entry in CanvasTemplatesService.builtInTemplates.entries) {
        expect(
          entry.value.cards,
          isNotEmpty,
          reason: 'Template "${entry.key}" should have at least one card',
        );
      }
    });

    test('all template connections reference valid card IDs', () {
      for (final entry in CanvasTemplatesService.builtInTemplates.entries) {
        final cardIds = entry.value.cards.map((c) => c.id).toSet();
        for (final conn in entry.value.connections) {
          expect(
            cardIds,
            contains(conn.fromCardId),
            reason:
                'Template "${entry.key}": connection ${conn.id} fromCardId "${conn.fromCardId}" not found',
          );
          expect(
            cardIds,
            contains(conn.toCardId),
            reason:
                'Template "${entry.key}": connection ${conn.id} toCardId "${conn.toCardId}" not found',
          );
        }
      }
    });

    test('kanban template has swimlaneV type cards', () {
      final kanban =
          CanvasTemplatesService.builtInTemplates['kanban']!;
      final hasSwimlaneV = kanban.cards.any(
        (c) => c.type == CanvasCardType.swimlaneV,
      );
      expect(hasSwimlaneV, isTrue);
    });
  });
}

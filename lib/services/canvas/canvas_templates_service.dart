import '../../data/models/canvas_model.dart';

part 'templates/templates_flow.dart';
part 'templates/templates_diagrams.dart';
part 'templates/templates_layouts.dart';

class CanvasTemplatesService {
  const CanvasTemplatesService();

  static final Map<String, Map<String, List<CanvasCardType>>>
  shapeLibraryCategories = {
    'General': {
      'Basic': [
        CanvasCardType.rectangle,
        CanvasCardType.roundedRect,
        CanvasCardType.ellipse,
        CanvasCardType.diamond,
        CanvasCardType.triangle,
      ],
    },
    'Flowchart': {
      'Flow': [
        CanvasCardType.roundedRect,
        CanvasCardType.diamond,
        CanvasCardType.parallelogram,
        CanvasCardType.rectangle,
      ],
    },
    'UML': {
      'Class': [
        CanvasCardType.rectangle,
        CanvasCardType.diamond,
        CanvasCardType.ellipse,
        CanvasCardType.roundedRect,
      ],
    },
    'Network': {
      'Infrastructure': [
        CanvasCardType.cylinder,
        CanvasCardType.hexagon,
        CanvasCardType.ellipse,
        CanvasCardType.rectangle,
      ],
    },
    'Tables': {
      'Data': [CanvasCardType.table],
    },
    'Containers': {
      'Layout': [
        CanvasCardType.container,
        CanvasCardType.swimlaneH,
        CanvasCardType.swimlaneV,
      ],
    },
    'Decorative': {
      'Shapes': [
        CanvasCardType.star,
        CanvasCardType.hexagon,
        CanvasCardType.freehand,
      ],
    },
  };

  static final Map<String, CanvasData> builtInTemplates = {
    ..._flowTemplates,
    ..._diagramTemplates,
    ..._layoutTemplates,
  };
}

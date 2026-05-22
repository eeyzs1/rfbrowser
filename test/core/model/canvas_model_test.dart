import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';

void main() {
  group('CanvasCard with noteId', () {
    test('AC-M-1: card with noteId serializes/deserializes correctly', () {
      final card = CanvasCard(
        id: 'c1',
        type: CanvasCardType.note,
        noteId: 'note-123',
        title: '',
        content: '',
      );
      final json = card.toJson();
      final restored = CanvasCard.fromJson(json);
      expect(restored.noteId, equals('note-123'));
      expect(restored.type, equals(CanvasCardType.note));
    });

    test('AC-M-2: card without noteId has null noteId', () {
      final card = CanvasCard(
        id: 'c2',
        type: CanvasCardType.text,
        title: 'Hello',
        content: 'World',
      );
      expect(card.noteId, isNull);
    });
  });

  group('CanvasConnection isAuto flag', () {
    test('AC-M-3: manual connection has isAuto=false by default', () {
      final conn = CanvasConnection(
        id: 'conn1',
        fromCardId: 'a',
        toCardId: 'b',
      );
      expect(conn.isAuto, isFalse);
    });

    test('AC-M-4: auto connection serializes isAuto in JSON', () {
      final conn = CanvasConnection(
        id: 'conn_auto1',
        fromCardId: 'a',
        toCardId: 'b',
        isAuto: true,
      );
      final json = conn.toJson();
      expect(json['isAuto'], isTrue);
    });

    test(
      'AC-M-5: old JSON without isAuto -> isAuto=false after deserialization',
      () {
        final json = <String, dynamic>{
          'id': 'old_conn',
          'fromCardId': 'a',
          'toCardId': 'b',
          'fromSide': 3,
          'toSide': 2,
          'label': '',
        };
        final conn = CanvasConnection.fromJson(json);
        expect(conn.isAuto, isFalse);
      },
    );
  });

  group('CanvasSettings', () {
    test('AC-M-6: default autoConnectionsEnabled is true', () {
      final settings = CanvasSettings();
      expect(settings.autoConnectionsEnabled, isTrue);
    });
  });

  group('CanvasCardStyle', () {
    test('defaults have expected values', () {
      const style = CanvasCardStyle.defaults;
      expect(style.fillColor, equals(0xFFFFFFFF));
      expect(style.gradientColor, isNull);
      expect(style.borderColor, equals(0xFFE0E0E0));
      expect(style.borderWidth, equals(1.0));
      expect(style.borderStyle, equals(CardBorderStyle.solid));
      expect(style.borderRadius, equals(8.0));
      expect(style.opacity, equals(1.0));
      expect(style.shadow, isTrue);
    });

    test('round-trip serialization preserves all fields', () {
      const style = CanvasCardStyle(
        fillColor: 0xFFE3F2FD,
        gradientColor: 0xFF90CAF9,
        gradientDirection: GradientDirection.leftToRight,
        borderColor: 0xFF1565C0,
        borderWidth: 2.0,
        borderStyle: CardBorderStyle.dashed,
        borderRadius: 12.0,
        opacity: 0.8,
        shadow: false,
      );
      final json = style.toJson();
      final restored = CanvasCardStyle.fromJson(json);
      expect(restored.fillColor, equals(0xFFE3F2FD));
      expect(restored.gradientColor, equals(0xFF90CAF9));
      expect(restored.gradientDirection, equals(GradientDirection.leftToRight));
      expect(restored.borderColor, equals(0xFF1565C0));
      expect(restored.borderWidth, equals(2.0));
      expect(restored.borderStyle, equals(CardBorderStyle.dashed));
      expect(restored.borderRadius, equals(12.0));
      expect(restored.opacity, equals(0.8));
      expect(restored.shadow, isFalse);
    });

    test('old JSON without gradientColor -> gradientColor is null', () {
      final json = <String, dynamic>{
        'fillColor': 0xFFFFFFFF,
        'gradientDirection': 0,
        'borderColor': 0xFFE0E0E0,
        'borderWidth': 1.0,
        'borderStyle': 0,
        'borderRadius': 8.0,
        'opacity': 1.0,
        'shadow': true,
      };
      final restored = CanvasCardStyle.fromJson(json);
      expect(restored.gradientColor, isNull);
    });

    test('copyWith clearGradient sets gradientColor to null', () {
      const style = CanvasCardStyle(gradientColor: 0xFF90CAF9);
      final cleared = style.copyWith(clearGradient: true);
      expect(cleared.gradientColor, isNull);
    });
  });

  group('CanvasConnectionStyle', () {
    test('defaults have expected values', () {
      const style = CanvasConnectionStyle.defaults;
      expect(style.pathType, equals(ConnectionPath.curved));
      expect(style.arrowStyle, equals(ArrowStyle.filledTriangle));
      expect(style.strokeWidth, equals(2.0));
      expect(style.colorValue, equals(0xFF000000));
    });

    test('round-trip serialization preserves all fields', () {
      const style = CanvasConnectionStyle(
        pathType: ConnectionPath.orthogonal,
        arrowStyle: ArrowStyle.diamond,
        strokeWidth: 3.5,
        colorValue: 0xFF1565C0,
      );
      final json = style.toJson();
      final restored = CanvasConnectionStyle.fromJson(json);
      expect(restored.pathType, equals(ConnectionPath.orthogonal));
      expect(restored.arrowStyle, equals(ArrowStyle.diamond));
      expect(restored.strokeWidth, equals(3.5));
      expect(restored.colorValue, equals(0xFF1565C0));
    });

    test('old JSON without style -> connection.style is null', () {
      final json = <String, dynamic>{
        'id': 'c1',
        'fromCardId': 'a',
        'toCardId': 'b',
        'fromSide': 3,
        'toSide': 2,
        'label': '',
        'isAuto': false,
      };
      final conn = CanvasConnection.fromJson(json);
      expect(conn.style, isNull);
    });
  });

  group('CanvasGroup', () {
    test('round-trip serialization preserves all fields', () {
      final group = CanvasGroup(
        id: 'g1',
        name: 'My Group',
        cardIds: ['c1', 'c2', 'c3'],
        colorValue: 0xFFE3F2FD,
      );
      final json = group.toJson();
      final restored = CanvasGroup.fromJson(json);
      expect(restored.id, equals('g1'));
      expect(restored.name, equals('My Group'));
      expect(restored.cardIds, equals(['c1', 'c2', 'c3']));
      expect(restored.colorValue, equals(0xFFE3F2FD));
    });

    test('old JSON without cardIds -> empty list', () {
      final json = <String, dynamic>{'id': 'g2', 'name': 'Empty'};
      final restored = CanvasGroup.fromJson(json);
      expect(restored.cardIds, isEmpty);
      expect(restored.colorValue, equals(0xFFFFFFFF));
    });
  });

  group('CanvasCard container', () {
    test('container card with childIds and collapsed serializes correctly', () {
      final card = CanvasCard(
        id: 'cont1',
        type: CanvasCardType.container,
        title: 'My Container',
        childIds: ['c1', 'c2'],
        collapsed: true,
      );
      final json = card.toJson();
      final restored = CanvasCard.fromJson(json);
      expect(restored.type, equals(CanvasCardType.container));
      expect(restored.childIds, equals(['c1', 'c2']));
      expect(restored.collapsed, isTrue);
    });

    test('old JSON without childIds/collapsed -> defaults', () {
      final json = <String, dynamic>{
        'id': 'old1',
        'type': 0,
        'x': 0.0,
        'y': 0.0,
        'width': 240.0,
        'height': 160.0,
        'title': '',
        'content': '',
      };
      final restored = CanvasCard.fromJson(json);
      expect(restored.childIds, isEmpty);
      expect(restored.collapsed, isFalse);
      expect(restored.style, isNull);
    });

    test('card with style serializes and deserializes correctly', () {
      final card = CanvasCard(
        id: 'styled1',
        type: CanvasCardType.note,
        title: 'Styled',
        style: const CanvasCardStyle(
          borderRadius: 16.0,
          borderStyle: CardBorderStyle.dashed,
          shadow: false,
          gradientColor: 0xFF90CAF9,
        ),
      );
      final json = card.toJson();
      final restored = CanvasCard.fromJson(json);
      expect(restored.style, isNotNull);
      expect(restored.style!.borderRadius, equals(16.0));
      expect(restored.style!.borderStyle, equals(CardBorderStyle.dashed));
      expect(restored.style!.shadow, isFalse);
      expect(restored.style!.gradientColor, equals(0xFF90CAF9));
    });

    test('copyWith clearStyle sets style to null', () {
      final card = CanvasCard(
        id: 'c1',
        type: CanvasCardType.note,
        style: const CanvasCardStyle(borderRadius: 16.0),
      );
      final cleared = card.copyWith(clearStyle: true);
      expect(cleared.style, isNull);
    });
  });

  group('CanvasData round-trip', () {
    test('toJsonString includes CanvasSettings section', () {
      final data = CanvasData(
        settings: CanvasSettings(autoConnectionsEnabled: false),
      );
      final json = data.toJsonString();
      expect(json.contains('autoConnectionsEnabled'), isTrue);
      expect(json.contains('false'), isTrue);
    });

    test('fromJsonString handles missing settings gracefully', () {
      final json = '{"cards":[],"connections":[]}';
      final data = CanvasData.fromJsonString(json);
      expect(data.settings.autoConnectionsEnabled, isTrue);
      expect(data.groups, isEmpty);
      expect(data.selectedCardIds, isEmpty);
    });

    test('corrupt JSON returns empty CanvasData, no exception', () {
      final data = CanvasData.fromJsonString('{not valid json}}');
      expect(data.cards, isEmpty);
      expect(data.connections, isEmpty);
      expect(data.groups, isEmpty);
    });

    test('full round-trip preserves all data including groups and styles', () {
      final original = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.note,
            x: 100,
            y: 200,
            width: 300,
            height: 180,
            title: 'Test',
            content: 'Hello World',
            noteId: 'note-1',
            style: const CanvasCardStyle(
              borderRadius: 12.0,
              borderStyle: CardBorderStyle.dotted,
              opacity: 0.9,
            ),
          ),
          CanvasCard(
            id: 'cont1',
            type: CanvasCardType.container,
            title: 'Container',
            childIds: ['c1'],
            collapsed: false,
          ),
        ],
        connections: [
          CanvasConnection(
            id: 'conn1',
            fromCardId: 'c1',
            toCardId: 'c2',
            label: 'relates to',
            isAuto: false,
            style: const CanvasConnectionStyle(
              pathType: ConnectionPath.straight,
              arrowStyle: ArrowStyle.diamond,
              strokeWidth: 3.0,
              colorValue: 0xFF1565C0,
            ),
          ),
        ],
        groups: [
          CanvasGroup(id: 'g1', name: 'Group 1', cardIds: ['c1']),
        ],
        settings: CanvasSettings(autoConnectionsEnabled: false),
      );
      final json = original.toJsonString();
      final restored = CanvasData.fromJsonString(json);
      expect(restored.cards.length, equals(2));
      expect(restored.cards.first.title, equals('Test'));
      expect(restored.cards.first.noteId, equals('note-1'));
      expect(restored.cards.first.style?.borderRadius, equals(12.0));
      expect(
        restored.cards.first.style?.borderStyle,
        equals(CardBorderStyle.dotted),
      );
      expect(restored.cards[1].type, equals(CanvasCardType.container));
      expect(restored.cards[1].childIds, equals(['c1']));
      expect(restored.connections.length, equals(1));
      expect(
        restored.connections.first.style?.pathType,
        equals(ConnectionPath.straight),
      );
      expect(
        restored.connections.first.style?.arrowStyle,
        equals(ArrowStyle.diamond),
      );
      expect(restored.groups.length, equals(1));
      expect(restored.groups.first.name, equals('Group 1'));
      expect(restored.settings.autoConnectionsEnabled, isFalse);
    });

    test('old JSON without groups -> groups is empty', () {
      final json =
          '{"cards":[],"connections":[],"settings":{"autoConnectionsEnabled":true,"snapToGrid":true,"gridVisible":true,"lastModified":"2026-01-01T00:00:00.000"}}';
      final data = CanvasData.fromJsonString(json);
      expect(data.groups, isEmpty);
      expect(data.selectedCardIds, isEmpty);
    });
  });

  group('CanvasSearchState', () {
    test('isActive returns true when query is non-empty', () {
      final state = CanvasSearchState(query: 'search term');
      expect(state.isActive, isTrue);
    });

    test('isActive returns false when query is empty', () {
      final state = CanvasSearchState();
      expect(state.isActive, isFalse);
    });

    test('copyWith updates fields correctly', () {
      final state = CanvasSearchState(query: 'test');
      final updated = state.copyWith(
        matchedCardIds: ['c1', 'c2'],
        activeIndex: 1,
      );
      expect(updated.query, equals('test'));
      expect(updated.matchedCardIds, equals(['c1', 'c2']));
      expect(updated.activeIndex, equals(1));
      expect(updated.isActive, isTrue);
    });
  });

  group('CanvasData copyWith', () {
    test('clearSelectedCardIds sets selectedCardIds to empty', () {
      final data = CanvasData(selectedCardIds: ['c1', 'c2']);
      final cleared = data.copyWith(clearSelectedCardIds: true);
      expect(cleared.selectedCardIds, isEmpty);
    });

    test('clearInlineEditingCardId sets inlineEditingCardId to null', () {
      final data = CanvasData(inlineEditingCardId: 'c1');
      final cleared = data.copyWith(clearInlineEditingCardId: true);
      expect(cleared.inlineEditingCardId, isNull);
    });
  });

  group('AlignmentGuide', () {
    test('can be created and fields accessed', () {
      const guide = AlignmentGuide(
        start: Offset(0, 0),
        end: Offset(100, 0),
        type: AlignmentGuideType.centerVertical,
      );
      expect(guide.start, equals(const Offset(0, 0)));
      expect(guide.end, equals(const Offset(100, 0)));
      expect(guide.type, equals(AlignmentGuideType.centerVertical));
    });
  });

  group('CanvasCardType.container', () {
    test('has correct label and icon', () {
      expect(CanvasCardType.container.label, equals('Container'));
      expect(CanvasCardType.container.icon, equals(Icons.crop_square));
    });
  });

  group('CanvasCard image type', () {
    test('AC-IMP-8-1: canvas card stores image URL in content field', () {
      final card = CanvasCard(
        id: 'model-test',
        type: CanvasCardType.image,
        x: 0,
        y: 0,
        width: 200,
        height: 150,
        title: 'Cat Photo',
        content: 'https://example.com/cat.jpg',
      );

      expect(card.type, equals(CanvasCardType.image));
      expect(card.content, equals('https://example.com/cat.jpg'));
      expect(card.title, equals('Cat Photo'));
      expect(card.content.isEmpty, isFalse);
    });

    test('AC-IMP-8-2: empty content card still has valid model state', () {
      final card = CanvasCard(
        id: 'empty',
        type: CanvasCardType.image,
        x: 50,
        y: 60,
        width: 100,
        height: 100,
        title: '',
        content: '',
      );

      expect(card.content.isEmpty, isTrue);
      expect(card.type, equals(CanvasCardType.image));
      expect(card.width, equals(100));
      expect(card.height, equals(100));
    });

    test('AC-IMP-8-3: copyWith preserves image dimensions and content', () {
      final card = CanvasCard(
        id: 'orig',
        type: CanvasCardType.image,
        x: 10,
        y: 20,
        width: 300,
        height: 200,
        title: 'Original',
        content: 'https://example.com/img.png',
      );

      final updated = card.copyWith(title: 'Updated');
      expect(updated.content, equals('https://example.com/img.png'));
      expect(updated.type, equals(CanvasCardType.image));
      expect(updated.title, equals('Updated'));
      expect(updated.width, equals(300));
      expect(updated.height, equals(200));
    });

    test('canvas card image type has correct icon and label', () {
      final card = CanvasCard(
        id: 'type-test',
        type: CanvasCardType.image,
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        title: '',
        content: '',
      );

      expect(card.type.label, equals('Image'));
      expect(card.type.icon, isNotNull);
    });

    test('image card stores local file path in content', () {
      final card = CanvasCard(
        id: 'local',
        type: CanvasCardType.image,
        x: 0,
        y: 0,
        width: 200,
        height: 200,
        title: 'Local Photo',
        content: 'C:/photos/screenshot.png',
      );

      expect(card.content, equals('C:/photos/screenshot.png'));
      expect(card.title, equals('Local Photo'));
    });
  });

  group('CanvasLayer', () {
    test('round-trip serialization preserves all fields', () {
      final layer = CanvasLayer(
        id: 'layer1',
        name: 'Background',
        visible: false,
        locked: true,
        order: 2,
      );
      final json = layer.toJson();
      final restored = CanvasLayer.fromJson(json);
      expect(restored.id, equals('layer1'));
      expect(restored.name, equals('Background'));
      expect(restored.visible, isFalse);
      expect(restored.locked, isTrue);
      expect(restored.order, equals(2));
    });

    test('old JSON without optional fields -> defaults', () {
      final json = <String, dynamic>{'id': 'l1', 'name': 'Test'};
      final restored = CanvasLayer.fromJson(json);
      expect(restored.visible, isTrue);
      expect(restored.locked, isFalse);
      expect(restored.order, equals(0));
    });

    test('copyWith updates fields correctly', () {
      const layer = CanvasLayer(id: 'l1', name: 'A', order: 0);
      final updated = layer.copyWith(
        name: 'B',
        visible: false,
        locked: true,
        order: 3,
      );
      expect(updated.name, equals('B'));
      expect(updated.visible, isFalse);
      expect(updated.locked, isTrue);
      expect(updated.order, equals(3));
      expect(updated.id, equals('l1'));
    });
  });

  group('CanvasCard with layerId', () {
    test('card with layerId serializes correctly', () {
      final card = CanvasCard(
        id: 'c1',
        type: CanvasCardType.note,
        layerId: 'layer1',
      );
      final json = card.toJson();
      final restored = CanvasCard.fromJson(json);
      expect(restored.layerId, equals('layer1'));
    });

    test('card without layerId -> layerId is null', () {
      final card = CanvasCard(id: 'c2', type: CanvasCardType.text);
      expect(card.layerId, isNull);
      final json = card.toJson();
      expect(json.containsKey('layerId'), isFalse);
    });

    test('copyWith clearLayerId sets layerId to null', () {
      final card = CanvasCard(
        id: 'c1',
        type: CanvasCardType.note,
        layerId: 'l1',
      );
      final cleared = card.copyWith(clearLayerId: true);
      expect(cleared.layerId, isNull);
    });
  });

  group('CanvasConnection with waypoints', () {
    test('connection with waypoints serializes correctly', () {
      final conn = CanvasConnection(
        id: 'conn1',
        fromCardId: 'a',
        toCardId: 'b',
        waypoints: [const Offset(100, 200), const Offset(300, 400)],
      );
      final json = conn.toJson();
      final restored = CanvasConnection.fromJson(json);
      expect(restored.waypoints.length, equals(2));
      expect(restored.waypoints[0], equals(const Offset(100, 200)));
      expect(restored.waypoints[1], equals(const Offset(300, 400)));
    });

    test('connection without waypoints -> empty list', () {
      final conn = CanvasConnection(id: 'c1', fromCardId: 'a', toCardId: 'b');
      expect(conn.waypoints, isEmpty);
      final json = conn.toJson();
      expect(json.containsKey('waypoints'), isFalse);
    });

    test('old JSON without waypoints -> empty list', () {
      final json = <String, dynamic>{
        'id': 'c1',
        'fromCardId': 'a',
        'toCardId': 'b',
        'fromSide': 3,
        'toSide': 2,
        'label': '',
        'isAuto': false,
      };
      final restored = CanvasConnection.fromJson(json);
      expect(restored.waypoints, isEmpty);
    });

    test('copyWith waypoints updates correctly', () {
      final conn = CanvasConnection(id: 'c1', fromCardId: 'a', toCardId: 'b');
      final withWp = conn.copyWith(waypoints: [const Offset(50, 60)]);
      expect(withWp.waypoints.length, equals(1));
      expect(withWp.waypoints.first, equals(const Offset(50, 60)));
    });
  });

  group('ScratchpadItem', () {
    test('round-trip serialization preserves all fields', () {
      final item = ScratchpadItem(
        id: 'sp1',
        name: 'My Template',
        type: CanvasCardType.note,
        width: 300,
        height: 200,
        colorValue: 0xFFE3F2FD,
        style: const CanvasCardStyle(borderRadius: 12.0),
        category: 'Work',
      );
      final json = item.toJson();
      final restored = ScratchpadItem.fromJson(json);
      expect(restored.id, equals('sp1'));
      expect(restored.name, equals('My Template'));
      expect(restored.type, equals(CanvasCardType.note));
      expect(restored.width, equals(300));
      expect(restored.height, equals(200));
      expect(restored.colorValue, equals(0xFFE3F2FD));
      expect(restored.style?.borderRadius, equals(12.0));
      expect(restored.category, equals('Work'));
    });

    test('old JSON without category -> defaults to General', () {
      final json = <String, dynamic>{
        'id': 'sp1',
        'name': 'Test',
        'type': 0,
        'width': 240.0,
        'height': 160.0,
        'colorValue': 0xFFFFFFFF,
      };
      final restored = ScratchpadItem.fromJson(json);
      expect(restored.category, equals('General'));
    });
  });

  group('CanvasData with layers', () {
    test('toJsonString includes layers', () {
      final data = CanvasData(
        layers: [
          CanvasLayer(id: 'l1', name: 'Layer 1', order: 0),
          CanvasLayer(id: 'l2', name: 'Layer 2', visible: false, order: 1),
        ],
      );
      final json = data.toJsonString();
      final restored = CanvasData.fromJsonString(json);
      expect(restored.layers.length, equals(2));
      expect(restored.layers[0].name, equals('Layer 1'));
      expect(restored.layers[1].visible, isFalse);
    });

    test('old JSON without layers -> empty list', () {
      final json =
          '{"cards":[],"connections":[],"settings":{"autoConnectionsEnabled":true,"snapToGrid":true,"gridVisible":true,"lastModified":"2026-01-01T00:00:00.000"}}';
      final data = CanvasData.fromJsonString(json);
      expect(data.layers, isEmpty);
    });
  });
}

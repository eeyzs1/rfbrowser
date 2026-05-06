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

    test('AC-M-5: old JSON without isAuto -> isAuto=false after deserialization', () {
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
    });
  });

  group('CanvasSettings', () {
    test('AC-M-6: default autoConnectionsEnabled is true', () {
      final settings = CanvasSettings();
      expect(settings.autoConnectionsEnabled, isTrue);
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
    });

    test('corrupt JSON returns empty CanvasData, no exception', () {
      final data = CanvasData.fromJsonString('{not valid json}}');
      expect(data.cards, isEmpty);
      expect(data.connections, isEmpty);
    });

    test('full round-trip preserves all data', () {
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
          ),
        ],
        connections: [
          CanvasConnection(
            id: 'conn1',
            fromCardId: 'c1',
            toCardId: 'c2',
            label: 'relates to',
            isAuto: false,
          ),
        ],
        settings: CanvasSettings(autoConnectionsEnabled: false),
      );
      final json = original.toJsonString();
      final restored = CanvasData.fromJsonString(json);
      expect(restored.cards.length, equals(1));
      expect(restored.cards.first.title, equals('Test'));
      expect(restored.cards.first.noteId, equals('note-1'));
      expect(restored.connections.length, equals(1));
      expect(restored.connections.first.isAuto, isFalse);
      expect(restored.connections.first.label, equals('relates to'));
      expect(restored.settings.autoConnectionsEnabled, isFalse);
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
      final updated = state.copyWith(matchedCardIds: ['c1', 'c2'], activeIndex: 1);
      expect(updated.query, equals('test'));
      expect(updated.matchedCardIds, equals(['c1', 'c2']));
      expect(updated.activeIndex, equals(1));
      expect(updated.isActive, isTrue);
    });
  });
}

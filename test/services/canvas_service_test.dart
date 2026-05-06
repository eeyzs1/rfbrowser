import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/services/canvas_service.dart';

void main() {
  test('AC-M-3: manual connection has isAuto=false by default', () {
    final conn = CanvasConnection(
      id: 'conn1',
      fromCardId: 'a',
      toCardId: 'b',
    );
    expect(conn.isAuto, isFalse);
  });

  group('CanvasNotifier search', () {
    late ProviderContainer container;
    late CanvasNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      notifier = container.read(canvasProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    void addCards(List<CanvasCard> cards) {
      for (final card in cards) {
        notifier.addCardSync(card);
      }
    }

    test('AC-S-8: searchCards matches title (case-insensitive)', () {
      addCards([
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Research Notes', content: ''),
        CanvasCard(id: 'c2', type: CanvasCardType.text, title: 'Shopping List', content: ''),
        CanvasCard(id: 'c3', type: CanvasCardType.text, title: 'Research Methods', content: ''),
      ]);

      final results = notifier.searchCards('research');
      expect(results.length, equals(2));
      expect(results.map((c) => c.title), containsAll(['Research Notes', 'Research Methods']));
    });

    test('AC-S-9: searchCards matches content', () {
      addCards([
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Note 1', content: 'learn Flutter state management'),
      ]);

      final results = notifier.searchCards('flutter');
      expect(results.length, equals(1));
      expect(results.first.content, contains('Flutter'));
    });

    test('AC-S-10: searchCards empty query returns all', () {
      addCards([
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'A', content: ''),
        CanvasCard(id: 'c2', type: CanvasCardType.text, title: 'B', content: ''),
      ]);

      final results = notifier.searchCards('');
      expect(results.length, equals(2));
    });

    test('AC-S-11: searchCards no match returns empty', () {
      addCards([
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Note', content: ''),
      ]);

      final results = notifier.searchCards('xyzwqk');
      expect(results, isEmpty);
    });
  });

  group('CanvasNotifier auto connections', () {
    late ProviderContainer container;
    late CanvasNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      notifier = container.read(canvasProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    void addCardsSync(List<CanvasCard> cards) {
      for (final card in cards) {
        notifier.addCardSync(card);
      }
    }

    test('AC-S-1: deriveAutoConnections returns empty when disabled', () {
      addCardsSync([
        CanvasCard(id: 'c1', type: CanvasCardType.note, noteId: 'note-A', x: 0, y: 0, title: 'A', content: ''),
        CanvasCard(id: 'c2', type: CanvasCardType.note, noteId: 'note-B', x: 200, y: 0, title: 'B', content: ''),
      ]);

      notifier.toggleAutoConnections();
      final results = notifier.deriveAutoConnections([], null);
      expect(results, isEmpty);
    });

    test('AC-S-4: cards without noteId not included in auto connections', () {
      addCardsSync([
        CanvasCard(id: 'c1', type: CanvasCardType.note, noteId: 'note-A', x: 0, y: 0, title: 'Note A', content: ''),
        CanvasCard(id: 'c2', type: CanvasCardType.text, x: 200, y: 0, title: 'Text Card', content: ''),
      ]);

      final noteA = Note(id: 'note-A', title: 'Note A', filePath: 'note-a.md', content: '[[Text Card]]');
      final results = notifier.deriveAutoConnections([noteA], null);
      expect(results, isEmpty);
    });

    test('autoConnectionsEnabled is true by default', () {
      expect(notifier.autoConnectionsEnabled, isTrue);
    });

    test('toggleAutoConnections toggles the setting', () {
      expect(notifier.autoConnectionsEnabled, isTrue);
      notifier.toggleAutoConnections();
      expect(notifier.autoConnectionsEnabled, isFalse);
      notifier.toggleAutoConnections();
      expect(notifier.autoConnectionsEnabled, isTrue);
    });
  });

  group('CanvasData persistence', () {
    test('AC-S-5: toJsonString includes CanvasSettings', () {
      final data = CanvasData(
        cards: [],
        connections: [],
        settings: CanvasSettings(autoConnectionsEnabled: false),
      );
      final json = data.toJsonString();
      expect(json.contains('autoConnectionsEnabled'), isTrue);
    });

    test('AC-S-6: fromJsonString handles missing settings gracefully', () {
      final json = '{"cards":[],"connections":[]}';
      final data = CanvasData.fromJsonString(json);
      expect(data.settings.autoConnectionsEnabled, isTrue);
    });

    test('AC-S-7: corrupt JSON returns empty CanvasData, no exception', () {
      final data = CanvasData.fromJsonString('{not valid json}}');
      expect(data.cards, isEmpty);
      expect(data.connections, isEmpty);
    });
  });

  group('CanvasConnection isAuto flag', () {
    test('manual connection has isAuto=false by default', () {
      final conn = CanvasConnection(id: 'c1', fromCardId: 'a', toCardId: 'b');
      expect(conn.isAuto, isFalse);
    });

    test('auto connection has isAuto=true', () {
      final conn = CanvasConnection(id: 'c1', fromCardId: 'a', toCardId: 'b', isAuto: true);
      expect(conn.isAuto, isTrue);
    });

    test('old JSON without isAuto defaults to false', () {
      final json = <String, dynamic>{
        'id': 'old', 'fromCardId': 'a', 'toCardId': 'b',
        'fromSide': 3, 'toSide': 2, 'label': '',
      };
      final conn = CanvasConnection.fromJson(json);
      expect(conn.isAuto, isFalse);
    });
  });
}

extension CanvasNotifierTestExtension on CanvasNotifier {
  void addCardSync(CanvasCard card) {
    state = state.copyWith(cards: [...state.cards, card]);
  }
}

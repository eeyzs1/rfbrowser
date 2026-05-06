import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/services/canvas_service.dart';

void main() {
  group('Canvas Integration Tests', () {
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

    test('UI-1: card real-time sync - noteId card renders live note data', () {
      final card = CanvasCard(
        id: 'c1',
        type: CanvasCardType.note,
        noteId: 'note-1',
        x: 100, y: 100,
        title: 'Old Title',
        content: 'Old Content',
      );
      addCardsSync([card]);

      final retrievedCard = notifier.cardById('c1');
      expect(retrievedCard, isNotNull);
      expect(retrievedCard!.noteId, equals('note-1'));
      expect(retrievedCard.title, equals('Old Title'));
    });

    test('UI-2: auto connections appear for wikilink-related notes', () {
      addCardsSync([
        CanvasCard(id: 'c1', type: CanvasCardType.note, noteId: 'note-A', x: 0, y: 0, title: 'Note A', content: ''),
        CanvasCard(id: 'c2', type: CanvasCardType.note, noteId: 'note-B', x: 200, y: 0, title: 'Note B', content: ''),
      ]);

      final noteA = Note(
        id: 'note-A',
        title: 'Note A',
        filePath: 'note-a.md',
        content: 'See [[Note B]] for more details.',
      );
      final noteB = Note(
        id: 'note-B',
        title: 'Note B',
        filePath: 'note-b.md',
        content: 'Related to Note A',
      );

      expect(notifier.autoConnectionsEnabled, isTrue);
      expect(notifier.state.cards.length, equals(2));
      expect(notifier.state.cards.where((c) => c.noteId != null).length, equals(2));
      expect(noteA.content.contains('[[Note B]]'), isTrue);
      expect(noteB.title, 'Note B');
    });

    test('UI-3: search for cards by title (case-insensitive)', () {
      addCardsSync([
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Research Notes', content: ''),
        CanvasCard(id: 'c2', type: CanvasCardType.text, title: 'Shopping List', content: ''),
        CanvasCard(id: 'c3', type: CanvasCardType.text, title: 'Research Methods', content: ''),
      ]);

      final results = notifier.searchCards('research');
      expect(results.length, equals(2));
    });

    test('UI-4: persistence round-trip preserves cards and connections', () {
      addCardsSync([
        CanvasCard(id: 'c1', type: CanvasCardType.note, x: 10, y: 20, title: 'Card 1', content: 'Content 1'),
        CanvasCard(id: 'c2', type: CanvasCardType.note, x: 100, y: 200, title: 'Card 2', content: 'Content 2'),
      ]);

      notifier.addConnectionSync(CanvasConnection(
        id: 'conn1',
        fromCardId: 'c1',
        toCardId: 'c2',
        label: 'relates to',
        isAuto: false,
      ));

      final json = notifier.state.toJsonString();
      final restored = CanvasData.fromJsonString(json);

      expect(restored.cards.length, equals(2));
      expect(restored.connections.length, equals(1));
      expect(restored.connections.first.label, equals('relates to'));
      expect(restored.connections.first.isAuto, isFalse);
    });

    test('UI-5: clear canvas removes all cards and connections', () {
      addCardsSync([
        CanvasCard(id: 'c1', type: CanvasCardType.note, x: 10, y: 20, title: 'Card 1', content: ''),
        CanvasCard(id: 'c2', type: CanvasCardType.note, x: 100, y: 200, title: 'Card 2', content: ''),
      ]);

      notifier.addConnectionSync(CanvasConnection(
        id: 'conn1', fromCardId: 'c1', toCardId: 'c2',
      ));

      expect(notifier.state.cards.length, equals(2));
      expect(notifier.state.connections.length, equals(1));

      notifier.clearCanvasSync();

      expect(notifier.state.cards, isEmpty);
      expect(notifier.state.connections, isEmpty);
    });
  });
}

extension CanvasNotifierTestExtension on CanvasNotifier {
  void addCardSync(CanvasCard card) {
    state = state.copyWith(cards: [...state.cards, card]);
  }

  void addConnectionSync(CanvasConnection conn) {
    state = state.copyWith(connections: [...state.connections, conn]);
  }

  void clearCanvasSync() {
    state = CanvasData();
  }
}

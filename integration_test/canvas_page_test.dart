import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CanvasData Model (C-4 compliance)', () {
    test('copyWith clearSelectedCardIds works', () {
      final data = CanvasData(
        cards: [
          CanvasCard(id: 'card1', type: CanvasCardType.text, title: 'Card 1'),
        ],
        selectedCardIds: ['card1'],
      );

      final cleared = data.copyWith(clearSelectedCardIds: true);
      expect(cleared.selectedCardIds, isEmpty);
      expect(cleared.cards.length, equals(1));
    });

    test('copyWith clearInlineEditingCardId works', () {
      final data = CanvasData(inlineEditingCardId: 'card1');

      final cleared = data.copyWith(clearInlineEditingCardId: true);
      expect(cleared.inlineEditingCardId, isNull);
    });

    test('copyWith clearSelectedConnectionId works', () {
      final data = CanvasData(selectedConnectionId: 'conn1');

      final cleared = data.copyWith(clearSelectedConnectionId: true);
      expect(cleared.selectedConnectionId, isNull);
    });

    test('copyWith preserves existing values when not overridden', () {
      final card = CanvasCard(id: 'card1', type: CanvasCardType.text, title: 'Card 1');
      final conn = CanvasConnection(id: 'conn1', fromCardId: 'card1', toCardId: 'card2');
      final data = CanvasData(
        cards: [card],
        connections: [conn],
        selectedCardIds: ['card1'],
      );

      final copied = data.copyWith();
      expect(copied.cards.length, equals(1));
      expect(copied.connections.length, equals(1));
      expect(copied.selectedCardIds.length, equals(1));
    });

    test('CanvasCard copyWith preserves id and type', () {
      final card = CanvasCard(id: 'card1', type: CanvasCardType.text, title: 'Card 1');
      final copied = card.copyWith(title: 'Updated Card');

      expect(copied.id, equals('card1'));
      expect(copied.title, equals('Updated Card'));
      expect(copied.type, equals(CanvasCardType.text));
    });

    test('CanvasCard default dimensions', () {
      final card = CanvasCard(id: 'card1', type: CanvasCardType.text);
      expect(card.width, equals(160));
      expect(card.height, equals(100));
    });

    test('CanvasConnection computeSides horizontal right', () {
      final from = CanvasCard(id: 'from', type: CanvasCardType.text, x: 0, y: 0);
      final to = CanvasCard(id: 'to', type: CanvasCardType.text, x: 300, y: 0);

      final (fromSide, toSide) = CanvasConnection.computeSides(from, to);
      expect(fromSide, equals(ConnectionSide.right));
      expect(toSide, equals(ConnectionSide.left));
    });

    test('CanvasConnection computeSides vertical down', () {
      final from = CanvasCard(id: 'from', type: CanvasCardType.text, x: 0, y: 0);
      final to = CanvasCard(id: 'to', type: CanvasCardType.text, x: 0, y: 300);

      final (fromSide, toSide) = CanvasConnection.computeSides(from, to);
      expect(fromSide, equals(ConnectionSide.bottom));
      expect(toSide, equals(ConnectionSide.top));
    });

    test('CanvasConnection computeSides horizontal left', () {
      final from = CanvasCard(id: 'from', type: CanvasCardType.text, x: 300, y: 0);
      final to = CanvasCard(id: 'to', type: CanvasCardType.text, x: 0, y: 0);

      final (fromSide, toSide) = CanvasConnection.computeSides(from, to);
      expect(fromSide, equals(ConnectionSide.left));
      expect(toSide, equals(ConnectionSide.right));
    });

    test('CanvasConnection copyWith clearStyle works (C-4)', () {
      final conn = CanvasConnection(
        id: 'conn1',
        fromCardId: 'card1',
        toCardId: 'card2',
        style: CanvasConnectionStyle(colorValue: 0xFFFF0000),
      );

      final cleared = conn.copyWith(clearStyle: true);
      expect(cleared.style, isNull);
    });

    test('CanvasData toJsonString produces valid JSON', () {
      final data = CanvasData(
        cards: [
          CanvasCard(id: 'card1', type: CanvasCardType.text, title: 'Test'),
        ],
      );

      final json = data.toJsonString();
      expect(json, isNotEmpty);
      expect(json, contains('card1'));
    });

    test('CanvasCardType label returns correct strings', () {
      expect(CanvasCardType.text.label, equals('Text'));
      expect(CanvasCardType.note.label, equals('Note'));
      expect(CanvasCardType.image.label, equals('Image'));
      expect(CanvasCardType.link.label, equals('Link'));
    });

    test('CanvasCard effectiveFontSize uses base when fontSize is 0', () {
      final card = CanvasCard(id: 'card1', type: CanvasCardType.text, fontSize: 0);
      expect(card.effectiveFontSize(16.0), equals(16.0 * 0.85));
    });

    test('CanvasCard effectiveFontSize uses custom fontSize when set', () {
      final card = CanvasCard(id: 'card1', type: CanvasCardType.text, fontSize: 20.0);
      expect(card.effectiveFontSize(16.0), equals(20.0));
    });
  });
}

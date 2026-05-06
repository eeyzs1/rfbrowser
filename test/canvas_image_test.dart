import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';

void main() {
  group('Canvas Image Card', () {
    test('AC-IMP-8-1: canvas card stores image URL in content field', () {
      final card = CanvasCard(
        id: 'model-test',
        type: CanvasCardType.image,
        x: 0, y: 0,
        width: 200, height: 150,
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
        x: 50, y: 60,
        width: 100, height: 100,
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
        x: 10, y: 20,
        width: 300, height: 200,
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
        x: 0, y: 0,
        width: 100, height: 100,
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
        x: 0, y: 0,
        width: 200, height: 200,
        title: 'Local Photo',
        content: 'C:/photos/screenshot.png',
      );

      expect(card.content, equals('C:/photos/screenshot.png'));
      expect(card.title, equals('Local Photo'));
    });
  });
}

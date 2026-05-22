import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/drag_data.dart';

void main() {
  group('DragData', () {
    test('AC-P5-2-1: serializes and deserializes correctly', () {
      final data = DragData(
        source: DragSource.browser,
        type: DragDataType.text,
        content: 'hello',
        url: 'https://example.com',
      );

      final json = data.toJson();
      final restored = DragData.fromJson(json);

      expect(restored.source, data.source);
      expect(restored.type, data.type);
      expect(restored.content, data.content);
      expect(restored.url, data.url);
    });
  });

  group('DropHandler', () {
    test('AC-P5-2-2: text drop creates blockquote with source', () {
      final handler = DropHandler();
      final data = DragData(
        source: DragSource.browser,
        type: DragDataType.text,
        content: 'hello',
        url: 'https://example.com',
      );

      final result = handler.handle(data);
      expect(result, contains('> hello'));
      expect(result, contains('@web'));
    });

    test('AC-P5-2-3: note drop creates wikilink', () {
      final handler = DropHandler();
      final data = DragData(
        source: DragSource.sidebar,
        type: DragDataType.note,
        content: '笔记A',
        title: '笔记A',
      );

      final result = handler.handle(data);
      expect(result, '[[笔记A]]');
    });

    test('AC-P5-2-4: image drop creates embed syntax', () {
      final handler = DropHandler();
      final data = DragData(
        source: DragSource.browser,
        type: DragDataType.image,
        content: 'photo.png',
      );

      final result = handler.handle(data);
      expect(result, '![[photo.png]]');
    });

    test('link drop creates markdown link', () {
      final handler = DropHandler();
      final data = DragData(
        source: DragSource.browser,
        type: DragDataType.link,
        content: 'https://example.com',
        title: 'Example',
      );

      final result = handler.handle(data);
      expect(result, '[Example](https://example.com)');
    });
  });
}

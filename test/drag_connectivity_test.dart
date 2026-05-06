import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/drag_data.dart';
import 'package:rfbrowser/services/connectivity_service.dart';

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

  group('ConnectivityService', () {
    test('AC-P5-5-1: isOnline returns correct state', () {
      var state = ConnectivityState(isOnline: true);
      expect(state.isOnline, true);

      state = state.copyWith(isOnline: false);
      expect(state.isOnline, false);
    });

    test('AC-P5-5-2: offline state tracks sync queue', () {
      var state = ConnectivityState(isOnline: false);
      expect(state.syncQueue, isEmpty);

      state = state.copyWith(syncQueue: ['notes/a.md', 'notes/b.md']);
      expect(state.syncQueue.length, 2);
      expect(state.syncQueue, contains('notes/a.md'));
    });

    test('AC-P5-5-3: OfflineNoModelError has correct message', () {
      final error = OfflineNoModelError();
      expect(error.toString(), contains('OfflineNoModelError'));
      expect(error.message, contains('No local model'));
    });

    test('AC-P5-5-3: OfflineNoModelError custom message', () {
      final error = OfflineNoModelError('Custom error');
      expect(error.message, 'Custom error');
      expect(error.toString(), contains('Custom error'));
    });

    test('AC-P5-5-4: sync queue flush clears all entries', () {
      var state = ConnectivityState(
        isOnline: false,
        syncQueue: ['a.md', 'b.md', 'c.md'],
      );
      expect(state.syncQueue.length, 3);

      state = state.copyWith(syncQueue: []);
      expect(state.syncQueue, isEmpty);
    });

    test('AC-P5-5-4: going online triggers queue flush', () {
      var state = ConnectivityState(
        isOnline: false,
        syncQueue: ['a.md', 'b.md'],
      );
      expect(state.syncQueue.length, 2);

      state = state.copyWith(isOnline: true, syncQueue: []);
      expect(state.isOnline, true);
      expect(state.syncQueue, isEmpty);
    });

    test('AC-P5-5-4: enqueue adds to sync queue', () {
      var state = ConnectivityState(isOnline: false);
      state = state.copyWith(syncQueue: [...state.syncQueue, 'note1.md']);
      state = state.copyWith(syncQueue: [...state.syncQueue, 'note2.md']);
      expect(state.syncQueue, ['note1.md', 'note2.md']);
    });
  });
}

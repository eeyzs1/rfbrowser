import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/tantivy_bridge_stub.dart'
    if (dart.library.ffi) 'package:rfbrowser/services/tantivy_bridge.dart';

void main() {
  group('TantivyBridge stub', () {
    test('isAvailable is false for stub', () {
      expect(TantivyBridge.isAvailable, false);
    });

    test('initialize returns null', () async {
      final bridge = await TantivyBridge.initialize(':memory:');
      expect(bridge, isNull);
    });
  });

  group('TantivySearchResults', () {
    test('fromJsonString parses valid JSON correctly', () {
      const json = '''
      {
        "hits": [
          {
            "note_id": "n1",
            "title": "代理模式",
            "snippet": "**代理**是一种设计模式",
            "score": 3.5,
            "file_path": "notes/代理模式.md"
          },
          {
            "note_id": "n2",
            "title": "反向代理",
            "snippet": "配置Nginx**反向代理**",
            "score": 2.1,
            "file_path": "notes/反向代理.md"
          }
        ],
        "total_count": 2
      }
      ''';

      final results = TantivySearchResults.fromJsonString(json);
      expect(results.totalCount, 2);
      expect(results.hits.length, 2);
      expect(results.hits[0].noteId, 'n1');
      expect(results.hits[0].title, '代理模式');
      expect(results.hits[0].snippet, '**代理**是一种设计模式');
      expect(results.hits[0].score, 3.5);
      expect(results.hits[0].filePath, 'notes/代理模式.md');
      expect(results.hits[1].noteId, 'n2');
    });

    test('fromJsonString handles empty string', () {
      final results = TantivySearchResults.fromJsonString('');
      expect(results.totalCount, 0);
      expect(results.hits, isEmpty);
    });

    test('fromJsonString handles malformed JSON', () {
      final results = TantivySearchResults.fromJsonString('{bad json');
      expect(results.totalCount, 0);
      expect(results.hits, isEmpty);
    });

    test('fromJsonString handles null in fields', () {
      const json = '''
      {
        "hits": [
          {
            "note_id": null,
            "title": null,
            "snippet": null,
            "score": null,
            "file_path": null
          }
        ],
        "total_count": null
      }
      ''';

      final results = TantivySearchResults.fromJsonString(json);
      expect(results.totalCount, 0);
      expect(results.hits.length, 1);
      expect(results.hits[0].noteId, '');
      expect(results.hits[0].title, '');
      expect(results.hits[0].snippet, '');
      expect(results.hits[0].score, 0.0);
      expect(results.hits[0].filePath, '');
    });

    test('fromJsonString handles empty hits array', () {
      const json = '''
      {
        "hits": [],
        "total_count": 0
      }
      ''';

      final results = TantivySearchResults.fromJsonString(json);
      expect(results.hits, isEmpty);
      expect(results.totalCount, 0);
    });
  });

  group('TantivyHit', () {
    test('all fields are accessible', () {
      final hit = TantivyHit(
        noteId: 'n1',
        title: 'Test',
        snippet: '**Test** snippet',
        score: 2.5,
        filePath: 'test.md',
      );

      expect(hit.noteId, 'n1');
      expect(hit.title, 'Test');
      expect(hit.snippet, '**Test** snippet');
      expect(hit.score, 2.5);
      expect(hit.filePath, 'test.md');
    });
  });

  group('TantivySearchResults scoring order', () {
    test('fromJsonString preserves hit order', () {
      const json = '''
      {
        "hits": [
          {"note_id": "n3", "title": "", "snippet": "", "score": 1.0, "file_path": ""},
          {"note_id": "n1", "title": "", "snippet": "", "score": 5.0, "file_path": ""},
          {"note_id": "n2", "title": "", "snippet": "", "score": 3.0, "file_path": ""}
        ],
        "total_count": 3
      }
      ''';

      final results = TantivySearchResults.fromJsonString(json);
      expect(results.totalCount, 3);
      expect(results.hits[0].noteId, 'n3');
      expect(results.hits[0].score, 1.0);
      expect(results.hits[1].noteId, 'n1');
      expect(results.hits[1].score, 5.0);
      expect(results.hits[2].noteId, 'n2');
      expect(results.hits[2].score, 3.0);
    });
  });
}

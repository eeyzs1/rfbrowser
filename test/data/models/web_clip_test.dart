import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/web_clip.dart';

void main() {
  final testCaptured = DateTime.parse('2025-01-15T10:30:00.000');

  WebClip createTestClip({DateTime? captured}) {
    return WebClip(
      id: 'clip-1',
      url: 'https://example.com/article',
      title: 'Test Article',
      content: '<p>Hello world</p>',
      rawHtmlPath: '/raw/page.html',
      screenshotPath: '/img/screenshot.png',
      selectedText: ['first selection', 'second selection'],
      captured: captured ?? testCaptured,
      noteId: 'note-1',
    );
  }

  group('WebClip.toJson', () {
    test('includes all fields', () {
      final clip = createTestClip();
      final json = clip.toJson();

      expect(json, containsPair('id', 'clip-1'));
      expect(json, containsPair('url', 'https://example.com/article'));
      expect(json, containsPair('title', 'Test Article'));
      expect(json, containsPair('content', '<p>Hello world</p>'));
      expect(json, containsPair('rawHtmlPath', '/raw/page.html'));
      expect(json, containsPair('screenshotPath', '/img/screenshot.png'));
      expect(json, containsPair('selectedText', ['first selection', 'second selection']));
      expect(json, containsPair('captured', testCaptured.toIso8601String()));
      expect(json, containsPair('noteId', 'note-1'));
    });
  });

  group('WebClip.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'clip-1',
        'url': 'https://example.com/article',
        'title': 'Test Article',
        'content': '<p>Hello world</p>',
        'rawHtmlPath': '/raw/page.html',
        'screenshotPath': '/img/screenshot.png',
        'selectedText': ['first selection', 'second selection'],
        'captured': testCaptured.toIso8601String(),
        'noteId': 'note-1',
      };

      final clip = WebClip.fromJson(json);

      expect(clip.id, 'clip-1');
      expect(clip.url, 'https://example.com/article');
      expect(clip.title, 'Test Article');
      expect(clip.content, '<p>Hello world</p>');
      expect(clip.rawHtmlPath, '/raw/page.html');
      expect(clip.screenshotPath, '/img/screenshot.png');
      expect(clip.selectedText, ['first selection', 'second selection']);
      expect(clip.captured, testCaptured);
      expect(clip.noteId, 'note-1');
    });

    test('handles null fields with defaults', () {
      final json = <String, dynamic>{};

      final clip = WebClip.fromJson(json);

      expect(clip.id, '');
      expect(clip.url, '');
      expect(clip.title, '');
      expect(clip.content, '');
      expect(clip.rawHtmlPath, isNull);
      expect(clip.screenshotPath, isNull);
      expect(clip.selectedText, isEmpty);
      expect(clip.captured, isNotNull);
      expect(clip.noteId, '');
    });

    test('handles missing selectedText with empty list', () {
      final json = {
        'id': 'clip-1',
        'url': 'https://example.com',
        'title': 'T',
        'content': 'C',
        'noteId': 'n1',
      };

      final clip = WebClip.fromJson(json);

      expect(clip.selectedText, isEmpty);
    });

    test('handles missing captured with DateTime.now()', () {
      final before = DateTime.now();
      final json = {
        'id': 'clip-1',
        'url': 'https://example.com',
        'title': 'T',
        'content': 'C',
        'noteId': 'n1',
      };

      final clip = WebClip.fromJson(json);
      final after = DateTime.now();

      expect(clip.captured.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(clip.captured.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('WebClip round-trip', () {
    test('toJson/fromJson preserves data', () {
      final original = createTestClip();
      final restored = WebClip.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.url, original.url);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
      expect(restored.rawHtmlPath, original.rawHtmlPath);
      expect(restored.screenshotPath, original.screenshotPath);
      expect(restored.selectedText, original.selectedText);
      expect(restored.captured, original.captured);
      expect(restored.noteId, original.noteId);
    });

    test('toJsonString/fromJsonString round-trip', () {
      final original = createTestClip();
      final jsonString = original.toJsonString();
      final restored = WebClip.fromJsonString(jsonString);

      expect(restored.id, original.id);
      expect(restored.url, original.url);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
      expect(restored.rawHtmlPath, original.rawHtmlPath);
      expect(restored.screenshotPath, original.screenshotPath);
      expect(restored.selectedText, original.selectedText);
      expect(restored.captured, original.captured);
      expect(restored.noteId, original.noteId);
    });
  });
}

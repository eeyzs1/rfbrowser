import 'package:flutter_test/flutter_test.dart';

bool shouldBlockUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return true;
  const allowed = {'http', 'https', 'about'};
  return !allowed.contains(uri.scheme);
}

void main() {
  group('BrowserWebViewStack URL filtering (S-1)', () {
    test('blocks javascript: scheme including case variations', () {
      expect(shouldBlockUrl('javascript:alert(1)'), isTrue);
      expect(shouldBlockUrl('JAVASCRIPT:void(0)'), isTrue);
    });

    test('blocks file: scheme', () {
      expect(shouldBlockUrl('file:///etc/passwd'), isTrue);
      expect(shouldBlockUrl('file:///C:/Windows/System32'), isTrue);
    });

    test('blocks data: scheme', () {
      expect(
        shouldBlockUrl('data:text/html,<script>alert(1)</script>'),
        isTrue,
      );
      expect(shouldBlockUrl('data:image/png;base64,abc'), isTrue);
    });

    test('blocks ftp: scheme', () {
      expect(shouldBlockUrl('ftp://malicious.com/file'), isTrue);
    });

    test('allows http: and https: schemes', () {
      expect(shouldBlockUrl('http://example.com'), isFalse);
      expect(shouldBlockUrl('https://secure.example.com/path'), isFalse);
    });

    test('allows about:blank', () {
      expect(shouldBlockUrl('about:blank'), isFalse);
    });

    test('blocks chrome: and other browser-internal schemes', () {
      expect(shouldBlockUrl('chrome://settings'), isTrue);
      expect(shouldBlockUrl('chrome-extension://abc'), isTrue);
    });

    test('blocks empty and malformed URLs', () {
      expect(shouldBlockUrl(''), isTrue);
      expect(shouldBlockUrl('not-a-url'), isTrue);
    });

    test('blocks blob: and filesystem: schemes', () {
      expect(shouldBlockUrl('blob:https://example.com/uuid'), isTrue);
      expect(
        shouldBlockUrl('filesystem:https://example.com/temporary/'),
        isTrue,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/platform/webview/agent_webview.dart';
import 'package:rfbrowser/platform/webview/headless_manager.dart';

void main() {
  group('G12: WebView Security Audit (S-1)', () {
    group('AgentWebView URL filtering', () {
      late AgentWebView agentWebView;

      setUp(() {
        final headless = HeadlessWebView(id: 'test-hwv');
        agentWebView = AgentWebView(headless);
      });

      test('blocks javascript: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('javascript:alert(1)'), isTrue);
        expect(agentWebView.shouldOverrideUrlLoading('javascript:void(0)'), isTrue);
        expect(agentWebView.shouldOverrideUrlLoading('JAVASCRIPT:alert(1)'), isTrue);
      });

      test('blocks file: scheme', () {
        expect(agentWebView.shouldOverrideUrlLoading('file:///etc/passwd'), isTrue);
        expect(agentWebView.shouldOverrideUrlLoading('file:///C:/Windows/System32/config/SAM'), isTrue);
      });

      test('blocks data: scheme', () {
        expect(
          agentWebView.shouldOverrideUrlLoading('data:text/html,<script>alert(1)</script>'),
          isTrue,
        );
        expect(agentWebView.shouldOverrideUrlLoading('data:image/svg+xml;base64,PHN2Zy8+'), isTrue);
      });

      test('blocks ftp: and other non-HTTP schemes', () {
        expect(agentWebView.shouldOverrideUrlLoading('ftp://malicious.com/malware.exe'), isTrue);
        expect(agentWebView.shouldOverrideUrlLoading('vbscript:msgbox("hi")'), isTrue);
        expect(agentWebView.shouldOverrideUrlLoading('chrome://settings'), isTrue);
      });

      test('allows http: and https: schemes', () {
        expect(agentWebView.shouldOverrideUrlLoading('http://example.com'), isFalse);
        expect(agentWebView.shouldOverrideUrlLoading('https://secure.example.com/path'), isFalse);
        expect(agentWebView.shouldOverrideUrlLoading('about:blank'), isFalse);
      });

      test('blocks malformed URLs', () {
        expect(agentWebView.shouldOverrideUrlLoading('not-a-valid-url'), isTrue);
        expect(agentWebView.shouldOverrideUrlLoading(''), isTrue);
      });

      test('navigateTo blocks dangerous URLs', () async {
        await agentWebView.navigateTo('javascript:alert(1)');
        expect(agentWebView.currentUrl, isNull,
            reason: 'Should not navigate to blocked URL');
      });
    });

    group('HeadlessWebView URL filtering', () {
      test('loadUrl blocks javascript: scheme', () async {
        final webView = HeadlessWebView(id: 'test-1');
        await webView.run();

        expect(
          () => webView.loadUrl('javascript:alert(1)'),
          throwsArgumentError,
        );
      });

      test('loadUrl blocks file: scheme', () async {
        final webView = HeadlessWebView(id: 'test-2');
        await webView.run();

        expect(
          () => webView.loadUrl('file:///etc/passwd'),
          throwsArgumentError,
        );
      });

      test('loadUrl allows https: scheme', () async {
        final webView = HeadlessWebView(id: 'test-3');
        await webView.run();

        await webView.loadUrl('https://example.com');
        expect(webView.currentUrl, 'https://example.com');
      });

      test('loadUrl allows http: scheme', () async {
        final webView = HeadlessWebView(id: 'test-4');
        await webView.run();

        await webView.loadUrl('http://localhost:8080');
        expect(webView.currentUrl, 'http://localhost:8080');
      });
    });

    group('HeadlessManager lifecycle', () {
      test('creates and disposes web views correctly', () {
        final manager = HeadlessManager();
        final webView = manager.create();
        expect(webView.id, startsWith('hwv-'));
        expect(manager.activeCount, 1);

        manager.dispose(webView.id);
        expect(manager.activeCount, 0);
      });

      test('disposeAll cleans up all instances', () {
        final manager = HeadlessManager();
        manager.create();
        manager.create();
        expect(manager.activeCount, 2);

        manager.disposeAll();
        expect(manager.activeCount, 0);
      });
    });
  });
}

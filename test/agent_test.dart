import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/platform/webview/headless_manager.dart';
import 'package:rfbrowser/platform/webview/agent_webview.dart';

void main() {
  group('HeadlessManager', () {
    test(
      'AC-P3-1-1: create returns non-null WebView and activeCount increments',
      () {
        final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
        final webView = manager.create();
        expect(webView, isNotNull);
        expect(webView.id, isNotEmpty);
        expect(manager.activeCount, 1);
        manager.disposeAll();
      },
    );

    test('AC-P3-1-8: dispose decrements activeCount', () async {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      final webView = manager.create();
      await webView.run();
      expect(manager.activeCount, 1);
      manager.dispose(webView.id);
      expect(manager.activeCount, 0);
    });

    test('AC-P3-1-9: idle timeout auto-disposes WebView', () async {
      final manager = HeadlessManager(idleTimeout: Duration(milliseconds: 100));
      final webView = manager.create();
      await webView.run();
      expect(manager.activeCount, 1);
      await Future.delayed(Duration(milliseconds: 200));
      expect(manager.activeCount, 0);
    });

    test('disposeAll removes all instances', () async {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      manager.create();
      manager.create();
      manager.create();
      expect(manager.activeCount, 3);
      manager.disposeAll();
      expect(manager.activeCount, 0);
    });
  });

  group('AgentWebView', () {
    test('AC-P3-1-2: navigateTo sets currentUrl', () async {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      final webView = manager.create();
      final agentWebView = AgentWebView(webView);
      await agentWebView.navigateTo('https://example.com');
      expect(agentWebView.currentUrl, contains('example.com'));
      manager.disposeAll();
    });

    test('AC-P3-1-3: extractText returns non-empty string', () async {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      final webView = manager.create();
      final agentWebView = AgentWebView(webView);
      await agentWebView.navigateTo('https://example.com');
      final text = await agentWebView.extractText();
      expect(text, isNotEmpty);
      manager.disposeAll();
    });
  });
}

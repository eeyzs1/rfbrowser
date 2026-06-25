import '../../core/logging/app_logger.dart';
import '../../platform/webview/headless_manager.dart';

class AgentWebView {
  final HeadlessWebView _webView;

  static const _allowedSchemes = {'http', 'https', 'about'};

  AgentWebView(this._webView);

  String get id => _webView.id;
  String? get currentUrl => _webView.currentUrl;
  bool get isRunning => _webView.isRunning;

  bool shouldOverrideUrlLoading(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return true;
    if (!_allowedSchemes.contains(uri.scheme)) {
      appLog.warning('AgentWebView: blocked non-HTTP URL scheme: ${uri.scheme}');
      return true;
    }
    return false;
  }

  Future<void> navigateTo(String url) async {
    if (shouldOverrideUrlLoading(url)) return;
    if (!_webView.isRunning) await _webView.run();
    await _webView.loadUrl(url);
  }

  Future<String> extractText() async {
    return _webView.extractText();
  }

  Future<String> evaluateJavascript(String script) async {
    return _webView.evaluateJavascript(script);
  }

  Future<void> dispose() async {
    await _webView.dispose();
  }
}

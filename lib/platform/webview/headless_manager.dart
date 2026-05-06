import 'dart:async';

int _counter = 0;

const _allowedSchemes = {'http', 'https'};

class HeadlessWebView {
  final String id;
  bool _isRunning = false;
  String? _currentUrl;
  String? _pageTitle;
  String? _pageContent;

  HeadlessWebView({required this.id});

  bool get isRunning => _isRunning;
  String? get currentUrl => _currentUrl;
  String? get pageTitle => _pageTitle;
  String? get pageContent => _pageContent;

  Future<void> run() async {
    _isRunning = true;
  }

  Future<void> loadUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !_allowedSchemes.contains(uri.scheme)) {
      throw ArgumentError('Blocked URL scheme: ${uri?.scheme ?? 'invalid'}');
    }
    _currentUrl = url;
    _pageTitle = uri.host;
    _pageContent = 'Page content for $url';
  }

  Future<String> extractText() async {
    if (!_isRunning) throw StateError('WebView is not running');
    return _pageContent ?? '';
  }

  Future<String> evaluateJavascript(String script) async {
    if (!_isRunning) throw StateError('WebView is not running');
    return '';
  }

  Future<void> dispose() async {
    _isRunning = false;
    _currentUrl = null;
    _pageTitle = null;
    _pageContent = null;
  }
}

class HeadlessManager {
  final Map<String, HeadlessWebView> _instances = {};
  final Duration idleTimeout;
  final Map<String, Timer> _idleTimers = {};

  HeadlessManager({this.idleTimeout = const Duration(minutes: 5)});

  int get activeCount => _instances.length;

  HeadlessWebView create() {
    final id = 'hwv-${_counter++}';
    final webView = HeadlessWebView(id: id);
    _instances[id] = webView;
    _resetIdleTimer(id);
    return webView;
  }

  HeadlessWebView? get(String id) => _instances[id];

  void dispose(String id) {
    _idleTimers[id]?.cancel();
    _idleTimers.remove(id);
    _instances[id]?.dispose();
    _instances.remove(id);
  }

  void disposeAll() {
    for (final id in _instances.keys.toList()) {
      dispose(id);
    }
  }

  void _resetIdleTimer(String id) {
    _idleTimers[id]?.cancel();
    _idleTimers[id] = Timer(idleTimeout, () => dispose(id));
  }
}

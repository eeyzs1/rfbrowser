import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'services/database_init.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable the engine-level semantics tree to prevent accessibility_bridge
  // errors caused by WebView2 native windows on Windows.
  // See: Flutter engine issue #98099, flutter_inappwebview compatibility
  PlatformDispatcher.instance.setSemanticsTreeEnabled(false);

  if (Platform.isLinux || Platform.isWindows) {
    initDatabaseFactory();
  }

  // Skip the native window setup when running inside flutter integration
  // tests. windowManager.ensureInitialized() needs a real interactive
  // desktop (a logged-in user on a window-station); the GitHub Actions
  // runner provides neither, so the call would block forever on
  // CreateWindowEx and the integration test framework would time out
  // with "Unable to start the app on the device" because runApp() is
  // never reached. The integration tests in integration_test/ only
  // exercise Dart-level plugin / service logic; they do not need a
  // real window. FLUTTER_TEST is set by .github/workflows/ci.yml in
  // the integration-test-windows job.
  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    runApp(const ProviderScope(child: RFBrowserApp()));
    return;
  }

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'RFBrowser',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: RFBrowserApp()));
}

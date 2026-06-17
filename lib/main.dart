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

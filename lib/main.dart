import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/logging/app_logger.dart';
import 'services/database_init.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    appLog.error('FlutterError: ${details.exceptionAsString()}',
        error: details.exception, stackTrace: details.stack);
    debugPrint('=== FlutterError ===');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack?.toString() ?? '(no stack)');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    appLog.error('Zone error: $error', error: error, stackTrace: stack);
    debugPrint('=== Uncaught error ===');
    debugPrint('$error');
    debugPrint('$stack');
    return true;
  };

  // Database init — must not block runApp() if it fails.
  try {
    if (Platform.isLinux || Platform.isWindows) {
      initDatabaseFactory();
    }
  } catch (e, st) {
    appLog.error('Database init failed', error: e, stackTrace: st);
  }

  // Window manager init — must not block runApp() if it fails.
  try {
    await windowManager.ensureInitialized();
  } catch (e, st) {
    appLog.error('Window manager init failed', error: e, stackTrace: st);
  }

  // IMPORTANT: Do NOT `await` waitUntilReadyToShow.
  //
  // Why: The native window is created hidden (WS_OVERLAPPEDWINDOW without
  // WS_VISIBLE) and only shown when the first Flutter frame renders, via
  // SetNextFrameCallback in flutter_window.cpp. If we `await` this call,
  // runApp() is never reached, no frame renders, the callback never fires,
  // and the window stays invisible forever — which is exactly the "GUI shows
  // nothing" symptom.
  //
  // waitUntilReadyToShow makes 10+ sequential method-channel round-trips
  // (setTitleBarStyle, isFullScreen, isMaximized, isMinimized, setSize,
  // setAlignment, setMinimumSize, setBackgroundColor, setSkipTaskbar,
  // setTitle) and then runs the callback. Any of these can hang. The
  // window_manager example app calls this WITHOUT await, and so do we.
  const windowOptions = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Color(0xFF0F172A),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'RFBrowser',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  }).catchError((Object e, StackTrace st) {
    appLog.error('Window show/focus failed', error: e, stackTrace: st);
  });

  // runApp() must be called unconditionally so the first frame renders and
  // the native window becomes visible.
  runApp(const ProviderScope(child: RFBrowserApp()));
}

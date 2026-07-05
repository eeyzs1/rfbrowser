import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/logging/app_logger.dart';
import 'core/rf_browser_binding.dart';
import 'services/database_init.dart';
import 'app.dart';

void main() async {
  // 自定义 binding：override `SemanticsBinding.semanticsEnabled` 返回 false，
  // 阻止 framework 创建 `_semanticsOwner` → 不发送 semantics 更新给 engine。
  // 详见 lib/core/rf_browser_binding.dart 中的根因分析。
  RFBrowserBinding();

  // engine 层兜底禁用（binding 的 `_handleFrameworkSemanticsEnabledChanged`
  // 监听器在 init 期间添加得比 ensureSemantics 调用晚，初始的
  // `_semanticsEnabled.value = true` 不会触发它，所以需要显式调用）。
  PlatformDispatcher.instance.setSemanticsTreeEnabled(false);

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

  // IMPORTANT: Do NOT `await` waitUntilReadyToShow before runApp().
  //
  // Why: The native window is created hidden (WS_OVERLAPPEDWINDOW without
  // WS_VISIBLE) and only shown when the first Flutter frame renders, via
  // SetNextFrameCallback in flutter_window.cpp. If we `await` this call,
  // runApp() is never reached, no frame renders, the callback never fires,
  // and the window stays invisible forever — "GUI shows nothing".
  //
  // waitUntilReadyToShow makes 10+ sequential method-channel round-trips
  // (setTitleBarStyle, isFullScreen, isMaximized, isMinimized, setSize,
  // setAlignment, setMinimumSize, setBackgroundColor, setSkipTaskbar,
  // setTitle) and then runs the callback. Any of these can hang.
  //
  // ─── Race condition with Flutter semantics ───────────────────────────
  // These method channel calls (especially `show()`/`setSize()`/`setAlignment`)
  // trigger Windows accessibility queries on the native side. Windows assigns
  // its own accessibility node IDs (e.g., 63, 57) BEFORE Flutter's
  // AccessibilityBridge has committed its first semantics tree. When Flutter's
  // semantics finally commit (MainLayout frame #1), the native AXTree is in
  // a partial state — orphaned native nodes cause
  // `accessibility_bridge.cc(114) Failed to update ui::AXTree, error: 63`
  // and a cascade of subsequent failures (error 57 × 40+).
  //
  // ─── Fix: Completer handoff ───────────────────────────────────────────
  // We do NOT await waitUntilReadyToShow here (runApp must run immediately).
  // Instead, we complete a `Completer<void>` when waitUntilReadyToShow
  // finishes (in the callback, the .then, or .catchError — whichever fires
  // first). RFBrowserApp._initApp awaits this Completer (with a 5s timeout)
  // BEFORE setting _initialized = true. This keeps the LoadingScreen (minimal
  // semantics — Scaffold + Icon + ExcludeSemantics(CircularProgressIndicator))
  // visible until windowManager is done. MainLayout renders only after the
  // native accessibility tree is stable, eliminating the orphan race.
  const windowOptions = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Color(0xFF0F172A),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'RFBrowser',
  );

  final windowReady = Completer<void>();

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    if (!windowReady.isCompleted) {
      windowReady.complete();
    }
  }).then((_) {
    if (!windowReady.isCompleted) {
      windowReady.complete();
    }
  }).catchError((Object e, StackTrace st) {
    appLog.error('Window show/focus failed', error: e, stackTrace: st);
    if (!windowReady.isCompleted) {
      windowReady.complete(); // complete anyway so _initApp doesn't hang
    }
  });

  // runApp() must be called unconditionally so the first frame renders and
  // the native window becomes visible. RFBrowserApp receives `windowReady`
  // future and awaits it in _initApp before rendering MainLayout.
  runApp(ProviderScope(child: RFBrowserApp(windowReady: windowReady.future)));
}

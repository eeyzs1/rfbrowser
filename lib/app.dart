import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/logging/app_logger.dart';
import 'core/ai/builtin_model_registry.dart';
import 'l10n/app_localizations.dart';
import 'services/settings_service.dart';
import 'services/shortcut_service.dart';
import 'services/knowledge_service.dart';
import 'services/browser_service.dart';
import 'services/embedding_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/layout/main_layout.dart';
import 'ui/pages/welcome_page.dart';
import 'data/stores/vault_store.dart';
import 'plugins/plugin_registry.dart';
import 'plugins/host/plugin_host.dart';

class RFBrowserApp extends ConsumerStatefulWidget {
  const RFBrowserApp({super.key, this.windowReady});

  /// Future that completes when windowManager.waitUntilReadyToShow finishes
  /// all its method channel round-trips. _initApp awaits this (with a 5s
  /// timeout) before setting _initialized = true, so MainLayout doesn't
  /// render until the native accessibility tree is stable. See main.dart for
  /// the full rationale (orphan node race condition).
  final Future<void>? windowReady;

  static Locale? _resolveLocale(String localeSetting) {
    if (localeSetting == 'system') return null;
    return Locale(localeSetting);
  }

  @override
  ConsumerState<RFBrowserApp> createState() => _RFBrowserAppState();
}

class _RFBrowserAppState extends ConsumerState<RFBrowserApp> {
  bool _initialized = false;
  bool _enteredMainLayout = false;
  Brightness? _platformBrightness;

  @override
  void initState() {
    super.initState();
    // 监听系统亮度变化，当 themeMode 为 system 时触发重建
    PlatformDispatcher.instance.onPlatformBrightnessChanged = () {
      if (mounted) {
        setState(() {
          _platformBrightness = PlatformDispatcher.instance.platformBrightness;
        });
      }
    };
    _initApp();
  }

  @override
  void dispose() {
    PlatformDispatcher.instance.onPlatformBrightnessChanged = null;
    super.dispose();
  }

  Future<void> _initApp() async {
    // Wrap the entire init flow in try/finally so the app always escapes the
    // loading spinner, even if a service throws. Without this, an unhandled
    // exception in any awaited call below would leave _initialized = false
    // forever, stranding the user on a blank loading screen.
    try {
      // ─── Await windowManager completion FIRST ──────────────────────────
      // waitUntilReadyToShow (in main.dart) is NOT awaited before runApp() —
      // the native window would never show if we did. Instead it completes a
      // `Completer<void>` (windowReady) when its 10+ method channel round-trips
      // finish. Awaiting that Completer here keeps the LoadingScreen (minimal
      // semantics — Scaffold + Icon + ExcludeSemantics(CircularProgressIndicator))
      // visible until windowManager is done.
      //
      // Why this matters: windowManager.show()/setSize()/setAlignment() trigger
      // Windows accessibility queries that assign native node IDs (e.g., 63, 57)
      // BEFORE Flutter's AccessibilityBridge commits its first semantics tree.
      // If MainLayout renders while these calls are in flight, the native
      // AXTree is in a partial state → orphaned native nodes →
      // `accessibility_bridge.cc(114) Failed to update ui::AXTree, error: 63`
      // → cascade of error 57 × 40+ → process crash.
      //
      // The 5-second timeout is a safety net: if windowManager hangs (rare),
      // we proceed anyway rather than stranding the user on LoadingScreen.
      if (widget.windowReady != null) {
        try {
          await widget.windowReady!.timeout(const Duration(seconds: 5));
        } catch (e) {
          appLog.error(
            'windowReady await failed or timed out (proceeding anyway)',
            error: e,
          );
        }
      }

      // Kick off ONNX embedding backend initialization in the background.
      // This downloads the MiniLM model (~23MB) on first run and loads it into
      // memory. Until it is ready, the EmbeddingService falls back to
      // Ollama/TF-IDF. Failures are logged and silently ignored so the app
      // always starts.
      ref.read(embeddingServiceProvider).initOnnx().catchError((e) {
        // Swallow: fallback paths handle embedding without ONNX.
        return;
      });

      await ref.read(settingsProvider.notifier).loadSettings();
      // Load model metadata from JSON before AI config loads, so
      // ModelDiscovery can use the registry during model list fetching.
      await BuiltinModelRegistry.loadFromAssets();
      await ref.read(aiConfigProvider.notifier).loadConfig();
      await ref.read(shortcutServiceProvider).load();
      await ref.read(vaultProvider.notifier).loadRecentVaults();

      final pluginHost = ref.read(pluginHostProvider.notifier);
      await pluginHost.loadConfig();
      await PluginRegistry.loadAllBuiltinPlugins(pluginHost);

      final vaultState = ref.read(vaultProvider);
      if (vaultState.currentVault != null) {
        await PluginRegistry.loadExternalPlugins(
          pluginHost,
          vaultState.currentVault!.path,
        );
      }
      final settings = ref.read(settingsProvider);
      if (vaultState.currentVault != null) {
        if (!settings.alwaysShowWelcomePage) {
          _enteredMainLayout = true;
        }
        // 必须在 _initialized = true 之前 await 完成：loadAllNotes() 和
        // loadBookmarks() 会触发 knowledgeProvider / browserProvider 通知，
        // 进而触发 MainLayout（含 SceneScaffold + CaptureScene + NoteSidebar
        // + BrowserView 的大语义树）rebuild。若这些通知在 MainLayout 渲染
        // 后才完成，会叠加在已经脆弱的启动 AXTree 上，触发
        // "Failed to update ui::AXTree, error: N" → 进程崩溃。
        // await 确保所有 provider 通知在 LoadingScreen（最小 AXTree）期间
        // 完成，MainLayout 渲染时数据已就绪，无 post-init 重建。
        await ref.read(knowledgeProvider.notifier).loadAllNotes();
        await ref.read(browserProvider.notifier).loadBookmarks();
      }
    } catch (e, st) {
      appLog.error('App initialization failed', error: e, stackTrace: st);
      debugPrint('=== _initApp error ===');
      debugPrint('$e');
      debugPrint('$st');
    } finally {
      if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // 当 themeMode 为 system 时，通过 _platformBrightness 触发重建
    // （在 initState 中注册了 onPlatformBrightnessChanged 回调）
    if (settings.themeMode == ThemeMode.system) {
      _platformBrightness; // 引用以建立依赖
    }

    final noVault = ref.watch(vaultProvider).currentVault == null;
    final showWelcome =
        noVault || (settings.alwaysShowWelcomePage && !_enteredMainLayout);

    // 统一使用同一个 MaterialApp 骨架，仅切换 home 内容。
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RFBrowser',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: settings.highContrastMode
          ? AppTheme.highContrastTheme(settings)
          : settings.isDarkMode
          ? AppTheme.darkTheme(settings)
          : AppTheme.lightTheme(settings),
      locale: RFBrowserApp._resolveLocale(settings.locale),
      home: !_initialized
          ? _buildLoadingScreen()
          : showWelcome
          ? WelcomePage(
              onVaultOpened: () {
                setState(() => _enteredMainLayout = true);
                ref.read(knowledgeProvider.notifier).loadAllNotes();
              },
            )
          : const MainLayout(),
    );
  }

  /// 启动加载屏。
  /// CircularProgressIndicator 必须用 ExcludeSemantics 包裹：它内部使用
  /// AnimationController.repeat() 每帧更新语义节点的 value 属性，在 _initApp
  /// 期间（ONNX 模型下载 ~23MB + 多次磁盘 I/O，可能持续数秒）会持续向 AXTree
  /// 提交更新。叠加 windowManager 并发的 native 窗口操作，会触发 Windows
  /// accessibility_bridge AXTree diff 失败导致进程崩溃。
  /// ExcludeSemantics 后该指示器不再向语义树贡献节点，从根源消除崩溃。
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore, size: 64, color: Colors.blue.shade400),
            const SizedBox(height: 16),
            const ExcludeSemantics(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

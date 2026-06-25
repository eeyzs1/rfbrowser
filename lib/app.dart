import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/logging/app_logger.dart';
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
  const RFBrowserApp({super.key});

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
          _platformBrightness =
              PlatformDispatcher.instance.platformBrightness;
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
        ref.read(knowledgeProvider.notifier).loadAllNotes();
        ref.read(browserProvider.notifier).loadBookmarks();
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

    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore, size: 64, color: Colors.blue.shade400),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }

    final noVault = ref.watch(vaultProvider).currentVault == null;
    final showWelcome =
        noVault || (settings.alwaysShowWelcomePage && !_enteredMainLayout);

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
      home: showWelcome
          ? WelcomePage(
              onVaultOpened: () {
                setState(() => _enteredMainLayout = true);
                ref.read(knowledgeProvider.notifier).loadAllNotes();
              },
            )
          : const MainLayout(),
    );
  }
}

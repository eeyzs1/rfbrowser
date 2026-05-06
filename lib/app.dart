import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'services/settings_service.dart';
import 'services/shortcut_service.dart';
import 'services/knowledge_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/layout/main_layout.dart';
import 'ui/pages/welcome_page.dart';
import 'data/stores/vault_store.dart';

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

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await ref.read(settingsProvider.notifier).loadSettings();
    await ref.read(aiConfigProvider.notifier).loadConfig();
    await ref.read(shortcutServiceProvider).load();
    await ref.read(vaultProvider.notifier).loadRecentVaults();
    final vaultState = ref.read(vaultProvider);
    final settings = ref.read(settingsProvider);
    if (vaultState.currentVault != null) {
      if (!settings.alwaysShowWelcomePage) {
        _enteredMainLayout = true;
      }
      ref.read(knowledgeProvider.notifier).loadAllNotes();
    }
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

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
          : AppTheme.lightTheme(settings),
      darkTheme: settings.highContrastMode
          ? AppTheme.highContrastTheme(settings)
          : AppTheme.darkTheme(settings),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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

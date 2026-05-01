import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/settings_service.dart';
import 'services/knowledge_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/layout/main_layout.dart';
import 'data/stores/vault_store.dart';

class RFBrowserApp extends ConsumerStatefulWidget {
  const RFBrowserApp({super.key});

  @override
  ConsumerState<RFBrowserApp> createState() => _RFBrowserAppState();
}

class _RFBrowserAppState extends ConsumerState<RFBrowserApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await ref.read(settingsProvider.notifier).loadSettings();
    await ref.read(vaultProvider.notifier).loadRecentVaults();
    if (ref.read(vaultProvider).currentVault != null) {
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RFBrowser',
      theme: AppTheme.lightTheme(settings),
      darkTheme: AppTheme.darkTheme(settings),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(settings.locale),
      supportedLocales: const [Locale('en'), Locale('zh')],
      home: const MainLayout(),
    );
  }
}

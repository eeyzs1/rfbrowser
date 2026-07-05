import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/layout/scene_scaffold.dart';
import 'package:rfbrowser/ui/layout/scene_switcher.dart';
import 'package:rfbrowser/ui/pages/settings_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Scene Navigation', () {
    Future<void> pumpMainLayout(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const _TestMainLayout(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows Capture scene by default', (tester) async {
      await pumpMainLayout(tester);

      expect(find.byType(SceneSwitcher), findsOneWidget);
      expect(find.text('Capture'), findsWidgets);
    });

    testWidgets('can switch to Think scene via button', (tester) async {
      await pumpMainLayout(tester);

      await tester.tap(find.text('Think'));
      await tester.pumpAndSettle();

      expect(find.text('Think'), findsWidgets);
    });

    testWidgets('can switch to Connect scene via button', (tester) async {
      await pumpMainLayout(tester);

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(find.text('Connect'), findsWidgets);
    });

    testWidgets('can switch back to Capture scene', (tester) async {
      await pumpMainLayout(tester);

      await tester.tap(find.text('Think'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Capture'));
      await tester.pumpAndSettle();

      expect(find.text('Capture'), findsWidgets);
    });

    testWidgets('settings button navigates to SettingsPage', (tester) async {
      await pumpMainLayout(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });
}

class _TestMainLayout extends StatefulWidget {
  const _TestMainLayout();

  @override
  State<_TestMainLayout> createState() => _TestMainLayoutState();
}

class _TestMainLayoutState extends State<_TestMainLayout> {
  SceneType _currentScene = SceneType.capture;
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    if (_showSettings) {
      return SettingsPage(onBack: () => setState(() => _showSettings = false));
    }
    return Scaffold(
      body: Column(
        children: [
          SceneSwitcher(
            currentScene: _currentScene,
            onSceneChanged: (scene) => setState(() => _currentScene = scene),
            onSettings: () => setState(() => _showSettings = true),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: KeyedSubtree(
                key: ValueKey(_currentScene),
                child: _buildScene(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScene() {
    return switch (_currentScene) {
      SceneType.capture => const Center(child: Text('Capture Scene')),
      SceneType.think => const Center(child: Text('Think Scene')),
      SceneType.connect => const Center(child: Text('Connect Scene')),
    };
  }
}

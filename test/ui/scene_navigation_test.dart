import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/layout/scene_scaffold.dart';

class _TestVaultNotifier extends VaultNotifier {
  @override
  VaultState build() => VaultState();
}

void main() {
  group('SceneType', () {
    test('has three values', () {
      expect(SceneType.values.length, 3);
      expect(SceneType.capture, isA<SceneType>());
      expect(SceneType.think, isA<SceneType>());
      expect(SceneType.connect, isA<SceneType>());
    });
  });

  group('SceneScaffold', () {
    testWidgets('renders scene content and switcher', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [vaultProvider.overrideWith(() => _TestVaultNotifier())],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SceneScaffold(
                initialScene: SceneType.capture,
                captureView: (_) => const Text('Capture View'),
                thinkView: (_) => const Text('Think View'),
                connectView: (_) => const Text('Connect View'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Capture View'), findsOneWidget);
      expect(find.text('Think View'), findsNothing);
      expect(find.text('Connect View'), findsNothing);
    });

    testWidgets('scene icons are rendered', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [vaultProvider.overrideWith(() => _TestVaultNotifier())],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SceneScaffold(
                initialScene: SceneType.capture,
                captureView: (_) => const SizedBox(),
                thinkView: (_) => const SizedBox(),
                connectView: (_) => const SizedBox(),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.explore), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
      expect(find.byIcon(Icons.hub), findsOneWidget);
    });
  });
}

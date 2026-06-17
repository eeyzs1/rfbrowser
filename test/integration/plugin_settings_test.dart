import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';
import 'package:rfbrowser/plugins/builtin/hello_world/hello_world_plugin.dart';
import 'package:rfbrowser/ui/pages/settings/plugin_settings_section.dart';

class _TestVaultNotifier extends VaultNotifier {
  final VaultConfig? _currentVault;

  _TestVaultNotifier({VaultConfig? currentVault})
    : _currentVault = currentVault;

  @override
  VaultState build() => VaultState(currentVault: _currentVault);
}

class _TestPluginHostNotifier extends PluginHostNotifier {
  final PluginState _initialState;

  _TestPluginHostNotifier(this._initialState);

  @override
  PluginState build() => _initialState;
}

void main() {
  // These tests are pure widget tests — they pump a small widget tree
  // into a TestWidgetsFlutterBinding and assert what the renderer draws.
  // They do not need the integration-test driver, a real desktop, or
  // the rfbrowser.exe launcher. Originally they lived under
  // integration_test/ which forced a separate rfbrowser.exe build and
  // launch on a desktop session, which the windows-2022 CI runner
  // cannot provide. Running them as plain widget tests under
  // test/integration/ exercises the exact same code paths and produces
  // real failure messages, without needing a window.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PluginSettingsSection UI', () {
    Future<void> pumpPluginSettings(
      WidgetTester tester, {
      PluginState? pluginState,
      VaultConfig? vaultConfig,
    }) async {
      final state = pluginState ?? PluginState();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginHostProvider.overrideWith(
              () => _TestPluginHostNotifier(state),
            ),
            vaultProvider.overrideWith(
              () => _TestVaultNotifier(currentVault: vaultConfig),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: PluginSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('AC-PS-1: shows empty state when no plugins registered', (
      tester,
    ) async {
      await pumpPluginSettings(tester);

      expect(find.byIcon(Icons.extension_off), findsOneWidget);
    });

    testWidgets('AC-PS-2: shows plugin card for registered plugin', (
      tester,
    ) async {
      final manifest = HelloWorldPlugin().manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: true},
        running: {manifest.id: true},
        commands: {manifest.id: HelloWorldPlugin().commands},
      );

      await pumpPluginSettings(tester, pluginState: state);

      expect(find.text('Hello World'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
    });

    testWidgets('AC-PS-3: shows builtin badge for builtin plugin', (
      tester,
    ) async {
      final manifest = HelloWorldPlugin().manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: true},
        running: {manifest.id: true},
        commands: {manifest.id: HelloWorldPlugin().commands},
      );

      await pumpPluginSettings(tester, pluginState: state);

      expect(find.text('Builtin'), findsOneWidget);
    });

    testWidgets('AC-PS-4: no builtin badge for external plugin', (
      tester,
    ) async {
      final manifest = PluginManifest(
        id: 'com.example.external',
        name: 'External Plugin',
        version: '0.1.0',
        description: 'An external plugin',
        permissions: [Permission.knowledgeRead],
      );
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: false},
        running: {},
        commands: {},
      );

      await pumpPluginSettings(tester, pluginState: state);

      expect(find.text('External Plugin'), findsOneWidget);
      expect(find.text('Builtin'), findsNothing);
    });

    testWidgets('AC-PS-5: switch is on for running plugin', (tester) async {
      final manifest = HelloWorldPlugin().manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: true},
        running: {manifest.id: true},
        commands: {manifest.id: HelloWorldPlugin().commands},
      );

      await pumpPluginSettings(tester, pluginState: state);

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, true);
    });

    testWidgets('AC-PS-6: switch is off for disabled plugin', (tester) async {
      final manifest = HelloWorldPlugin().manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: false},
        running: {},
        commands: {},
      );

      await pumpPluginSettings(tester, pluginState: state);

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, false);
    });

    testWidgets('AC-PS-7: expands to show details on tap', (tester) async {
      final plugin = HelloWorldPlugin();
      final manifest = plugin.manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: true},
        running: {manifest.id: true},
        commands: {manifest.id: plugin.commands},
      );

      await pumpPluginSettings(tester, pluginState: state);

      await tester.tap(find.text('Hello World'));
      await tester.pumpAndSettle();

      expect(find.text('Author'), findsOneWidget);
      expect(find.text('RFBrowser Team'), findsOneWidget);
    });

    testWidgets('AC-PS-8: shows permission chips when expanded', (
      tester,
    ) async {
      final plugin = HelloWorldPlugin();
      final manifest = plugin.manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: true},
        running: {manifest.id: true},
        commands: {manifest.id: plugin.commands},
      );

      await pumpPluginSettings(tester, pluginState: state);

      await tester.tap(find.text('Hello World'));
      await tester.pumpAndSettle();

      expect(find.text('knowledge.read'), findsOneWidget);
      expect(find.text('knowledge.write'), findsOneWidget);
      expect(find.text('browser.read'), findsOneWidget);
      expect(find.text('ui.command'), findsOneWidget);
      expect(find.text('ui.panel'), findsOneWidget);
    });

    testWidgets('AC-PS-9: shows commands list when expanded', (tester) async {
      final plugin = HelloWorldPlugin();
      final manifest = plugin.manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: true},
        running: {manifest.id: true},
        commands: {manifest.id: plugin.commands},
      );

      await pumpPluginSettings(tester, pluginState: state);

      await tester.tap(find.text('Hello World'));
      await tester.pumpAndSettle();

      expect(find.text('• Say Hello'), findsOneWidget);
      expect(find.text('• Count Notes'), findsOneWidget);
      expect(find.text('• Show Hello Panel'), findsOneWidget);
    });

    testWidgets('AC-PS-10: shows skills list when expanded', (tester) async {
      final plugin = HelloWorldPlugin();
      final manifest = plugin.manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: true},
        running: {manifest.id: true},
        commands: {manifest.id: plugin.commands},
      );

      await pumpPluginSettings(tester, pluginState: state);

      await tester.tap(find.text('Hello World'));
      await tester.pumpAndSettle();

      expect(find.text('• Greeting Generator'), findsOneWidget);
      expect(find.text('• Note Statistics'), findsOneWidget);
    });

    testWidgets('AC-PS-11: shows error indicator when plugin has error', (
      tester,
    ) async {
      final manifest = HelloWorldPlugin().manifest;
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: true},
        running: {manifest.id: true},
        commands: {manifest.id: HelloWorldPlugin().commands},
        error: 'Something went wrong',
      );

      await pumpPluginSettings(tester, pluginState: state);

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('AC-PS-12: shows install and marketplace buttons', (
      tester,
    ) async {
      final vaultConfig = VaultConfig(
        path: '/tmp/test-vault',
        name: 'Test Vault',
        lastOpened: DateTime.now(),
      );

      await pumpPluginSettings(tester, vaultConfig: vaultConfig);

      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.store), findsOneWidget);
    });

    testWidgets('AC-PS-13: shows multiple plugin cards', (tester) async {
      final hwManifest = HelloWorldPlugin().manifest;
      final extManifest = PluginManifest(
        id: 'com.example.ext',
        name: 'External Plugin',
        version: '0.2.0',
        description: 'Another plugin',
        permissions: [Permission.browserRead],
      );
      final state = PluginState(
        manifests: {hwManifest.id: hwManifest, extManifest.id: extManifest},
        enabled: {hwManifest.id: true, extManifest.id: false},
        running: {hwManifest.id: true},
        commands: {hwManifest.id: HelloWorldPlugin().commands},
      );

      await pumpPluginSettings(tester, pluginState: state);

      expect(find.text('Hello World'), findsOneWidget);
      expect(find.text('External Plugin'), findsOneWidget);
    });

    testWidgets('AC-PS-14: plugin description shown when present', (
      tester,
    ) async {
      final manifest = PluginManifest(
        id: 'desc-test',
        name: 'Described Plugin',
        version: '1.0.0',
        description: 'A plugin with a description',
        permissions: [],
      );
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: false},
        running: {},
        commands: {},
      );

      await pumpPluginSettings(tester, pluginState: state);

      expect(find.text('A plugin with a description'), findsOneWidget);
    });

    testWidgets('AC-PS-15: plugin id shown when description is empty', (
      tester,
    ) async {
      final manifest = PluginManifest(
        id: 'no-desc-test',
        name: 'No Desc Plugin',
        version: '1.0.0',
        permissions: [],
      );
      final state = PluginState(
        manifests: {manifest.id: manifest},
        enabled: {manifest.id: false},
        running: {},
        commands: {},
      );

      await pumpPluginSettings(tester, pluginState: state);

      expect(find.text('no-desc-test'), findsOneWidget);
    });
  });
}

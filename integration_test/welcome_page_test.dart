import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/welcome_page.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Welcome Page', () {
    Future<void> pumpWelcomePage(
      WidgetTester tester, {
      List<VaultConfig> recentVaults = const [],
      String? error,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultProvider.overrideWith(
              () => _TestVaultNotifier(
                recentVaults: recentVaults,
                error: error,
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WelcomePage(onVaultOpened: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders app name and subtitle', (tester) async {
      await pumpWelcomePage(tester);

      expect(find.byIcon(Icons.explore), findsOneWidget);
      expect(find.text('RFBrowser'), findsOneWidget);
    });

    testWidgets('renders open vault and create vault buttons', (tester) async {
      await pumpWelcomePage(tester);

      expect(find.text('Open Vault'), findsOneWidget);
      expect(find.text('Create Vault'), findsOneWidget);
    });

    testWidgets('shows no recent vaults section when empty', (tester) async {
      await pumpWelcomePage(tester);

      expect(find.text('Recent Vaults'), findsNothing);
    });

    testWidgets('shows recent vaults when available', (tester) async {
      final vaults = [
        VaultConfig(
          path: '/path/to/vault1',
          name: 'My Vault',
          lastOpened: DateTime.now(),
        ),
        VaultConfig(
          path: '/path/to/vault2',
          name: 'Work Vault',
          lastOpened: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      await pumpWelcomePage(tester, recentVaults: vaults);

      expect(find.text('Recent Vaults'), findsOneWidget);
      expect(find.text('My Vault'), findsOneWidget);
      expect(find.text('Work Vault'), findsOneWidget);
    });

    testWidgets('shows today for recently opened vault', (tester) async {
      final vaults = [
        VaultConfig(
          path: '/path/to/vault1',
          name: 'Today Vault',
          lastOpened: DateTime.now(),
        ),
      ];

      await pumpWelcomePage(tester, recentVaults: vaults);

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('shows yesterday for vault opened yesterday', (tester) async {
      final vaults = [
        VaultConfig(
          path: '/path/to/vault1',
          name: 'Yesterday Vault',
          lastOpened: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      await pumpWelcomePage(tester, recentVaults: vaults);

      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('shows error banner when error exists', (tester) async {
      await pumpWelcomePage(tester, error: 'Failed to open vault');

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Failed to open vault'), findsOneWidget);
    });

    testWidgets('does not show error banner when no error', (tester) async {
      await pumpWelcomePage(tester);

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('delete vault button shows confirmation dialog (UX-3)', (tester) async {
      final vaults = [
        VaultConfig(
          path: '/path/to/vault1',
          name: 'Delete Me',
          lastOpened: DateTime.now(),
        ),
      ];

      await pumpWelcomePage(tester, recentVaults: vaults);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('cancel delete does not remove vault (UX-3)', (tester) async {
      final vaults = [
        VaultConfig(
          path: '/path/to/vault1',
          name: 'Keep Me',
          lastOpened: DateTime.now(),
        ),
      ];

      await pumpWelcomePage(tester, recentVaults: vaults);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Keep Me'), findsOneWidget);
    });

    testWidgets('shows vault path in list item', (tester) async {
      final vaults = [
        VaultConfig(
          path: '/path/to/my-vault',
          name: 'My Vault',
          lastOpened: DateTime.now(),
        ),
      ];

      await pumpWelcomePage(tester, recentVaults: vaults);

      expect(find.text('/path/to/my-vault'), findsOneWidget);
    });
  });
}

class _TestVaultNotifier extends VaultNotifier {
  final List<VaultConfig> _recentVaults;
  final String? _error;

  _TestVaultNotifier({
    List<VaultConfig>? recentVaults,
    String? error,
  })  : _recentVaults = recentVaults ?? [],
        _error = error;

  @override
  VaultState build() => VaultState(
        recentVaults: _recentVaults,
        error: _error,
      );
}

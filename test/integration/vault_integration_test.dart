import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_platform_interface/src/method_channel_path_provider.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';

class _TestPathProviderPlatform extends PathProviderPlatform {
  final String supportDir;

  _TestPathProviderPlatform(this.supportDir);

  @override
  Future<String?> getApplicationSupportPath() async => supportDir;

  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => supportDir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vault Integration', () {
    late String supportDir;
    late String tempVaultDir;
    late ProviderContainer container;

    setUp(() async {
      supportDir = p.join(
        Directory.systemTemp.path,
        'rfb_vault_int_test_${DateTime.now().millisecondsSinceEpoch}',
      );
      tempVaultDir = p.join(
        Directory.systemTemp.path,
        'rfb_vault_data_${DateTime.now().millisecondsSinceEpoch}',
      );
      await Directory(supportDir).create(recursive: true);
      await Directory(tempVaultDir).create(recursive: true);

      PathProviderPlatform.instance = _TestPathProviderPlatform(supportDir);

      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      PathProviderPlatform.instance =
          MethodChannelPathProvider();
      if (Directory(supportDir).existsSync()) {
        Directory(supportDir).deleteSync(recursive: true);
      }
      if (Directory(tempVaultDir).existsSync()) {
        Directory(tempVaultDir).deleteSync(recursive: true);
      }
    });

    test('VaultNotifier build returns empty state', () {
      final state = container.read(vaultProvider);
      expect(state.currentVault, isNull);
      expect(state.recentVaults, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('VaultConfig toJson and fromJson roundtrip', () {
      final config = VaultConfig(
        path: '/test/path',
        name: 'TestVault',
        lastOpened: DateTime(2024, 6, 1, 12, 0),
      );

      final json = config.toJson();
      expect(json['path'], '/test/path');
      expect(json['name'], 'TestVault');

      final restored = VaultConfig.fromJson(json);
      expect(restored.path, config.path);
      expect(restored.name, config.name);
      expect(restored.lastOpened.millisecondsSinceEpoch,
          config.lastOpened.millisecondsSinceEpoch);
    });

    test('VaultState copyWith updates fields', () {
      final state = VaultState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(state.isLoading, isFalse);

      final withError = state.copyWith(error: 'Test error');
      expect(withError.error, 'Test error');

      final cleared = withError.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('VaultState copyWith clearCurrentVault sets null', () {
      final state = VaultState(
        currentVault: VaultConfig(
          path: '/test',
          name: 'Test',
          lastOpened: DateTime.now(),
        ),
      );

      final cleared = state.copyWith(clearCurrentVault: true);
      expect(cleared.currentVault, isNull);
    });

    test('loadRecentVaults loads from file', () async {
      final vaultConfigPath = p.join(supportDir, 'vaults.json');
      await File(vaultConfigPath).writeAsString(
        '{"current_vault":null,"recent_vaults":[{"path":"/test/vault","name":"Test Vault","lastOpened":"2024-06-01T12:00:00.000"}]}',
      );

      final notifier = container.read(vaultProvider.notifier);
      await notifier.loadRecentVaults();

      final state = container.read(vaultProvider);
      expect(state.recentVaults.length, 1);
      expect(state.recentVaults.first.name, 'Test Vault');
      expect(state.recentVaults.first.path, '/test/vault');
    });

    test('openVault updates current vault', () async {
      final notifier = container.read(vaultProvider.notifier);

      await notifier.openVault(tempVaultDir);

      final state = container.read(vaultProvider);
      expect(state.currentVault, isNotNull);
      expect(state.currentVault!.path, tempVaultDir);
    });

    test('openVault adds to recent vaults', () async {
      final notifier = container.read(vaultProvider.notifier);

      await notifier.openVault(tempVaultDir);

      final state = container.read(vaultProvider);
      expect(state.recentVaults.any((v) => v.path == tempVaultDir), isTrue);
    });

    test('openVault removes duplicate recent vault entry', () async {
      final notifier = container.read(vaultProvider.notifier);

      await notifier.openVault(tempVaultDir);
      await notifier.openVault(tempVaultDir);

      final state = container.read(vaultProvider);
      final count = state.recentVaults.where((v) => v.path == tempVaultDir).length;
      expect(count, 1);
    });

    test('closeVault clears current vault', () async {
      final notifier = container.read(vaultProvider.notifier);
      await notifier.openVault(tempVaultDir);

      expect(container.read(vaultProvider).currentVault, isNotNull);

      await notifier.closeVault();
      expect(container.read(vaultProvider).currentVault, isNull);
    });
  });
}
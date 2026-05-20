import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/stores/vault_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String supportDir;
  late String tempVaultDir;

  setUp(() async {
    supportDir = p.join(
      Directory.systemTemp.path,
      'rfbrowser_test_support_${DateTime.now().millisecondsSinceEpoch}',
    );
    tempVaultDir = p.join(
      Directory.systemTemp.path,
      'rfbrowser_test_vault_${DateTime.now().millisecondsSinceEpoch}',
    );
    await Directory(supportDir).create(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return supportDir;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (Directory(supportDir).existsSync()) {
      Directory(supportDir).deleteSync(recursive: true);
    }
    if (Directory(tempVaultDir).existsSync()) {
      Directory(tempVaultDir).deleteSync(recursive: true);
    }
  });
  group('VaultConfig', () {
    test('fromJson and toJson roundtrip', () {
      final config = VaultConfig(
        path: '/test/path',
        name: 'TestVault',
        lastOpened: DateTime(2024, 1, 15, 10, 30),
      );
      final json = config.toJson();
      expect(json['path'], '/test/path');
      expect(json['name'], 'TestVault');

      final restored = VaultConfig.fromJson(json);
      expect(restored.path, config.path);
      expect(restored.name, config.name);
      expect(restored.lastOpened.year, 2024);
    });
  });

  group('VaultState', () {
    test('copyWith preserves unchanged values', () {
      final state = VaultState(currentVault: null);
      final updated = state.copyWith();
      expect(updated.currentVault, isNull);
      expect(updated.recentVaults, isEmpty);
      expect(updated.isLoading, isFalse);
    });

    test('copyWith clearCurrentVault sets it to null', () {
      final vault = VaultConfig(
        path: '/vault',
        name: 'Vault',
        lastOpened: DateTime.now(),
      );
      final state = VaultState(currentVault: vault);
      final updated = state.copyWith(clearCurrentVault: true);
      expect(updated.currentVault, isNull);
    });

    test('copyWith clearError removes error', () {
      final state = VaultState(error: 'some error');
      final updated = state.copyWith(clearError: true);
      expect(updated.error, isNull);
    });

    test('copyWith sets isLoading', () {
      final state = VaultState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
    });
  });

  group('VaultNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no vault', () {
      final state = container.read(vaultProvider);
      expect(state.currentVault, isNull);
      expect(state.recentVaults, isEmpty);
    });

    test('openVault creates .rfbrowser subdirectories', () async {
      await container.read(vaultProvider.notifier).openVault(tempVaultDir);

      final state = container.read(vaultProvider);
      expect(state.currentVault, isNotNull);
      expect(state.currentVault!.path, p.normalize(p.absolute(tempVaultDir)));
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);

      expect(Directory(p.join(tempVaultDir, '.rfbrowser')).existsSync(), isTrue);
      expect(Directory(p.join(tempVaultDir, '.rfbrowser', 'cache')).existsSync(), isTrue);
      expect(Directory(p.join(tempVaultDir, '.rfbrowser', 'plugins')).existsSync(), isTrue);
      expect(Directory(p.join(tempVaultDir, '.rfbrowser', 'sync')).existsSync(), isTrue);
    });

    test('openVault updates recentVaults', () async {
      await container.read(vaultProvider.notifier).openVault(tempVaultDir);
      final state = container.read(vaultProvider);
      expect(state.recentVaults.length, 1);
      expect(state.recentVaults[0].name, p.basename(tempVaultDir));
    });

    test('createVault creates user subdirectories and opens vault', () async {
      await container.read(vaultProvider.notifier).createVault(tempVaultDir);

      expect(Directory(p.join(tempVaultDir, 'daily-notes')).existsSync(), isTrue);
      expect(Directory(p.join(tempVaultDir, 'clippings')).existsSync(), isTrue);
      expect(Directory(p.join(tempVaultDir, 'attachments')).existsSync(), isTrue);

      final state = container.read(vaultProvider);
      expect(state.currentVault, isNotNull);
      expect(state.currentVault!.name, p.basename(tempVaultDir));
    });

    test('closeVault clears current vault', () async {
      await container.read(vaultProvider.notifier).openVault(tempVaultDir);
      await container.read(vaultProvider.notifier).closeVault();

      final state = container.read(vaultProvider);
      expect(state.currentVault, isNull);
    });

    test('removeFromRecent removes vault from list', () async {
      await container.read(vaultProvider.notifier).openVault(tempVaultDir);
      await container.read(vaultProvider.notifier).removeFromRecent(tempVaultDir);

      final state = container.read(vaultProvider);
      expect(state.recentVaults.where((v) => v.path == p.normalize(p.absolute(tempVaultDir))), isEmpty);
    });

    test('removeFromRecent clears currentVault when removing active vault', () async {
      await container.read(vaultProvider.notifier).openVault(tempVaultDir);
      await container.read(vaultProvider.notifier).removeFromRecent(tempVaultDir);

      final state = container.read(vaultProvider);
      expect(state.currentVault, isNull);
    });

    test('loadRecentVaults loads persisted vaults', () async {
      await container.read(vaultProvider.notifier).openVault(tempVaultDir);
      await container.read(vaultProvider.notifier).closeVault();

      final container2 = ProviderContainer();
      addTearDown(() => container2.dispose());

      await container2.read(vaultProvider.notifier).loadRecentVaults();
      final state = container2.read(vaultProvider);
      expect(state.recentVaults.isNotEmpty, isTrue);
    });

    test('openVault handles non-existent directory', () async {
      final newDir = p.join(tempVaultDir, 'new_vault');
      await container.read(vaultProvider.notifier).openVault(newDir);

      expect(Directory(newDir).existsSync(), isTrue);
      final state = container.read(vaultProvider);
      expect(state.currentVault, isNotNull);
      expect(state.error, isNull);
    });

    test('recentVaults limited to 10 items', () async {
      final notifier = container.read(vaultProvider.notifier);
      for (int i = 0; i < 12; i++) {
        final dir = p.join(tempVaultDir, 'vault_$i');
        await notifier.openVault(dir);
      }

      final state = container.read(vaultProvider);
      expect(state.recentVaults.length, lessThanOrEqualTo(10));
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/browser_service.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
  @override
  set state(VaultState newState) => super.state = newState;
}

void main() {
  group('Browser Tab Lifecycle Integration Tests', () {
    late ProviderContainer container;
    late BrowserNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final vaultState = VaultState(
        currentVault: VaultConfig(
          path: '.',
          name: 'test',
          lastOpened: DateTime.now(),
        ),
      );
      container = ProviderContainer(overrides: [
        vaultProvider.overrideWith(() => TestVaultNotifier(vaultState)),
      ]);
      notifier = container.read(browserProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('createTab adds new tab and sets it as active', () {
      final tabId = notifier.createTab(url: 'https://example.com');
      final state = container.read(browserProvider);

      expect(state.tabs.length, 1);
      expect(state.activeTabId, tabId);
      expect(state.activeTab, isNotNull);
      expect(state.activeTab!.id, tabId);
      expect(state.activeTab!.isActive, isTrue);
    });

    test('createTab with url parameter sets initial URL', () {
      notifier.createTab(url: 'https://flutter.dev');
      final state = container.read(browserProvider);

      expect(state.tabs.first.url, 'https://flutter.dev');
    });

    test('createTab default url is about:blank', () {
      notifier.createTab();
      final state = container.read(browserProvider);

      expect(state.tabs.first.url, 'about:blank');
    });

    test('closeTab removes tab and adjusts active index', () {
      final tab1 = notifier.createTab(url: 'https://a.com');
      final tab2 = notifier.createTab(url: 'https://b.com');
      final tab3 = notifier.createTab(url: 'https://c.com');

      notifier.closeTab(tab2);
      final state = container.read(browserProvider);

      expect(state.tabs.length, 2);
      expect(state.tabs.where((t) => t.id == tab2).length, 0);
      expect(state.tabs.any((t) => t.id == tab1), isTrue);
      expect(state.activeTabId, tab3);
    });

    test('closeTab with only one tab clears all tabs', () {
      final tab1 = notifier.createTab(url: 'https://only.com');

      notifier.closeTab(tab1);
      final state = container.read(browserProvider);

      expect(state.tabs, isEmpty);
      expect(state.activeTabId, isNull);
      expect(state.activeTab, isNull);
    });

    test('closeTab active tab switches to adjacent tab', () {
      notifier.createTab(url: 'https://a.com');
      final tab2 = notifier.createTab(url: 'https://b.com');
      final tab3 = notifier.createTab(url: 'https://c.com');

      notifier.closeTab(tab3);
      final state = container.read(browserProvider);

      expect(state.activeTabId, tab2);
    });

    test('closeTab first active tab switches to next', () {
      final tab1 = notifier.createTab(url: 'https://a.com');
      final tab2 = notifier.createTab(url: 'https://b.com');

      notifier.setActiveTab(tab1);
      notifier.closeTab(tab1);
      final state = container.read(browserProvider);

      expect(state.activeTabId, tab2);
    });

    test('setActiveTab changes activeTabIndex', () {
      final tab1 = notifier.createTab(url: 'https://a.com');
      final tab2 = notifier.createTab(url: 'https://b.com');
      final tab3 = notifier.createTab(url: 'https://c.com');

      notifier.setActiveTab(tab1);
      final state = container.read(browserProvider);

      expect(state.activeTabId, tab1);
      expect(state.activeTab!.isActive, isTrue);
      expect(
        state.tabs.firstWhere((t) => t.id == tab2).isActive,
        isFalse,
      );
      expect(
        state.tabs.firstWhere((t) => t.id == tab3).isActive,
        isFalse,
      );
    });

    test('updateTabUrl changes URL of specified tab', () {
      final tabId = notifier.createTab(url: 'https://old.com');

      notifier.updateTabUrl(tabId, 'https://new.com');
      final state = container.read(browserProvider);

      expect(state.tabs.first.url, 'https://new.com');
    });

    test('updateTabUrl does not affect other tabs', () {
      final tab1 = notifier.createTab(url: 'https://a.com');
      final tab2 = notifier.createTab(url: 'https://b.com');

      notifier.updateTabUrl(tab1, 'https://updated.com');
      final state = container.read(browserProvider);

      expect(
        state.tabs.firstWhere((t) => t.id == tab1).url,
        'https://updated.com',
      );
      expect(
        state.tabs.firstWhere((t) => t.id == tab2).url,
        'https://b.com',
      );
    });

    test('activeTab returns current active tab', () {
      final tab1 = notifier.createTab(url: 'https://a.com');
      notifier.createTab(url: 'https://b.com');

      notifier.setActiveTab(tab1);
      final state = container.read(browserProvider);

      expect(state.activeTab, isNotNull);
      expect(state.activeTab!.id, tab1);
      expect(state.activeTab!.url, 'https://a.com');
    });

    test('activeTab returns null when no tabs exist', () {
      final state = container.read(browserProvider);

      expect(state.activeTab, isNull);
    });

    test('multiple tabs maintain independent URLs', () {
      final tab1 = notifier.createTab(url: 'https://flutter.dev');
      final tab2 = notifier.createTab(url: 'https://dart.dev');
      final tab3 = notifier.createTab(url: 'https://pub.dev');

      notifier.updateTabUrl(tab1, 'https://flutter.dev/docs');
      notifier.updateTabUrl(tab2, 'https://dart.dev/tutorials');
      notifier.updateTabUrl(tab3, 'https://pub.dev/packages');

      final state = container.read(browserProvider);

      expect(
        state.tabs.firstWhere((t) => t.id == tab1).url,
        'https://flutter.dev/docs',
      );
      expect(
        state.tabs.firstWhere((t) => t.id == tab2).url,
        'https://dart.dev/tutorials',
      );
      expect(
        state.tabs.firstWhere((t) => t.id == tab3).url,
        'https://pub.dev/packages',
      );
    });

    test('tab count is tracked correctly', () {
      expect(container.read(browserProvider).tabs.length, 0);

      notifier.createTab(url: 'https://a.com');
      expect(container.read(browserProvider).tabs.length, 1);

      notifier.createTab(url: 'https://b.com');
      expect(container.read(browserProvider).tabs.length, 2);

      notifier.createTab(url: 'https://c.com');
      expect(container.read(browserProvider).tabs.length, 3);

      final tabId = container.read(browserProvider).tabs.first.id;
      notifier.closeTab(tabId);
      expect(container.read(browserProvider).tabs.length, 2);
    });

    test('full lifecycle: create, navigate, switch, close', () {
      final tab1 = notifier.createTab(url: 'https://example.com');
      final tab2 = notifier.createTab(url: 'https://dart.dev');

      notifier.updateTabUrl(tab1, 'https://example.com/page1');
      notifier.setActiveTab(tab1);
      expect(container.read(browserProvider).activeTabId, tab1);

      notifier.closeTab(tab2);
      expect(container.read(browserProvider).tabs.length, 1);
      expect(container.read(browserProvider).activeTabId, tab1);

      notifier.closeTab(tab1);
      expect(container.read(browserProvider).tabs, isEmpty);
      expect(container.read(browserProvider).activeTabId, isNull);
    });
  });
}

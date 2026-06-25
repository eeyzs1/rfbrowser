// Covers acceptance criteria:
// - AC-P4-3-1: PluginUiNotifier.notify() adds a notification to state
// - AC-P4-3-2: PluginUiNotifier.showPanel() displays a panel in state
// - AC-P4-3-3: PluginUiNotifier.dismissNotification() removes a notification
// - AC-P4-3-4: PluginUiNotifier.closePanel() removes a panel
// - AC-P4-3-5: PluginUiNotifier.clearForPlugin() clears all notifications and
//   panels for a specific plugin
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/plugins/api/plugin_ui_notifier.dart';

void main() {
  late ProviderContainer container;
  late PluginUiNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(pluginUiProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('PluginUiNotifier initial state', () {
    test('starts with empty notifications and panels', () {
      final state = container.read(pluginUiProvider);
      expect(state.notifications, isEmpty);
      expect(state.panels, isEmpty);
    });
  });

  group('PluginUiNotifier.notify', () {
    test('adds a notification to the state', () {
      notifier.notify('plugin-a', 'Hello world');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, hasLength(1));
      expect(state.notifications.first.pluginId, 'plugin-a');
      expect(state.notifications.first.message, 'Hello world');
    });

    test('generates a unique id for each notification', () {
      notifier.notify('plugin-a', 'First');
      notifier.notify('plugin-a', 'Second');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, hasLength(2));
      expect(state.notifications.first.id, isNot(state.notifications.last.id));
    });

    test('preserves pluginId for multiple plugins', () {
      notifier.notify('plugin-a', 'From A');
      notifier.notify('plugin-b', 'From B');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, hasLength(2));
      expect(state.notifications[0].pluginId, 'plugin-a');
      expect(state.notifications[1].pluginId, 'plugin-b');
    });

    test('sets createdAt timestamp', () {
      final before = DateTime.now();
      notifier.notify('plugin-a', 'Timed');
      final after = DateTime.now();

      final state = container.read(pluginUiProvider);
      final createdAt = state.notifications.first.createdAt;
      expect(createdAt.isAfter(before.subtract(const Duration(milliseconds: 1))), isTrue);
      expect(createdAt.isBefore(after.add(const Duration(milliseconds: 1))), isTrue);
    });
  });

  group('PluginUiNotifier.showPanel', () {
    test('adds a panel to the state', () {
      notifier.showPanel('plugin-a', 'panel-1', 'My Panel', 'content');

      final state = container.read(pluginUiProvider);
      expect(state.panels, hasLength(1));
      expect(state.panels['panel-1'], isNotNull);
      expect(state.panels['panel-1']!.pluginId, 'plugin-a');
      expect(state.panels['panel-1']!.title, 'My Panel');
      expect(state.panels['panel-1']!.content, 'content');
    });

    test('overwrites panel with same id', () {
      notifier.showPanel('plugin-a', 'panel-1', 'First', 'v1');
      notifier.showPanel('plugin-a', 'panel-1', 'Second', 'v2');

      final state = container.read(pluginUiProvider);
      expect(state.panels, hasLength(1));
      expect(state.panels['panel-1']!.title, 'Second');
      expect(state.panels['panel-1']!.content, 'v2');
    });

    test('supports multiple panels with different ids', () {
      notifier.showPanel('plugin-a', 'panel-1', 'Panel 1', 'c1');
      notifier.showPanel('plugin-a', 'panel-2', 'Panel 2', 'c2');

      final state = container.read(pluginUiProvider);
      expect(state.panels, hasLength(2));
      expect(state.panels['panel-1']!.title, 'Panel 1');
      expect(state.panels['panel-2']!.title, 'Panel 2');
    });

    test('sets createdAt timestamp', () {
      final before = DateTime.now();
      notifier.showPanel('plugin-a', 'panel-1', 'Title', null);
      final after = DateTime.now();

      final state = container.read(pluginUiProvider);
      final createdAt = state.panels['panel-1']!.createdAt;
      expect(createdAt.isAfter(before.subtract(const Duration(milliseconds: 1))), isTrue);
      expect(createdAt.isBefore(after.add(const Duration(milliseconds: 1))), isTrue);
    });
  });

  group('PluginUiNotifier.dismissNotification', () {
    test('removes the notification with the given id', () {
      notifier.notify('plugin-a', 'First');
      notifier.notify('plugin-a', 'Second');

      final stateBefore = container.read(pluginUiProvider);
      final firstId = stateBefore.notifications.first.id;

      notifier.dismissNotification(firstId);

      final stateAfter = container.read(pluginUiProvider);
      expect(stateAfter.notifications, hasLength(1));
      expect(stateAfter.notifications.first.message, 'Second');
    });

    test('does nothing when notification id does not exist', () {
      notifier.notify('plugin-a', 'Hello');

      notifier.dismissNotification('nonexistent-id');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, hasLength(1));
    });

    test('does nothing when there are no notifications', () {
      notifier.dismissNotification('any-id');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, isEmpty);
    });
  });

  group('PluginUiNotifier.closePanel', () {
    test('removes the panel with the given id', () {
      notifier.showPanel('plugin-a', 'panel-1', 'Panel 1', 'c1');
      notifier.showPanel('plugin-a', 'panel-2', 'Panel 2', 'c2');

      notifier.closePanel('panel-1');

      final state = container.read(pluginUiProvider);
      expect(state.panels, hasLength(1));
      expect(state.panels['panel-2'], isNotNull);
      expect(state.panels['panel-1'], isNull);
    });

    test('does nothing when panel id does not exist', () {
      notifier.showPanel('plugin-a', 'panel-1', 'Panel 1', 'c1');

      notifier.closePanel('nonexistent');

      final state = container.read(pluginUiProvider);
      expect(state.panels, hasLength(1));
    });

    test('does nothing when there are no panels', () {
      notifier.closePanel('any-id');

      final state = container.read(pluginUiProvider);
      expect(state.panels, isEmpty);
    });
  });

  group('PluginUiNotifier.clearForPlugin', () {
    test('removes all notifications for the specified plugin', () {
      notifier.notify('plugin-a', 'A1');
      notifier.notify('plugin-b', 'B1');
      notifier.notify('plugin-a', 'A2');
      notifier.notify('plugin-b', 'B2');

      notifier.clearForPlugin('plugin-a');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, hasLength(2));
      for (final n in state.notifications) {
        expect(n.pluginId, 'plugin-b');
      }
    });

    test('removes all panels for the specified plugin', () {
      notifier.showPanel('plugin-a', 'p1', 'A1', 'c1');
      notifier.showPanel('plugin-b', 'p2', 'B1', 'c1');
      notifier.showPanel('plugin-a', 'p3', 'A2', 'c2');

      notifier.clearForPlugin('plugin-a');

      final state = container.read(pluginUiProvider);
      expect(state.panels, hasLength(1));
      expect(state.panels['p2'], isNotNull);
      expect(state.panels['p2']!.pluginId, 'plugin-b');
    });

    test('removes both notifications and panels for the plugin', () {
      notifier.notify('plugin-a', 'A1');
      notifier.showPanel('plugin-a', 'p1', 'Panel', 'c');
      notifier.notify('plugin-b', 'B1');
      notifier.showPanel('plugin-b', 'p2', 'Panel B', 'c');

      notifier.clearForPlugin('plugin-a');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, hasLength(1));
      expect(state.notifications.first.pluginId, 'plugin-b');
      expect(state.panels, hasLength(1));
      expect(state.panels['p2']!.pluginId, 'plugin-b');
    });

    test('does not affect other plugins', () {
      notifier.notify('plugin-a', 'A1');
      notifier.notify('plugin-b', 'B1');
      notifier.showPanel('plugin-a', 'p1', 'A', 'c');
      notifier.showPanel('plugin-b', 'p2', 'B', 'c');

      notifier.clearForPlugin('plugin-a');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, hasLength(1));
      expect(state.notifications.first.pluginId, 'plugin-b');
      expect(state.panels, hasLength(1));
      expect(state.panels['p2']!.pluginId, 'plugin-b');
    });

    test('does nothing when plugin has no notifications or panels', () {
      notifier.notify('plugin-a', 'A1');
      notifier.showPanel('plugin-a', 'p1', 'A', 'c');

      notifier.clearForPlugin('plugin-nonexistent');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, hasLength(1));
      expect(state.panels, hasLength(1));
    });

    test('clears everything when all belong to the specified plugin', () {
      notifier.notify('plugin-a', 'A1');
      notifier.notify('plugin-a', 'A2');
      notifier.showPanel('plugin-a', 'p1', 'A', 'c');
      notifier.showPanel('plugin-a', 'p2', 'A2', 'c');

      notifier.clearForPlugin('plugin-a');

      final state = container.read(pluginUiProvider);
      expect(state.notifications, isEmpty);
      expect(state.panels, isEmpty);
    });
  });
}

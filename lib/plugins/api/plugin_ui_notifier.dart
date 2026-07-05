import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A notification emitted by a plugin via [UIAPI.showNotification].
class PluginNotification {
  final String id;
  final String pluginId;
  final String message;
  final DateTime createdAt;

  PluginNotification({
    required this.id,
    required this.pluginId,
    required this.message,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// A panel registered by a plugin via [UIAPI.showPanel].
class PluginPanel {
  final String id;
  final String pluginId;
  final String title;
  final dynamic content;
  final DateTime createdAt;

  PluginPanel({
    required this.id,
    required this.pluginId,
    required this.title,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class PluginUiState {
  final List<PluginNotification> notifications;
  final Map<String, PluginPanel> panels;

  const PluginUiState({this.notifications = const [], this.panels = const {}});

  PluginUiState copyWith({
    List<PluginNotification>? notifications,
    Map<String, PluginPanel>? panels,
  }) {
    return PluginUiState(
      notifications: notifications ?? this.notifications,
      panels: panels ?? this.panels,
    );
  }
}

/// Backs [UIAPI.showNotification] / [UIAPI.showPanel] for sandboxed plugins.
///
/// Plugins run in a separate isolate and cannot touch the widget tree
/// directly. They emit notifications / panels here; the UI layer subscribes
/// to [pluginUiProvider] and renders them on the host side.
class PluginUiNotifier extends Notifier<PluginUiState> {
  /// Monotonic counter appended to notification ids so that two notifications
  /// emitted within the same millisecond (or even microsecond) still get
  /// distinct ids.
  static int _idCounter = 0;

  @override
  PluginUiState build() {
    _idCounter = 0;
    return const PluginUiState();
  }

  void notify(String pluginId, String message) {
    final notification = PluginNotification(
      id: '${pluginId}_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
      pluginId: pluginId,
      message: message,
    );
    state = state.copyWith(
      notifications: [...state.notifications, notification],
    );
  }

  void showPanel(String pluginId, String id, String title, dynamic content) {
    final panel = PluginPanel(
      id: id,
      pluginId: pluginId,
      title: title,
      content: content,
    );
    state = state.copyWith(panels: {...state.panels, id: panel});
  }

  void dismissNotification(String id) {
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != id).toList(),
    );
  }

  void closePanel(String id) {
    final panels = Map<String, PluginPanel>.from(state.panels);
    panels.remove(id);
    state = state.copyWith(panels: panels);
  }

  void clearForPlugin(String pluginId) {
    state = state.copyWith(
      notifications: state.notifications
          .where((n) => n.pluginId != pluginId)
          .toList(),
      panels: Map.fromEntries(
        state.panels.entries.where((e) => e.value.pluginId != pluginId),
      ),
    );
  }
}

final pluginUiProvider = NotifierProvider<PluginUiNotifier, PluginUiState>(
  PluginUiNotifier.new,
);

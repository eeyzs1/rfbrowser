// ignore_for_file: avoid_print
import 'plugin_host.dart';

/// Thrown when a plugin attempts to call a sandbox API for which it has not
/// been granted the corresponding [Permission] in its [PluginManifest].
class PluginCapabilityDeniedError implements Exception {
  final String pluginId;
  final Permission permission;
  final String message;

  PluginCapabilityDeniedError({
    required this.pluginId,
    required this.permission,
    String? message,
  }) : message =
           message ??
           'Plugin "$pluginId" lacks permission "${permission.name}"';

  @override
  String toString() => 'PluginCapabilityDeniedError: $message';
}

/// G14-A: capability checker for sandboxed plugin APIs.
///
/// Plugins run in a separate isolate with no automatic access to the host's
/// knowledge store, browser, AI service, etc. Each capability-protected call
/// must go through [CapabilityChecker.assertCapability] first; the checker
/// verifies the plugin's manifest grants the required permission.
///
/// Usage:
///
/// ```dart
/// class KnowledgeAPIImpl implements KnowledgeAPI {
///   KnowledgeAPIImpl(this._checker, this._repo);
///
///   final CapabilityChecker _checker;
///   final NoteRepository _repo;
///
///   @override
///   Future<Map<String, dynamic>?> getNote(String id) async {
///     _checker.assertCapability(Permission.knowledgeRead);
///     final note = await _repo.getNoteById(id);
///     return note?.toMap();
///   }
/// }
/// ```
class CapabilityChecker {
  final String pluginId;
  final PluginManifest manifest;

  CapabilityChecker({required this.pluginId, required this.manifest});

  /// Returns true if [manifest.permissions] contains [permission].
  bool hasCapability(Permission permission) =>
      manifest.permissions.contains(permission);

  /// Throws [PluginCapabilityDeniedError] when the manifest does not grant
  /// [permission]. Returns silently on success.
  void assertCapability(Permission permission) {
    if (!hasCapability(permission)) {
      throw PluginCapabilityDeniedError(
        pluginId: pluginId,
        permission: permission,
      );
    }
  }

  /// Same as [assertCapability] but for a *set* of permissions (all-or-nothing).
  void assertAllCapabilities(Iterable<Permission> permissions) {
    for (final p in permissions) {
      assertCapability(p);
    }
  }

  /// Same as [assertCapability] but for *any* of the listed permissions.
  /// Throws if NONE of them is granted.
  void assertAnyCapability(Iterable<Permission> permissions) {
    if (!permissions.any(hasCapability)) {
      throw PluginCapabilityDeniedError(
        pluginId: pluginId,
        permission: permissions.first,
        message:
            'Plugin "$pluginId" lacks at least one of: '
            '${permissions.map((p) => p.name).join(', ')}',
      );
    }
  }
}

/// Maps API surface to the permission it requires. Centralising this table
/// here prevents drift between callers and keeps the policy in one place.
class CapabilityMatrix {
  /// Read-only knowledge operations: query, get, search.
  static const Permission knowledgeRead = Permission.knowledgeRead;

  /// Knowledge mutation: create, update, delete notes.
  static const Permission knowledgeWrite = Permission.knowledgeWrite;

  /// Read browser tab state (URL, page content).
  static const Permission browserRead = Permission.browserRead;

  /// Mutate browser state (navigate, close tabs).
  static const Permission browserWrite = Permission.browserWrite;

  /// AI chat / completion.
  static const Permission aiChat = Permission.aiChat;

  /// Issue UI commands (e.g. switch scene).
  static const Permission uiCommand = Permission.uiCommand;

  /// Register a panel.
  static const Permission uiPanel = Permission.uiPanel;
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging/app_logger.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/stores/index_store.dart';
import '../../services/agent/agent_tool.dart';
import '../../services/browser_service.dart';
import '../../services/agent_service.dart';
import '../../data/models/agent_task.dart';
import '../api/plugin_api_impl.dart';
import 'capability_checker.dart';

part 'plugin_sandbox.dart';
part 'plugin_host_notifier.dart';

enum Permission {
  knowledgeRead,
  knowledgeWrite,
  browserRead,
  browserWrite,
  aiChat,
  uiCommand,
  uiPanel,
}

class PluginManifest {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final List<Permission> permissions;
  /// Relative path to the JS entry point file (e.g. "main.js").
  /// When set, the sandbox loads and runs this file in a QuickJS engine.
  final String? entryPoint;

  PluginManifest({
    required this.id,
    required this.name,
    this.version = '0.1.0',
    this.author = '',
    this.description = '',
    this.permissions = const [],
    this.entryPoint,
  });

  factory PluginManifest.fromMap(Map<String, dynamic> map) => PluginManifest(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    version: map['version'] as String? ?? '0.1.0',
    author: map['author'] as String? ?? '',
    description: map['description'] as String? ?? '',
    permissions:
        (map['permissions'] as List?)
            ?.map(
              (p) => Permission.values.firstWhere(
                (e) => e.name == p,
                orElse: () => Permission.knowledgeRead,
              ),
            )
            .toList() ??
        [],
    entryPoint: map['entryPoint'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'permissions': permissions.map((p) => p.name).toList(),
    if (entryPoint != null) 'entryPoint': entryPoint,
  };
}

class PluginCommand {
  final String id;
  final String label;
  final String pluginId;

  PluginCommand({
    required this.id,
    required this.label,
    required this.pluginId,
  });
}

class PluginHook {
  final String event;
  final String handler;

  PluginHook({required this.event, required this.handler});

  factory PluginHook.fromMap(Map<String, dynamic> map) => PluginHook(
    event: map['event'] as String? ?? '',
    handler: map['handler'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {'event': event, 'handler': handler};
}

class PluginState {
  final Map<String, PluginManifest> manifests;
  final Map<String, bool> enabled;
  final Map<String, bool> running;
  final Map<String, List<PluginCommand>> commands;
  final String? error;

  PluginState({
    this.manifests = const {},
    this.enabled = const {},
    this.running = const {},
    this.commands = const {},
    this.error,
  });

  PluginState copyWith({
    Map<String, PluginManifest>? manifests,
    Map<String, bool>? enabled,
    Map<String, bool>? running,
    Map<String, List<PluginCommand>>? commands,
    String? error,
    bool clearError = false,
  }) {
    return PluginState(
      manifests: manifests ?? this.manifests,
      enabled: enabled ?? this.enabled,
      running: running ?? this.running,
      commands: commands ?? this.commands,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PermissionChecker {
  bool check(PluginManifest manifest, Permission permission) {
    return manifest.permissions.contains(permission);
  }

  List<Permission> missingPermissions(
    PluginManifest manifest,
    List<Permission> required,
  ) {
    return required.where((p) => !manifest.permissions.contains(p)).toList();
  }
}

typedef ApiHandler =
    Future<Map<String, dynamic>> Function(
      String apiName,
      Map<String, dynamic> args,
    );

class PermissionDeniedError implements Exception {
  final String message;
  PermissionDeniedError(this.message);

  @override
  String toString() => 'PermissionDeniedError: $message';
}

/// Resource quota for a plugin sandbox. Enforced on every [Sandbox.callApi]
/// invocation to prevent runaway plugins from exhausting host resources.
class ResourceQuota {
  /// Maximum API calls allowed per second. 0 means no limit.
  final int maxMessagesPerSecond;

  /// Maximum serialized payload size (request args) in bytes.
  final int maxMessageSizeBytes;

  /// Per-call execution timeout.
  final Duration maxExecutionDuration;

  /// Maximum consecutive errors before the sandbox is auto-stopped.
  final int maxConsecutiveErrors;

  const ResourceQuota({
    this.maxMessagesPerSecond = 100,
    this.maxMessageSizeBytes = 1024 * 1024, // 1 MB
    this.maxExecutionDuration = const Duration(seconds: 30),
    this.maxConsecutiveErrors = 10,
  });

  static const ResourceQuota defaultQuota = ResourceQuota();
}

class ResourceQuotaExceededError implements Exception {
  final String message;
  ResourceQuotaExceededError(this.message);

  @override
  String toString() => 'ResourceQuotaExceededError: $message';
}

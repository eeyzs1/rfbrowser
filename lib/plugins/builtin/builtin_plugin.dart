import 'package:flutter/material.dart';
import '../../data/models/skill.dart';
import '../host/plugin_host.dart';

abstract class BuiltinPlugin {
  PluginManifest get manifest;

  List<PluginCommand> get commands;

  List<Skill> get skills => const [];

  List<PluginHook> get hooks => const [];

  Widget? buildPanel(BuildContext context);

  Future<void> onEnable(PluginHostNotifier host);

  Future<void> onDisable(PluginHostNotifier host);

  Future<Map<String, dynamic>> handleApiCall(
    String apiName,
    Map<String, dynamic> args,
  );

  Future<void> onHookEvent(String event, Map<String, dynamic> data) async {}
}

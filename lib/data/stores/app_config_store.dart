import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfigStore {
  static AppConfigStore? _instance;
  static AppConfigStore get instance => _instance ??= AppConfigStore._();

  AppConfigStore._();

  String? _configDir;
  SharedPreferences? _prefs;

  Future<String> get configDir async {
    if (_configDir != null) return _configDir!;
    final dir = await getApplicationSupportDirectory();
    _configDir = dir.path;
    return _configDir!;
  }

  Future<String> get _configPath async {
    final dir = await configDir;
    return p.join(dir, 'rfbrowser_config.json');
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Map<String, dynamic>> loadConfig() async {
    final path = await _configPath;
    final file = File(path);
    if (await file.exists()) {
      try {
        return Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()) as Map,
        );
      } catch (_) {}
    }
    return {};
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    final path = await _configPath;
    final file = File(path);
    final dir = Directory(p.dirname(path));
    if (!await dir.exists()) await dir.create(recursive: true);
    await file.writeAsString(
      JsonEncoder.withIndent('  ').convert(config),
    );
  }

  Future<void> migrateFromSharedPreferences() async {
    final sp = await prefs;
    final config = <String, dynamic>{};

    final keys = sp.getKeys();
    if (keys.isEmpty) return;

    for (final key in keys) {
      final value = sp.get(key);
      if (value != null) {
        config[key] = value;
      }
    }

    if (config.isNotEmpty) {
      await saveConfig(config);
    }
  }
}

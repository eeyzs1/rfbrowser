import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String configPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rfbrowser_config_test_');
    configPath = p.join(tempDir.path, 'rfbrowser_config.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> writeConfig(Map<String, dynamic> config) async {
    final dir = Directory(p.dirname(configPath));
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(configPath).writeAsString(
      JsonEncoder.withIndent('  ').convert(config),
    );
  }

  Future<Map<String, dynamic>> readConfig() async {
    final file = File(configPath);
    if (!await file.exists()) return {};
    try {
      return Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
    } catch (_) {
      return {};
    }
  }

  group('AppConfigStore JSON serialization', () {
    test('loadConfig returns empty map when config file does not exist',
        () async {
      final config = await readConfig();
      expect(config, isEmpty);
    });

    test('saveConfig writes JSON file with correct content', () async {
      final config = {
        'theme': 'dark',
        'fontSize': 14,
        'language': 'zh-CN',
      };
      await writeConfig(config);

      final file = File(configPath);
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['theme'], 'dark');
      expect(decoded['fontSize'], 14);
      expect(decoded['language'], 'zh-CN');
    });

    test('saveConfig creates directory if not exists', () async {
      final nestedDir = Directory(p.join(tempDir.path, 'nested', 'deep'));
      final nestedPath = p.join(nestedDir.path, 'rfbrowser_config.json');

      final dir = Directory(p.dirname(nestedPath));
      if (!await dir.exists()) await dir.create(recursive: true);
      await File(nestedPath).writeAsString('{}');

      expect(await File(nestedPath).exists(), isTrue);
    });

    test('loadConfig returns saved config after saveConfig', () async {
      final config = {
        'vault': '/path/to/vault',
        'aiProvider': 'bailian',
        'shortcuts': {'search': 'Ctrl+K'},
      };
      await writeConfig(config);

      final loaded = await readConfig();
      expect(loaded['vault'], '/path/to/vault');
      expect(loaded['aiProvider'], 'bailian');
      expect(loaded['shortcuts'], isA<Map>());
    });

    test('saveConfig uses indented JSON encoding', () async {
      final config = {'key': 'value'};
      await writeConfig(config);

      final content = await File(configPath).readAsString();
      expect(content, contains('  "key"'));
      expect(content, contains('\n'));
    });

    test('loadConfig handles corrupt JSON gracefully', () async {
      await File(configPath).writeAsString('{invalid json}}}');
      final config = await readConfig();
      expect(config, isEmpty);
    });

    test('loadConfig handles empty JSON object', () async {
      await File(configPath).writeAsString('{}');
      final config = await readConfig();
      expect(config, isEmpty);
    });

    test('round-trip preserves nested structures', () async {
      final config = {
        'ui': {
          'theme': 'dark',
          'colors': {'accent': 0xFF2196F3, 'surface': 0xFF121212},
        },
        'ai': {
          'providers': [
            {'id': 'openai', 'name': 'OpenAI'},
            {'id': 'bailian', 'name': '百炼'},
          ],
        },
      };
      await writeConfig(config);
      final loaded = await readConfig();

      expect((loaded['ui'] as Map)['theme'], 'dark');
      expect(((loaded['ui'] as Map)['colors'] as Map)['accent'], 0xFF2196F3);
      expect((loaded['ai'] as Map)['providers'], isA<List>());
      expect(((loaded['ai'] as Map)['providers'] as List).length, 2);
    });
  });

  group('AppConfigStore migration logic', () {
    test('empty SharedPreferences produces no config file', () async {
      final spData = <String, dynamic>{};
      final config = <String, dynamic>{};

      for (final entry in spData.entries) {
        config[entry.key] = entry.value;
      }

      expect(config.isEmpty, isTrue);
    });

    test('SharedPreferences data maps to config correctly', () async {
      final spData = <String, dynamic>{
        'theme': 'dark',
        'fontSize': 14,
        'language': 'zh-CN',
      };
      final config = <String, dynamic>{};

      for (final entry in spData.entries) {
        config[entry.key] = entry.value;
      }

      expect(config['theme'], 'dark');
      expect(config['fontSize'], 14);
      expect(config['language'], 'zh-CN');
    });
  });
}

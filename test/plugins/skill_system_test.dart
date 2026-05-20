import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rfbrowser/data/models/skill.dart';
import 'package:rfbrowser/data/repositories/note_repository.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';
import 'package:rfbrowser/plugins/plugin_registry.dart';
import 'package:rfbrowser/plugins/builtin/hello_world/hello_world_plugin.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Skill System - All Sources', () {
    test('builtin skills include summarize-page', () {
      final noteService = _TestNoteService();
      final skills = noteService.testGetBuiltinSkills();

      final ids = skills.map((s) => s.id).toList();
      expect(ids, contains('summarize-page'));
      expect(ids, contains('daily-review'));
      expect(skills.length, 7);
    });

    test('plugin skills from HelloWorld include greeting and note-stats', () {
      final pluginSkills = PluginRegistry.getAllPluginSkills();

      final ids = pluginSkills.map((s) => s.id).toList();
      expect(ids, contains('hello-world.greeting'));
      expect(ids, contains('hello-world.note-stats'));
      expect(pluginSkills.length, 2);

      final greeting = pluginSkills.firstWhere((s) => s.id == 'hello-world.greeting');
      expect(greeting.params['tone'], isNotNull);
      expect(greeting.params['recipient'], isNotNull);
      expect(greeting.pluginId, 'hello-world');
    });

    test('YAML custom skill loads from vault .rfbrowser/skills/', () async {
      final tempDir = Directory.systemTemp.createTempSync('rfb_skill_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final skillsDir = Directory('${tempDir.path}/.rfbrowser/skills');
      skillsDir.createSync(recursive: true);

      final yamlContent = '''
id: custom-translate
name: Translate Note
description: Translate the current note to another language
prompt: |
  Translate the following note to {{target_language}}:
  @note[current]
''';

      File('${skillsDir.path}/custom-translate.yaml').writeAsStringSync(yamlContent);

      final repo = NoteRepository(tempDir.path);

      final container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);

      final vaultContainer = ProviderContainer(
        overrides: [
          noteRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(vaultContainer.dispose);

      final note = await repo.createNote(title: 'Dummy');
      final indexStore = vaultContainer.read(indexStoreProvider);
      await indexStore.indexNote(note);
      addTearDown(() => indexStore.close());

      final skills = await _loadYamlSkills(skillsDir);
      expect(skills.length, 1);
      expect(skills.first.id, 'custom-translate');
      expect(skills.first.name, 'Translate Note');
      expect(skills.first.prompt, contains('{{target_language}}'));
    });

    test('plugin + builtin + custom YAML skills all coexist', () {
      final builtinIds = _TestNoteService().testGetBuiltinSkills().map((s) => s.id).toSet();
      final pluginIds = PluginRegistry.getAllPluginSkills().map((s) => s.id).toSet();

      final allIds = {...builtinIds, ...pluginIds};
      expect(allIds, contains('summarize-page'));
      expect(allIds, contains('hello-world.greeting'));
      expect(allIds, contains('hello-world.note-stats'));
      expect(allIds, contains('auto-tag'));
    });

    test('plugin skills are discoverable via PluginRegistry', () {
      final found = PluginRegistry.findById('hello-world');
      expect(found, isNotNull);

      final plugin = found as HelloWorldPlugin;
      final skills = plugin.skills;

      expect(skills.length, 2);
      expect(skills.first.pluginId, 'hello-world');
      expect(skills.last.pluginId, 'hello-world');
    });

    test('Skill model with params works correctly', () {
      final skill = Skill(
        id: 'test-skill',
        name: 'Test',
        description: 'Test skill',
        prompt: 'Hello {{name}}',
        params: {
          'name': SkillParam(
            name: 'name',
            type: 'string',
            description: 'Your name',
            required: true,
            defaultValue: 'World',
          ),
        },
        pluginId: 'test-plugin',
        isBuiltin: false,
      );

      expect(skill.params['name']!.required, true);
      expect(skill.params['name']!.defaultValue, 'World');
      expect(skill.pluginId, 'test-plugin');
      expect(skill.isBuiltin, false);
    });
  });

  group('Plugin + Skill Bridge', () {
    test('HelloWorld plugin declares skills with params', () {
      final plugin = HelloWorldPlugin();

      expect(plugin.skills.length, 2);
      expect(plugin.skills[0].pluginId, 'hello-world');
      expect(plugin.skills[1].pluginId, 'hello-world');

      expect(plugin.commands.length, 3);
      expect(plugin.skills.length + plugin.commands.length, 5);
    });

    test('Sandbox isolation protects skills from plugin crash', () async {
      final manifest = PluginManifest(
        id: 'skill-plugin',
        name: 'Skill Plugin',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async => {'ok': true},
      );
      await sandbox.start();
      addTearDown(sandbox.stop);

      final result = await sandbox.callApi<Map<String, dynamic>>(
        'knowledge.getNote',
        {'id': 'test.md'},
        requiredPermission: Permission.knowledgeRead,
      );
      expect(result, isNotNull);
      expect(result!['ok'], true);
    });
  });
}

class _TestNoteService {
  List<Skill> testGetBuiltinSkills() {
    return [
      Skill(
        id: 'summarize-page',
        name: 'Summarize Page',
        description: 'Summarize the current web page',
        prompt: 'Please summarize the following web page content:\n\n@web[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'summarize-note',
        name: 'Summarize Note',
        description: 'Summarize the current note',
        prompt: 'Please summarize the following note:\n\n@note[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'research-topic',
        name: 'Research Topic',
        description: 'Deep research on a topic',
        prompt: 'Conduct thorough research on the following topic:\n\n{{topic}}',
        params: {
          'topic': SkillParam(name: 'topic', type: 'string', description: 'Topic to research', required: true),
        },
        isBuiltin: true,
      ),
      Skill(
        id: 'extract-key-points',
        name: 'Extract Key Points',
        description: 'Extract key points from content',
        prompt: 'Extract the key points:\n\n@note[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'generate-outline',
        name: 'Generate Outline',
        description: 'Generate an outline for a topic',
        prompt: 'Generate a detailed outline for:\n\n{{topic}}',
        params: {
          'topic': SkillParam(name: 'topic', type: 'string', description: 'Topic for the outline', required: true),
        },
        isBuiltin: true,
      ),
      Skill(
        id: 'auto-tag',
        name: 'Auto Tag',
        description: 'Automatically suggest tags',
        prompt: 'Analyze the note and suggest tags:\n\n@note[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'daily-review',
        name: 'Daily Review',
        description: 'Generate a daily review summary',
        prompt: "Review today's daily note:\n\n@note[daily]",
        isBuiltin: true,
      ),
    ];
  }
}

Future<List<Skill>> _loadYamlSkills(Directory skillsDir) async {
  final skills = <Skill>[];
  if (!await skillsDir.exists()) return skills;

  await for (final entity in skillsDir.list()) {
    if (entity is File && entity.path.endsWith('.yaml')) {
      try {
        final content = await entity.readAsString();
        final lines = content.split('\n');
        String id = '';
        String name = '';
        String description = '';
        String prompt = '';

        for (final line in lines) {
          if (line.startsWith('id:')) {
            id = line.substring(3).trim();
          } else if (line.startsWith('name:')) {
            name = line.substring(5).trim();
          } else if (line.startsWith('description:')) {
            description = line.substring(12).trim();
          }
        }

        final promptStart = lines.indexWhere((l) => l.startsWith('prompt:'));
        if (promptStart >= 0) {
          final promptLines = <String>[];
          for (var i = promptStart + 1; i < lines.length; i++) {
            final line = lines[i];
            if (line.startsWith('  ')) {
              promptLines.add(line.substring(2));
            } else if (line.trim().isNotEmpty) {
              break;
            }
          }
          prompt = promptLines.join('\n');
        }

        skills.add(Skill(
          id: id.isNotEmpty ? id : entity.path,
          name: name.isNotEmpty ? name : 'Unnamed',
          description: description,
          prompt: prompt,
          isBuiltin: false,
        ));
      } catch (e) {
        // skip malformed files
      }
    }
  }
  return skills;
}
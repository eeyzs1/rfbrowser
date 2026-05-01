import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../data/models/skill.dart';
import '../data/stores/vault_store.dart';

class SkillService {
  final String vaultPath;

  SkillService(this.vaultPath);

  Future<List<Skill>> getAllSkills() async {
    final skills = <Skill>[];
    skills.addAll(_getBuiltinSkills());

    final skillDir = Directory(p.join(vaultPath, '.rfbrowser', 'skills'));
    if (await skillDir.exists()) {
      await for (final entity in skillDir.list()) {
        if (entity is File && entity.path.endsWith('.yaml')) {
          try {
            final content = await entity.readAsString();
            final yaml = loadYaml(content);
            skills.add(
              Skill(
                id: yaml['id'] ?? p.basenameWithoutExtension(entity.path),
                name: yaml['name'] ?? 'Unnamed',
                description: yaml['description'] ?? '',
                prompt: yaml['prompt'] ?? '',
                isBuiltin: false,
              ),
            );
          } catch (_) {}
        }
      }
    }
    return skills;
  }

  Future<void> createSkill(Skill skill) async {
    final skillDir = Directory(p.join(vaultPath, '.rfbrowser', 'skills'));
    if (!await skillDir.exists()) {
      await skillDir.create(recursive: true);
    }
    final content =
        '''id: ${skill.id}
name: ${skill.name}
description: ${skill.description}
prompt: |
  ${skill.prompt.split('\n').join('\n  ')}
''';
    final file = File(p.join(skillDir.path, '${skill.id}.yaml'));
    await file.writeAsString(content);
  }

  Future<void> deleteSkill(String skillId) async {
    final file = File(
      p.join(vaultPath, '.rfbrowser', 'skills', '$skillId.yaml'),
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  List<Skill> _getBuiltinSkills() {
    return [
      Skill(
        id: 'summarize-page',
        name: 'Summarize Page',
        description: 'Summarize the current web page',
        prompt:
            'Please summarize the following web page content:\n\n@web[current]',
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
        prompt:
            'Conduct thorough research on the following topic and provide a comprehensive summary with key findings:\n\n{{topic}}',
        params: {
          'topic': SkillParam(
            name: 'topic',
            type: 'string',
            description: 'Topic to research',
            required: true,
          ),
        },
        isBuiltin: true,
      ),
      Skill(
        id: 'extract-key-points',
        name: 'Extract Key Points',
        description: 'Extract key points from content',
        prompt:
            'Extract the key points from the following content and format them as a bullet list:\n\n@note[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'generate-outline',
        name: 'Generate Outline',
        description: 'Generate an outline for a topic',
        prompt:
            'Generate a detailed outline for the following topic:\n\n{{topic}}',
        params: {
          'topic': SkillParam(
            name: 'topic',
            type: 'string',
            description: 'Topic for the outline',
            required: true,
          ),
        },
        isBuiltin: true,
      ),
      Skill(
        id: 'auto-tag',
        name: 'Auto Tag',
        description: 'Automatically suggest tags for the current note',
        prompt:
            'Analyze the following note and suggest relevant tags. Return only the tags as a comma-separated list:\n\n@note[current]',
        isBuiltin: true,
      ),
      Skill(
        id: 'daily-review',
        name: 'Daily Review',
        description: 'Generate a daily review summary',
        prompt:
            'Review today\'s daily note and generate a summary of accomplishments and pending tasks:\n\n@note[daily]',
        isBuiltin: true,
      ),
    ];
  }
}

final skillServiceProvider = Provider<SkillService?>((ref) {
  final vaultState = ref.watch(vaultProvider);
  if (vaultState.currentVault == null) return null;
  return SkillService(vaultState.currentVault!.path);
});

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../data/stores/vault_store.dart';

class Template {
  final String name;
  final String content;
  final String? description;

  Template({required this.name, required this.content, this.description});
}

class TemplateService {
  final String vaultPath;

  TemplateService(this.vaultPath);

  Future<List<Template>> getTemplates() async {
    final templates = <Template>[];
    final builtinTemplates = _getBuiltinTemplates();
    templates.addAll(builtinTemplates);

    final templateDir = Directory(p.join(vaultPath, '.rfbrowser', 'templates'));
    if (await templateDir.exists()) {
      await for (final entity in templateDir.list()) {
        if (entity is File && entity.path.endsWith('.md')) {
          final name = p.basenameWithoutExtension(entity.path);
          final content = await entity.readAsString();
          templates.add(Template(name: name, content: content));
        }
      }
    }
    return templates;
  }

  Future<void> createTemplate(String name, String content) async {
    final templateDir = Directory(p.join(vaultPath, '.rfbrowser', 'templates'));
    if (!await templateDir.exists()) {
      await templateDir.create(recursive: true);
    }
    final file = File(p.join(templateDir.path, '$name.md'));
    await file.writeAsString(content);
  }

  Future<void> deleteTemplate(String name) async {
    final file = File(p.join(vaultPath, '.rfbrowser', 'templates', '$name.md'));
    if (await file.exists()) {
      await file.delete();
    }
  }

  String applyTemplate(String templateContent, Map<String, String> variables) {
    var result = templateContent;
    variables.forEach((key, value) {
      result = result.replaceAll('{{{$key}}}', value);
    });
    result = result.replaceAll(
      '{{date}}',
      DateTime.now().toIso8601String().substring(0, 10),
    );
    result = result.replaceAll(
      '{{time}}',
      DateTime.now().toIso8601String().substring(11, 19),
    );
    result = result.replaceAll(
      '{{timestamp}}',
      DateTime.now().toIso8601String(),
    );
    return result;
  }

  List<Template> _getBuiltinTemplates() {
    return [
      Template(
        name: 'Empty Note',
        content: '# {{{title}}}\n\n',
        description: 'A blank note with just a title',
      ),
      Template(
        name: 'Daily Note',
        content: '# {{{date}}}\n\n## Tasks\n\n- [ ] \n\n## Notes\n\n',
        description: 'Daily note with task list',
      ),
      Template(
        name: 'Meeting Notes',
        content:
            '# {{{title}}}\n\n**Date:** {{{date}}}\n**Attendees:** \n\n## Agenda\n\n1. \n\n## Notes\n\n\n## Action Items\n\n- [ ] \n',
        description: 'Meeting notes template',
      ),
      Template(
        name: 'Research Note',
        content:
            '# {{{title}}}\n\n**Source:** \n**Date:** {{{date}}}\n\n## Summary\n\n\n## Key Points\n\n1. \n\n## Questions\n\n- \n\n## Connections\n\n- [[]]\n',
        description: 'Research note with source tracking',
      ),
      Template(
        name: 'Web Clip',
        content:
            '# {{{title}}}\n\n> **Source:** [{{{title}}}]({{{url}}})\n> **Captured:** {{{date}}}\n\n## Content\n\n',
        description: 'Web clipping template',
      ),
    ];
  }
}

final templateServiceProvider = Provider<TemplateService?>((ref) {
  final vaultState = ref.watch(vaultProvider);
  if (vaultState.currentVault == null) return null;
  return TemplateService(vaultState.currentVault!.path);
});

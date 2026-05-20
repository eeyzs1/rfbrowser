import 'package:flutter/material.dart';
import '../builtin_plugin.dart';
import '../../host/plugin_host.dart';
import '../../../data/models/skill.dart';

class HelloWorldPlugin extends BuiltinPlugin {
  @override
  PluginManifest get manifest => PluginManifest(
        id: 'hello-world',
        name: 'Hello World',
        version: '1.0.0',
        author: 'RFBrowser Team',
        description: 'A test plugin that demonstrates the plugin system',
        permissions: [
          Permission.knowledgeRead,
          Permission.knowledgeWrite,
          Permission.browserRead,
          Permission.uiCommand,
          Permission.uiPanel,
        ],
      );

  @override
  List<PluginCommand> get commands => [
        PluginCommand(
          id: 'hello-world.greet',
          label: 'Say Hello',
          pluginId: 'hello-world',
        ),
        PluginCommand(
          id: 'hello-world.count-notes',
          label: 'Count Notes',
          pluginId: 'hello-world',
        ),
        PluginCommand(
          id: 'hello-world.show-panel',
          label: 'Show Hello Panel',
          pluginId: 'hello-world',
        ),
      ];

  @override
  List<Skill> get skills => [
        Skill(
          id: 'hello-world.greeting',
          name: 'Greeting Generator',
          description: 'Generate a friendly greeting message',
          prompt:
              'Generate a warm and friendly greeting message. The tone should be: {{tone}}. The recipient is: {{recipient}}.',
          params: {
            'tone': SkillParam(
              name: 'tone',
              type: 'string',
              description: 'Tone of the greeting (casual, formal, enthusiastic)',
              defaultValue: 'casual',
            ),
            'recipient': SkillParam(
              name: 'recipient',
              type: 'string',
              description: 'Who the greeting is for',
              required: true,
            ),
          },
          pluginId: 'hello-world',
        ),
        Skill(
          id: 'hello-world.note-stats',
          name: 'Note Statistics',
          description: 'Generate statistics about your notes',
          prompt:
              'Analyze the following notes and provide statistics. Focus on: {{focus}}.\n\n@note[current]',
          params: {
            'focus': SkillParam(
              name: 'focus',
              type: 'string',
              description: 'What aspect to focus on (tags, topics, length)',
              defaultValue: 'tags',
            ),
          },
          pluginId: 'hello-world',
        ),
      ];

  @override
  Future<void> onEnable(PluginHostNotifier host) async {
    for (final cmd in commands) {
      host.registerCommand(cmd);
    }
  }

  @override
  Future<void> onDisable(PluginHostNotifier host) async {}

  @override
  Widget? buildPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello World Plugin',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This plugin demonstrates the RFBrowser plugin system.\n\n'
            'Features:\n'
            '- Plugin manifest with permissions\n'
            '- Command registration\n'
            '- API calls through sandbox\n'
            '- UI panel rendering',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.waving_hand),
            label: const Text('Hello!'),
          ),
        ],
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> handleApiCall(
    String apiName,
    Map<String, dynamic> args,
  ) async {
    switch (apiName) {
      case 'hello-world.greet':
        final name = args['name'] as String? ?? 'World';
        return {'message': 'Hello, $name!', 'timestamp': DateTime.now().toIso8601String()};
      case 'hello-world.count-notes':
        final count = args['count'] as int? ?? 0;
        return {'count': count, 'message': 'Found $count notes in vault'};
      default:
      throw UnimplementedError('HelloWorldPlugin: unknown API: $apiName');
    }
  }

  @override
  List<PluginHook> get hooks => [
    PluginHook(event: 'note.opened', handler: 'onNoteOpened'),
    PluginHook(event: 'note.saved', handler: 'onNoteSaved'),
  ];

  @override
  Future<void> onHookEvent(String event, Map<String, dynamic> data) async {
    debugPrint('HelloWorldPlugin: hook event=$event data=$data');
  }
}
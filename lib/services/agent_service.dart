import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/agent_task.dart';
import 'ai_service.dart';

class AgentService {
  final AINotifier _aiNotifier;

  AgentService(this._aiNotifier);

  Future<AgentTask> research(String topic, {int depth = 3}) async {
    final task = AgentTask(
      id: 'research-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Research: $topic',
      description: 'Deep research on $topic',
      steps: [
        AgentStep(description: 'Searching for information about $topic'),
        AgentStep(description: 'Analyzing and synthesizing findings'),
        AgentStep(description: 'Creating summary note'),
      ],
    );

    final prompt =
        '''You are a research assistant. Conduct a thorough research on the following topic:

Topic: $topic
Depth: $depth levels

Please provide:
1. A comprehensive overview
2. Key findings and insights
3. Related topics for further exploration
4. Sources and references

Format your response in Markdown.''';

    await _aiNotifier.sendMessage(
      prompt,
      systemPrompt:
          'You are a research assistant specialized in deep analysis and synthesis.',
    );
    return task;
  }

  Future<AgentTask> summarizeUrls(List<String> urls) async {
    final task = AgentTask(
      id: 'summarize-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Summarize URLs',
      description: 'Summarize ${urls.length} URLs',
      steps: urls
          .map((url) => AgentStep(description: 'Summarizing: $url'))
          .toList(),
    );

    final prompt =
        'Please summarize the key points from the following URLs:\n\n${urls.map((u) => '- $u').join('\n')}';
    await _aiNotifier.sendMessage(
      prompt,
      systemPrompt: 'You are a content summarization assistant.',
    );
    return task;
  }

  Future<AgentTask> extractDataFromWeb(String url, String schema) async {
    final task = AgentTask(
      id: 'extract-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Extract Data',
      description: 'Extract data from $url',
      steps: [
        AgentStep(description: 'Loading page: $url'),
        AgentStep(description: 'Extracting data using schema: $schema'),
      ],
    );

    final prompt =
        'Extract the following data from this URL: $url\n\nSchema: $schema';
    await _aiNotifier.sendMessage(
      prompt,
      systemPrompt: 'You are a data extraction assistant.',
    );
    return task;
  }

  Future<AgentTask> autoOrganize(List<String> noteTitles) async {
    final task = AgentTask(
      id: 'organize-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Auto Organize',
      description: 'Automatically organize notes',
      steps: [
        AgentStep(description: 'Analyzing note structure'),
        AgentStep(description: 'Suggesting tags and links'),
        AgentStep(description: 'Creating organization plan'),
      ],
    );

    final prompt = '''Analyze the following notes and suggest:
1. Tags for each note
2. Links between related notes
3. Folder organization

Notes:
${noteTitles.map((t) => '- $t').join('\n')}''';

    await _aiNotifier.sendMessage(
      prompt,
      systemPrompt: 'You are a knowledge organization assistant.',
    );
    return task;
  }
}

final agentServiceProvider = Provider<AgentService>((ref) {
  final aiNotifier = ref.watch(aiProvider.notifier);
  return AgentService(aiNotifier);
});

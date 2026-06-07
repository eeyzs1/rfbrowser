import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/agent_task.dart';
import '../data/models/note.dart';
import '../data/stores/index_store.dart';
import '../platform/webview/headless_manager.dart';
import '../services/ai_service.dart';
import '../services/knowledge_service.dart';
import 'agent/agent_tool.dart';
import 'agent/agent_tool_registry.dart';
import 'agent/agent_persistence.dart';
import 'agent/builtin_tools.dart';
import 'agent/task_execution_strategy.dart';

class AgentState {
  final List<AgentTask> tasks;
  final HeadlessManager headlessManager;
  final AgentToolRegistry toolRegistry;

  AgentState({
    this.tasks = const [],
    HeadlessManager? headlessManager,
    AgentToolRegistry? toolRegistry,
  }) : headlessManager = headlessManager ?? HeadlessManager(),
       toolRegistry = toolRegistry ?? AgentToolRegistry();

  AgentState copyWith({List<AgentTask>? tasks}) {
    return AgentState(
      tasks: tasks ?? this.tasks,
      headlessManager: headlessManager,
      toolRegistry: toolRegistry,
    );
  }
}

class AgentNotifier extends Notifier<AgentState> {
  static const int defaultReactIterations = 20;
  final AgentPersistence _persistence = AgentPersistence();

  @override
  AgentState build() {
    final agentState = AgentState();
    _registerBuiltinTools(agentState.toolRegistry);
    _loadPersistedTasks();
    return agentState;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _loadPersistedTasks() async {
    final tasks = await _persistence.loadTasks();
    if (tasks.isNotEmpty) {
      final updatedTasks = tasks.map((t) {
        if (t.status == TaskStatus.running || t.status == TaskStatus.paused) {
          return t.copyWith(
            status: TaskStatus.failed,
            result: 'Interrupted by app restart',
          );
        }
        return t;
      }).toList();
      state = state.copyWith(tasks: updatedTasks);
    }
  }

  Future<void> _persistTasks() async {
    await _persistence.saveTasks(state.tasks);
  }

  // ---------------------------------------------------------------------------
  // Tool registration
  // ---------------------------------------------------------------------------

  void _registerBuiltinTools(AgentToolRegistry registry) {
    registry.register(
      NavigateTool((url) async {
        final webView = state.headlessManager.create();
        await webView.run();
        await webView.loadUrl(url);
        return 'Navigated to $url';
      }),
    );

    registry.register(
      ExtractTextTool((url) async {
        final webView = state.headlessManager.create();
        await webView.run();
        await webView.loadUrl(url);
        final text = await webView.extractText();
        return text;
      }),
    );

    registry.register(
      CreateNoteTool((title, content) async {
        try {
          final note = await ref
              .read(knowledgeProvider.notifier)
              .createNote(title: title);
          ref.read(knowledgeProvider.notifier).updateActiveNoteContent(content);
          await ref.read(knowledgeProvider.notifier).saveActiveNote();
          return 'Note created: $title (${note.filePath})';
        } catch (e) {
          return 'Failed to create note "$title": $e';
        }
      }),
    );

    registry.register(
      SearchNotesTool((query) async {
        final indexStore = ref.read(indexStoreProvider);
        return await indexStore.searchNotes(query);
      }),
    );

    registry.register(
      AIReasonTool((prompt, systemPrompt) async {
        final aiNotifier = ref.read(aiProvider.notifier);
        await aiNotifier.sendMessage(prompt, systemPrompt: systemPrompt);
        final messages = ref.read(aiProvider).messages;
        final lastAssistant = messages.lastWhere(
          (m) => m.role == 'assistant' && !m.isStreaming,
          orElse: () => ChatMessage(role: 'assistant', content: ''),
        );
        return lastAssistant.content;
      }),
    );

    registry.register(
      WebClipTool((url, format) async {
        try {
          final title = Uri.parse(url).host;
          final knowledge = ref.read(knowledgeProvider.notifier);
          await knowledge.createNote(title: 'Clip: $title');
          knowledge.updateActiveNoteContent(
            'Source: $url\n\nClipped from $url in $format format.',
          );
          await knowledge.saveActiveNote();
          return 'Clipped $url as $format';
        } catch (e) {
          return 'Clip failed: $e';
        }
      }),
    );

    registry.register(
      DeleteNoteTool((title) async {
        try {
          final knowledge = ref.read(knowledgeProvider.notifier);
          final notes = knowledge.state.notes;
          final note = notes.where((n) => n.title == title).firstOrNull;
          if (note == null) return false;
          await knowledge.deleteNote(note.id);
          return true;
        } catch (e) {
          return false;
        }
      }),
    );

    registry.register(
      UpdateNoteTool((title, content) async {
        final knowledge = ref.read(knowledgeProvider.notifier);
        final note = knowledge.state.notes
            .where((n) => n.title == title)
            .firstOrNull;
        if (note == null) return 'Note "$title" not found';
        knowledge.updateActiveNoteContent(content);
        await knowledge.saveActiveNote();
        return 'Note "$title" updated';
      }),
    );

    registry.register(
      ListNotesTool((tag, limit) async {
        final knowledge = ref.read(knowledgeProvider.notifier);
        List<Note> notes;
        if (tag != null && tag.isNotEmpty) {
          notes = knowledge.getNotesByTag(tag);
        } else {
          notes = knowledge.state.notes;
        }
        final result = notes
            .take(limit)
            .map((n) => '- ${n.title} (${n.filePath})')
            .join('\n');
        return 'Found ${notes.length} notes:\n$result';
      }),
    );

    registry.register(
      GetTagsTool(() async {
        final knowledge = ref.read(knowledgeProvider.notifier);
        final tags = knowledge.getAllTags();
        return 'Tags: ${tags.join(", ")}';
      }),
    );

    registry.register(
      MoveNoteTool((title, folder) async {
        final knowledge = ref.read(knowledgeProvider.notifier);
        final note = knowledge.state.notes
            .where((n) => n.title == title)
            .firstOrNull;
        if (note == null) return 'Note "$title" not found';
        await knowledge.moveNote(note.id, folder);
        return 'Note "$title" moved to $folder';
      }),
    );

    registry.register(
      RenameNoteTool((oldTitle, newTitle) async {
        final knowledge = ref.read(knowledgeProvider.notifier);
        final note = knowledge.state.notes
            .where((n) => n.title == oldTitle)
            .firstOrNull;
        if (note == null) return 'Note "$oldTitle" not found';
        await knowledge.renameNote(note.filePath, newTitle);
        return 'Note renamed from "$oldTitle" to "$newTitle"';
      }),
    );
  }

  void registerPluginTool(AgentTool tool) {
    state.toolRegistry.register(tool);
  }

  void unregisterPluginTool(String name) {
    state.toolRegistry.unregister(name);
  }

  AgentToolRegistry get toolRegistry => state.toolRegistry;

  // ---------------------------------------------------------------------------
  // Task lookup & state helpers
  // ---------------------------------------------------------------------------

  AgentTask? getTask(String id) {
    return state.tasks.where((t) => t.id == id).firstOrNull;
  }

  void _updateTask(AgentTask updated) {
    state = state.copyWith(
      tasks: state.tasks.map((t) => t.id == updated.id ? updated : t).toList(),
    );
    _persistTasks();
  }

  // ---------------------------------------------------------------------------
  // Task execution — delegates to the appropriate strategy
  // ---------------------------------------------------------------------------

  Future<AgentTask> executeTask(AgentTask task) async {
    if (state.tasks.any((t) => t.id == task.id)) {
      return task;
    }

    var current = task.copyWith(status: TaskStatus.running);
    state = state.copyWith(tasks: [...state.tasks, current]);
    _persistTasks();

    final context = ExecutionContext(
      toolRegistry: state.toolRegistry,
      onUpdateTask: _updateTask,
      ref: ref,
    );

    final strategy = ExecutionStrategyFactory.createStrategy(
      current.mode,
      context,
    );

    return await strategy.execute(current);
  }

  // ---------------------------------------------------------------------------
  // Task lifecycle controls
  // ---------------------------------------------------------------------------

  void pauseTask(String id) {
    final task = getTask(id);
    if (task == null || task.status != TaskStatus.running) return;
    _updateTask(task.copyWith(status: TaskStatus.paused));
  }

  void cancelTask(String id) {
    final task = getTask(id);
    if (task == null) return;
    state.headlessManager.disposeAll();
    _updateTask(task.copyWith(status: TaskStatus.failed, result: 'cancelled'));
  }

  void resumeTask(String id) {
    final task = getTask(id);
    if (task == null || task.status != TaskStatus.paused) return;
    _updateTask(task.copyWith(status: TaskStatus.running));
  }

  void removeTask(String id) {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );
    _persistTasks();
  }

  // ---------------------------------------------------------------------------
  // Convenience task builders
  // ---------------------------------------------------------------------------

  Future<AgentTask> research(String topic, {int depth = 3}) async {
    final task = AgentTask(
      id: 'research-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Research: $topic',
      description:
          'Research the topic: $topic. Search for information, analyze findings, and create a summary note.',
      mode: TaskMode.reactLoop,
      maxIterations: depth * 5,
    );
    return executeTask(task);
  }

  Future<AgentTask> summarizeUrls(List<String> urls) async {
    final steps = <AgentStep>[];
    for (final url in urls) {
      steps.add(
        AgentStep(
          description: 'Extract text from $url',
          toolName: 'extract_text',
          args: {'url': url},
        ),
      );
    }
    steps.add(
      AgentStep(
        description: 'Summarize extracted content',
        toolName: 'ai_reason',
        args: {
          'prompt':
              'Summarize the following content:\n\n{{step_${steps.length - 1}}}',
          'system_prompt':
              'You are a helpful assistant that creates concise summaries.',
        },
      ),
    );

    final task = AgentTask(
      id: 'summarize-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Summarize URLs',
      description: 'Summarize ${urls.length} URLs',
      mode: TaskMode.manual,
      steps: steps,
    );
    return executeTask(task);
  }

  Future<AgentTask> extractDataFromWeb(String url, String schema) async {
    final task = AgentTask(
      id: 'extract-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Extract Data',
      description: 'Extract data from $url',
      mode: TaskMode.manual,
      steps: [
        AgentStep(
          description: 'Navigate to $url',
          toolName: 'navigate',
          args: {'url': url},
        ),
        AgentStep(
          description: 'Extract text from $url',
          toolName: 'extract_text',
          args: {'url': url},
        ),
        AgentStep(
          description: 'Extract data using schema: $schema',
          toolName: 'ai_reason',
          args: {
            'prompt':
                'Extract data from the following content using this schema: $schema\n\nContent:\n{{step_1}}',
            'system_prompt':
                'You are a data extraction assistant. Output structured data matching the given schema.',
          },
        ),
      ],
    );
    return executeTask(task);
  }

  Future<AgentTask> autoOrganize(List<String> noteTitles) async {
    final task = AgentTask(
      id: 'organize-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Auto Organize',
      description:
          'Analyze these notes and suggest tags, links, and organization: ${noteTitles.join(", ")}',
      mode: TaskMode.aiPlanned,
    );
    return executeTask(task);
  }

  Future<AgentTask> aiPlanAndExecute(
    String goal, {
    TaskMode mode = TaskMode.aiPlanned,
  }) async {
    final task = AgentTask(
      id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
      name: goal,
      description: goal,
      mode: mode,
    );
    return executeTask(task);
  }
}

final agentProvider = NotifierProvider<AgentNotifier, AgentState>(
  AgentNotifier.new,
);
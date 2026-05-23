import 'dart:async';
import 'package:flutter/foundation.dart';
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
import 'agent/plan_generator.dart';

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
  static const int maxSteps = 50;
  static const Duration maxDuration = Duration(minutes: 30);
  static const int defaultReactIterations = 20;
  final AgentPersistence _persistence = AgentPersistence();

  @override
  AgentState build() {
    final agentState = AgentState();
    _registerBuiltinTools(agentState.toolRegistry);
    _loadPersistedTasks();
    return agentState;
  }

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

  AgentTask? getTask(String id) {
    return state.tasks.where((t) => t.id == id).firstOrNull;
  }

  void _updateTask(AgentTask updated) {
    state = state.copyWith(
      tasks: state.tasks.map((t) => t.id == updated.id ? updated : t).toList(),
    );
    _persistTasks();
  }

  Future<AgentTask> executeTask(AgentTask task) async {
    if (state.tasks.any((t) => t.id == task.id)) {
      return task;
    }

    var current = task.copyWith(status: TaskStatus.running);
    state = state.copyWith(tasks: [...state.tasks, current]);
    _persistTasks();

    switch (task.mode) {
      case TaskMode.manual:
        return await _executeManualTask(current);
      case TaskMode.aiPlanned:
        return await _executeAiPlannedTask(current);
      case TaskMode.reactLoop:
        return await _executeReactTask(current);
    }
  }

  Future<AgentTask> _executeManualTask(AgentTask current) async {
    final stopwatch = Stopwatch()..start();
    final stepResults = <String>[];

    for (var i = 0; i < current.steps.length; i++) {
      if (current.status == TaskStatus.paused) break;
      if (current.status == TaskStatus.failed) break;

      if (i >= maxSteps) {
        current = current.copyWith(
          status: TaskStatus.failed,
          result: 'step_limit_exceeded',
        );
        _updateTask(current);
        break;
      }

      if (stopwatch.elapsed > maxDuration) {
        current = current.copyWith(
          status: TaskStatus.failed,
          result: 'time_limit_exceeded',
        );
        _updateTask(current);
        break;
      }

      final step = current.steps[i];

      if (step.condition != null &&
          !_evaluateCondition(step.condition!, stepResults)) {
        final skippedSteps = List<AgentStep>.from(current.steps);
        skippedSteps[i] = skippedSteps[i].copyWith(
          status: TaskStatus.completed,
          result: 'Skipped: condition not met',
        );
        current = current.copyWith(steps: skippedSteps);
        _updateTask(current);
        stepResults.add('Skipped');
        continue;
      }

      final updatedSteps = List<AgentStep>.from(current.steps);
      updatedSteps[i] = updatedSteps[i].copyWith(status: TaskStatus.running);
      current = current.copyWith(steps: updatedSteps);
      _updateTask(current);

      final result = await _executeStepWithRetry(current.steps[i], stepResults);

      if (result.success) {
        stepResults.add(result.output);
        final completedSteps = List<AgentStep>.from(current.steps);
        completedSteps[i] = completedSteps[i].copyWith(
          status: TaskStatus.completed,
          result: result.output,
          completedAt: DateTime.now(),
        );
        current = current.copyWith(steps: completedSteps);
        _updateTask(current);
      } else {
        final onFailure = current.steps[i].onFailure ?? 'abort';
        if (onFailure == 'skip') {
          stepResults.add('Error (skipped): ${result.error}');
          final skippedSteps = List<AgentStep>.from(current.steps);
          skippedSteps[i] = skippedSteps[i].copyWith(
            status: TaskStatus.completed,
            result: 'Error (skipped): ${result.error}',
            completedAt: DateTime.now(),
          );
          current = current.copyWith(steps: skippedSteps);
          _updateTask(current);
        } else {
          final failedSteps = List<AgentStep>.from(current.steps);
          failedSteps[i] = failedSteps[i].copyWith(
            status: TaskStatus.failed,
            result: result.error,
          );
          current = current.copyWith(
            steps: failedSteps,
            status: TaskStatus.failed,
            result: result.error,
          );
          _updateTask(current);
          break;
        }
      }
    }

    if (current.status == TaskStatus.running) {
      current = current.copyWith(
        status: TaskStatus.completed,
        completed: DateTime.now(),
        result: stepResults.join('\n\n'),
      );
      _updateTask(current);
    }

    return current;
  }

  Future<AgentTask> _executeAiPlannedTask(AgentTask current) async {
    final planGenerator = PlanGenerator(state.toolRegistry);
    final aiNotifier = ref.read(aiProvider.notifier);

    final systemPrompt = planGenerator.buildSystemPrompt();
    final userMessage = current.description;

    await aiNotifier.sendMessage(userMessage, systemPrompt: systemPrompt);

    final messages = ref.read(aiProvider).messages;
    final lastResponse = messages.lastWhere(
      (m) => m.role == 'assistant' && !m.isStreaming,
      orElse: () => ChatMessage(role: 'assistant', content: ''),
    );

    final planSteps = planGenerator.parsePlan(lastResponse.content);

    if (planSteps.isEmpty) {
      current = current.copyWith(
        status: TaskStatus.failed,
        result: 'AI failed to generate a valid plan',
      );
      _updateTask(current);
      return current;
    }

    final steps = planSteps
        .map(
          (ps) => AgentStep(
            description: ps.description ?? 'Use ${ps.toolName}',
            toolName: ps.toolName,
            args: ps.args,
            condition: ps.condition,
            retryCount: ps.retryCount,
            onFailure: ps.onFailure,
          ),
        )
        .toList();

    current = current.copyWith(steps: steps);
    _updateTask(current);

    return await _executeManualTask(current);
  }

  Future<AgentTask> _executeReactTask(AgentTask current) async {
    final planGenerator = PlanGenerator(state.toolRegistry);
    final aiNotifier = ref.read(aiProvider.notifier);
    final systemPrompt = planGenerator.buildReactSystemPrompt();

    final stopwatch = Stopwatch()..start();
    final stepResults = <String>[];
    final dynamicSteps = <AgentStep>[];
    var iteration = 0;
    final maxIter = current.maxIterations.clamp(1, maxSteps);

    current = current.copyWith(status: TaskStatus.running);
    _updateTask(current);

    while (iteration < maxIter) {
      if (current.status == TaskStatus.paused) break;
      if (current.status == TaskStatus.failed) break;

      if (stopwatch.elapsed > maxDuration) {
        current = current.copyWith(
          status: TaskStatus.failed,
          result: 'time_limit_exceeded',
        );
        _updateTask(current);
        break;
      }

      final observation = planGenerator.buildReactObservation(
        current.description,
        stepResults,
        iteration,
        maxIter,
      );

      await aiNotifier.sendMessage(observation, systemPrompt: systemPrompt);

      final messages = ref.read(aiProvider).messages;
      final lastResponse = messages.lastWhere(
        (m) => m.role == 'assistant' && !m.isStreaming,
        orElse: () => ChatMessage(role: 'assistant', content: ''),
      );

      final reactAction = planGenerator.parseReactResponse(
        lastResponse.content,
      );
      if (reactAction == null) {
        iteration++;
        stepResults.add('Failed to parse AI response, retrying...');
        continue;
      }

      final isDone = reactAction['done'] == true;
      final toolName = reactAction['tool'] as String? ?? '';
      final args = (reactAction['args'] as Map<String, dynamic>?) ?? {};
      final thought = reactAction['thought'] as String? ?? '';

      if (isDone || toolName == 'final_answer') {
        final answer = args['answer'] as String? ?? stepResults.join('\n');
        dynamicSteps.add(
          AgentStep(
            description: thought.isNotEmpty ? thought : 'Final answer',
            toolName: 'final_answer',
            args: args,
            status: TaskStatus.completed,
            result: answer,
            completedAt: DateTime.now(),
          ),
        );
        current = current.copyWith(
          steps: dynamicSteps,
          status: TaskStatus.completed,
          completed: DateTime.now(),
          result: answer,
        );
        _updateTask(current);
        return current;
      }

      if (!state.toolRegistry.hasTool(toolName)) {
        stepResults.add(
          'Unknown tool: $toolName. Available: ${state.toolRegistry.tools.keys.join(", ")}',
        );
        iteration++;
        continue;
      }

      final step = AgentStep(
        description: thought.isNotEmpty ? thought : 'Use $toolName',
        toolName: toolName,
        args: args,
      );

      final updatedSteps = List<AgentStep>.from(dynamicSteps)
        ..add(step.copyWith(status: TaskStatus.running));
      current = current.copyWith(steps: updatedSteps);
      _updateTask(current);

      final result = await _executeStepWithRetry(step, stepResults);

      if (result.success) {
        stepResults.add(result.output);
        dynamicSteps.add(
          step.copyWith(
            status: TaskStatus.completed,
            result: result.output,
            completedAt: DateTime.now(),
          ),
        );
      } else {
        stepResults.add('Error: ${result.error}');
        dynamicSteps.add(
          step.copyWith(status: TaskStatus.failed, result: result.error),
        );
      }

      current = current.copyWith(steps: dynamicSteps);
      _updateTask(current);
      iteration++;
    }

    if (current.status == TaskStatus.running) {
      current = current.copyWith(
        status: TaskStatus.completed,
        completed: DateTime.now(),
        result: stepResults.join('\n\n'),
      );
      _updateTask(current);
    }

    return current;
  }

  Future<ToolResult> _executeStepWithRetry(
    AgentStep step,
    List<String> previousResults,
  ) async {
    final toolName = step.toolName;
    if (toolName == null || toolName.isEmpty) {
      return _executeLegacyStep(step, previousResults);
    }

    final planGenerator = PlanGenerator(state.toolRegistry);
    final resolvedJson = planGenerator.resolveStepReferences(
      step.args,
      previousResults,
    );
    final resolvedArgs = planGenerator.parseResolvedArgs(resolvedJson);

    final tool = state.toolRegistry.getTool(toolName);
    if (tool == null) {
      return ToolResult.failure('Unknown tool: $toolName');
    }

    var lastResult = ToolResult.failure('not executed');
    for (var attempt = 0; attempt <= step.retryCount; attempt++) {
      try {
        final result = await state.toolRegistry.execute(toolName, resolvedArgs);
        if (result.success) return result;
        lastResult = result;
        if (attempt < step.retryCount) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      } catch (e) {
        lastResult = ToolResult.failure(e.toString());
        if (attempt < step.retryCount) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }

    return lastResult;
  }

  Future<ToolResult> _executeLegacyStep(
    AgentStep step,
    List<String> previousResults,
  ) async {
    final desc = step.description;

    if (desc.startsWith('Navigate to:')) {
      final url = desc.replaceFirst('Navigate to:', '').trim();
      return state.toolRegistry.execute('navigate', {'url': url});
    }

    if (desc.startsWith('Extract text from:')) {
      final url = desc.replaceFirst('Extract text from:', '').trim();
      return state.toolRegistry.execute('extract_text', {'url': url});
    }

    if (desc.startsWith('Create note:')) {
      final title = desc.replaceFirst('Create note:', '').trim();
      final content = previousResults.isNotEmpty
          ? '## Context\n\n${previousResults.join('\n\n')}'
          : '';
      return state.toolRegistry.execute('create_note', {
        'title': title,
        'content': content,
      });
    }

    if (desc.startsWith('Summarize extracted content')) {
      if (previousResults.isEmpty) {
        return ToolResult.failure('No content to summarize');
      }
      return state.toolRegistry.execute('ai_reason', {
        'prompt':
            'Summarize the following content:\n\n${previousResults.join('\n\n')}',
        'system_prompt':
            'You are a helpful assistant that creates concise summaries.',
      });
    }

    if (desc.startsWith('Extract data using schema:')) {
      final schema = desc.replaceFirst('Extract data using schema:', '').trim();
      if (previousResults.isEmpty) {
        return ToolResult.failure('No content to extract data from');
      }
      return state.toolRegistry.execute('ai_reason', {
        'prompt':
            'Extract data from the following content using this schema: $schema\n\nContent:\n${previousResults.last}',
        'system_prompt':
            'You are a data extraction assistant. Output structured data matching the given schema.',
      });
    }

    if (desc.contains('Searching') ||
        desc.contains('Analyzing') ||
        desc.contains('Suggesting') ||
        desc.contains('Creating organization')) {
      return state.toolRegistry.execute('ai_reason', {
        'prompt': desc,
        'system_prompt':
            'You are a knowledge management assistant. Help with the described task.',
      });
    }

    return ToolResult.success('Step completed: $desc');
  }

  bool _evaluateCondition(String condition, List<String> previousResults) {
    try {
      if (condition.startsWith('step_')) {
        final parts = condition.split('.');
        if (parts.length >= 2) {
          final indexStr = parts[0].replaceFirst('step_', '');
          final index = int.tryParse(indexStr);
          if (index != null && index < previousResults.length) {
            final result = previousResults[index];
            final check = condition.substring(parts[0].length + 1);
            if (check.startsWith('contains:')) {
              return result.contains(check.replaceFirst('contains:', ''));
            }
            if (check.startsWith('notEmpty')) {
              return result.isNotEmpty;
            }
            if (check.startsWith('success')) {
              return !result.startsWith('Error') &&
                  !result.startsWith('Failed');
            }
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('Condition evaluation error: $e');
      return true;
    }
  }

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

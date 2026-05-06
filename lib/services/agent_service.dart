import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/agent_task.dart';
import '../platform/webview/headless_manager.dart';
import 'knowledge_service.dart';

class AgentState {
  final List<AgentTask> tasks;
  final HeadlessManager headlessManager;

  AgentState({
    this.tasks = const [],
    HeadlessManager? headlessManager,
  }) : headlessManager = headlessManager ?? HeadlessManager();

  AgentState copyWith({List<AgentTask>? tasks}) {
    return AgentState(tasks: tasks ?? this.tasks, headlessManager: headlessManager);
  }
}

class AgentNotifier extends Notifier<AgentState> {
  static const int maxSteps = 50;
  static const Duration maxDuration = Duration(minutes: 30);

  @override
  AgentState build() => AgentState();

  AgentTask? getTask(String id) {
    return state.tasks.where((t) => t.id == id).firstOrNull;
  }

  void _updateTask(AgentTask updated) {
    state = state.copyWith(
      tasks: state.tasks.map((t) => t.id == updated.id ? updated : t).toList(),
    );
  }

  Future<AgentTask> executeTask(AgentTask task) async {
    if (state.tasks.any((t) => t.id == task.id)) {
      return task;
    }

    var current = task.copyWith(status: TaskStatus.running);
    state = state.copyWith(tasks: [...state.tasks, current]);

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

      final updatedSteps = List<AgentStep>.from(current.steps);
      updatedSteps[i] = updatedSteps[i].copyWith(status: TaskStatus.running);
      current = current.copyWith(steps: updatedSteps);
      _updateTask(current);

      try {
        final result = await _executeStep(current.steps[i], stepResults);
        stepResults.add(result);

        final completedSteps = List<AgentStep>.from(current.steps);
        completedSteps[i] = completedSteps[i].copyWith(
          status: TaskStatus.completed,
          result: result,
          completedAt: DateTime.now(),
        );
        current = current.copyWith(steps: completedSteps);
        _updateTask(current);
      } catch (e) {
        final failedSteps = List<AgentStep>.from(current.steps);
        failedSteps[i] = failedSteps[i].copyWith(
          status: TaskStatus.failed,
          result: e.toString(),
        );
        current = current.copyWith(
          steps: failedSteps,
          status: TaskStatus.failed,
          result: e.toString(),
        );
        _updateTask(current);
        break;
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

  Future<String> _executeStep(AgentStep step, List<String> previousResults) async {
    if (step.description.startsWith('Navigate to:')) {
      final url = step.description.replaceFirst('Navigate to:', '').trim();
      final webView = state.headlessManager.create();
      await webView.run();
      await webView.loadUrl(url);
      return 'Navigated to $url';
    }

    if (step.description.startsWith('Extract text from:')) {
      final url = step.description.replaceFirst('Extract text from:', '').trim();
      final webView = state.headlessManager.create();
      await webView.run();
      await webView.loadUrl(url);
      final text = await webView.extractText();
      return text;
    }

    if (step.description.startsWith('Create note:')) {
      final title = step.description.replaceFirst('Create note:', '').trim();
      final content = [
        '# $title',
        '',
        previousResults.isNotEmpty ? '## Context\n\n${previousResults.join('\n\n')}' : '',
      ].join('\n');
      try {
        final note = await ref.read(knowledgeProvider.notifier).createNote(
          title: title,
        );
        ref.read(knowledgeProvider.notifier).updateActiveNoteContent(content);
        await ref.read(knowledgeProvider.notifier).saveActiveNote();
        return 'Note created: $title (${note.filePath})';
      } catch (e) {
        return 'Failed to create note "$title": $e';
      }
    }

    return 'Step completed: ${step.description}';
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
    state = state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList());
  }

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
    return executeTask(task);
  }

  Future<AgentTask> summarizeUrls(List<String> urls) async {
    final steps = urls
        .map((url) => AgentStep(description: 'Extract text from: $url'))
        .toList();
    steps.add(AgentStep(description: 'Summarize extracted content'));

    final task = AgentTask(
      id: 'summarize-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Summarize URLs',
      description: 'Summarize ${urls.length} URLs',
      steps: steps,
    );
    return executeTask(task);
  }

  Future<AgentTask> extractDataFromWeb(String url, String schema) async {
    final task = AgentTask(
      id: 'extract-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Extract Data',
      description: 'Extract data from $url',
      steps: [
        AgentStep(description: 'Navigate to: $url'),
        AgentStep(description: 'Extract text from: $url'),
        AgentStep(description: 'Extract data using schema: $schema'),
      ],
    );
    return executeTask(task);
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
    return executeTask(task);
  }
}

final agentProvider = NotifierProvider<AgentNotifier, AgentState>(
  AgentNotifier.new,
);

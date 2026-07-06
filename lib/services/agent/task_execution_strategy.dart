import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging/app_logger.dart';
import '../../data/models/agent_task.dart';
import '../ai_service.dart';
import '../settings_service.dart';
import 'agent_tool.dart';
import 'agent_tool_registry.dart';
import 'plan_generator.dart';

part 'task_execution_react_strategy.dart';

/// Context passed to execution strategies, providing access to
/// shared infrastructure without coupling strategies to the notifier.
class ExecutionContext {
  final AgentToolRegistry toolRegistry;
  final void Function(AgentTask task) onUpdateTask;
  final Ref ref;

  const ExecutionContext({
    required this.toolRegistry,
    required this.onUpdateTask,
    required this.ref,
  });
}

/// Abstract base for all task execution strategies.
/// Provides common retry logic, step evaluation, and lifecycle helpers
/// shared by concrete strategies.
abstract class TaskExecutionStrategy {
  static const int maxSteps = 50;
  static const Duration maxDuration = Duration(minutes: 30);

  final ExecutionContext context;

  const TaskExecutionStrategy(this.context);

  Future<AgentTask> execute(AgentTask task);

  // ─── Step-level helpers ───────────────────────────────────────────

  /// Update a single step at [index] in [task] and notify listeners.
  AgentTask updateStep(
    AgentTask task,
    int index,
    AgentStep Function(AgentStep) update,
  ) {
    final steps = List<AgentStep>.from(task.steps);
    steps[index] = update(steps[index]);
    final updated = task.copyWith(steps: steps);
    context.onUpdateTask(updated);
    return updated;
  }

  /// Execute a single step with retry support.
  Future<ToolResult> executeStepWithRetry(
    AgentStep step,
    List<String> previousResults,
  ) async {
    final toolName = step.toolName;
    if (toolName == null || toolName.isEmpty) {
      return _executeLegacyStep(step, previousResults);
    }

    final planGenerator = PlanGenerator(context.toolRegistry);
    final resolvedJson = planGenerator.resolveStepReferences(
      step.args,
      previousResults,
    );
    final resolvedArgs = planGenerator.parseResolvedArgs(resolvedJson);

    final tool = context.toolRegistry.getTool(toolName);
    if (tool == null) {
      return ToolResult.failure('Unknown tool: $toolName');
    }

    var lastResult = ToolResult.failure('not executed');
    for (var attempt = 0; attempt <= step.retryCount; attempt++) {
      try {
        final result = await context.toolRegistry.execute(
          toolName,
          resolvedArgs,
        );
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

  /// Evaluate a step condition against previous results.
  bool evaluateCondition(String condition, List<String> previousResults) {
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
      appLog.error('Condition evaluation error', error: e);
      return true;
    }
  }

  // ─── Execution lifecycle helpers ──────────────────────────────────

  /// Check whether the task has been paused/failed, or exceeded step/time limits.
  /// Returns the updated task if execution should stop, null otherwise.
  AgentTask? checkStopConditions(
    AgentTask task,
    Stopwatch stopwatch,
    int currentStep,
    int maxSteps,
  ) {
    if (task.status == TaskStatus.paused || task.status == TaskStatus.failed) {
      return task;
    }
    if (currentStep >= maxSteps) {
      final updated = task.copyWith(
        status: TaskStatus.failed,
        result: 'step_limit_exceeded',
      );
      context.onUpdateTask(updated);
      return updated;
    }
    if (stopwatch.elapsed > maxDuration) {
      final updated = task.copyWith(
        status: TaskStatus.failed,
        result: 'time_limit_exceeded',
      );
      context.onUpdateTask(updated);
      return updated;
    }
    return null;
  }

  /// If the task is still running, mark it as completed and return the updated task.
  AgentTask finalizeIfRunning(AgentTask task, List<String> stepResults) {
    if (task.status == TaskStatus.running) {
      final updated = task.copyWith(
        status: TaskStatus.completed,
        completed: DateTime.now(),
        result: stepResults.join('\n\n'),
      );
      context.onUpdateTask(updated);
      return updated;
    }
    return task;
  }

  /// Get the last non-streaming assistant message from the AI provider.
  ChatMessage getLastAIResponse() {
    final messages = context.ref.read(aiProvider).messages;
    return messages.lastWhere(
      (m) => m.role == 'assistant' && !m.isStreaming,
      orElse: () => ChatMessage(role: 'assistant', content: ''),
    );
  }

  // ─── Internal ─────────────────────────────────────────────────────

  /// Handle legacy steps that use description-based tool dispatch.
  Future<ToolResult> _executeLegacyStep(
    AgentStep step,
    List<String> previousResults,
  ) async {
    final desc = step.description;

    if (desc.startsWith('Navigate to:')) {
      final url = desc.replaceFirst('Navigate to:', '').trim();
      return context.toolRegistry.execute('navigate', {'url': url});
    }

    if (desc.startsWith('Extract text from:')) {
      final url = desc.replaceFirst('Extract text from:', '').trim();
      return context.toolRegistry.execute('extract_text', {'url': url});
    }

    if (desc.startsWith('Create note:')) {
      final title = desc.replaceFirst('Create note:', '').trim();
      final content = previousResults.isNotEmpty
          ? '## Context\n\n${previousResults.join('\n\n')}'
          : '';
      return context.toolRegistry.execute('create_note', {
        'title': title,
        'content': content,
      });
    }

    if (desc.startsWith('Summarize extracted content')) {
      if (previousResults.isEmpty) {
        return ToolResult.failure('No content to summarize');
      }
      return context.toolRegistry.execute('ai_reason', {
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
      return context.toolRegistry.execute('ai_reason', {
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
      return context.toolRegistry.execute('ai_reason', {
        'prompt': desc,
        'system_prompt':
            'You are a knowledge management assistant. Help with the described task.',
      });
    }

    return ToolResult.success('Step completed: $desc');
  }
}

/// Executes tasks with pre-defined steps in sequential order,
/// with condition evaluation, retry, and failure handling.
class ManualExecutionStrategy extends TaskExecutionStrategy {
  const ManualExecutionStrategy(super.context);

  @override
  Future<AgentTask> execute(AgentTask task) async {
    var current = task;
    final stopwatch = Stopwatch()..start();
    final stepResults = <String>[];

    for (var i = 0; i < current.steps.length; i++) {
      final stopResult = checkStopConditions(
        current,
        stopwatch,
        i,
        TaskExecutionStrategy.maxSteps,
      );
      if (stopResult != null) return stopResult;

      final step = current.steps[i];

      if (step.condition != null &&
          !evaluateCondition(step.condition!, stepResults)) {
        current = updateStep(
          current,
          i,
          (s) => s.copyWith(
            status: TaskStatus.completed,
            result: 'Skipped: condition not met',
          ),
        );
        stepResults.add('Skipped');
        continue;
      }

      current = updateStep(
        current,
        i,
        (s) => s.copyWith(status: TaskStatus.running),
      );

      final result = await executeStepWithRetry(step, stepResults);

      if (result.success) {
        stepResults.add(result.output);
        current = updateStep(
          current,
          i,
          (s) => s.copyWith(
            status: TaskStatus.completed,
            result: result.output,
            completedAt: DateTime.now(),
          ),
        );
      } else {
        final onFailure = step.onFailure ?? 'abort';
        if (onFailure == 'skip') {
          stepResults.add('Error (skipped): ${result.error}');
          current = updateStep(
            current,
            i,
            (s) => s.copyWith(
              status: TaskStatus.completed,
              result: 'Error (skipped): ${result.error}',
              completedAt: DateTime.now(),
            ),
          );
        } else {
          current = updateStep(
            current,
            i,
            (s) => s.copyWith(status: TaskStatus.failed, result: result.error),
          );
          current = current.copyWith(
            status: TaskStatus.failed,
            result: result.error,
          );
          context.onUpdateTask(current);
          return current;
        }
      }
    }

    return finalizeIfRunning(current, stepResults);
  }
}

/// Uses AI to generate a plan from a natural language goal,
/// then executes the plan using the manual strategy.
class AIPlannedExecutionStrategy extends TaskExecutionStrategy {
  const AIPlannedExecutionStrategy(super.context);

  @override
  Future<AgentTask> execute(AgentTask task) async {
    var current = task;
    final planGenerator = PlanGenerator(context.toolRegistry);
    final aiNotifier = context.ref.read(aiProvider.notifier);

    final systemPrompt = planGenerator.buildSystemPrompt();
    await aiNotifier.sendMessage(
      current.description,
      systemPrompt: systemPrompt,
    );

    final lastResponse = getLastAIResponse();
    final planSteps = planGenerator.parsePlan(lastResponse.content);

    if (planSteps.isEmpty) {
      current = current.copyWith(
        status: TaskStatus.failed,
        result: 'AI failed to generate a valid plan',
      );
      context.onUpdateTask(current);
      return current;
    }

    current = current.copyWith(steps: planSteps);
    context.onUpdateTask(current);

    final manual = ManualExecutionStrategy(context);
    return await manual.execute(current);
  }
}

/// Creates the appropriate execution strategy for a given task mode.
class ExecutionStrategyFactory {
  static TaskExecutionStrategy createStrategy(
    TaskMode mode,
    ExecutionContext context,
  ) {
    switch (mode) {
      case TaskMode.manual:
        return ManualExecutionStrategy(context);
      case TaskMode.aiPlanned:
        return AIPlannedExecutionStrategy(context);
      case TaskMode.reactLoop:
        return ReactLoopExecutionStrategy(context);
    }
  }
}

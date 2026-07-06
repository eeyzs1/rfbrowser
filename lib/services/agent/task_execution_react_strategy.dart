part of 'task_execution_strategy.dart';

/// Iteratively observes, thinks, and acts using AI in a ReAct loop,
/// dynamically choosing tools until the task is complete.
class ReactLoopExecutionStrategy extends TaskExecutionStrategy {
  const ReactLoopExecutionStrategy(super.context);

  @override
  Future<AgentTask> execute(AgentTask task) async {
    var current = task;
    final planGenerator = PlanGenerator(context.toolRegistry);
    final aiNotifier = context.ref.read(aiProvider.notifier);
    final systemPrompt = planGenerator.buildReactSystemPrompt();

    final stopwatch = Stopwatch()..start();
    final stepResults = <String>[];
    final dynamicSteps = <AgentStep>[];
    var iteration = 0;
    // 用户可在 设置 → AI → 生成参数 中调整 ReAct 最大迭代数。
    // 仍然以 [TaskExecutionStrategy.maxSteps] 为硬上限,防止用户设置过高。
    final sampling = context.ref.read(settingsProvider).sampling;
    final userCap = sampling.maxReactIterations.clamp(
      1,
      TaskExecutionStrategy.maxSteps,
    );
    final maxIter = current.maxIterations.clamp(1, userCap);

    current = current.copyWith(status: TaskStatus.running);
    context.onUpdateTask(current);

    while (iteration < maxIter) {
      final stopResult = checkStopConditions(
        current,
        stopwatch,
        iteration,
        maxIter,
      );
      if (stopResult != null) return stopResult;

      final observation = planGenerator.buildReactObservation(
        current.description,
        stepResults,
        iteration,
        maxIter,
      );

      await aiNotifier.sendMessage(observation, systemPrompt: systemPrompt);

      final lastResponse = getLastAIResponse();
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
        context.onUpdateTask(current);
        return current;
      }

      if (!context.toolRegistry.hasTool(toolName)) {
        stepResults.add(
          'Unknown tool: $toolName. Available: ${context.toolRegistry.tools.keys.join(", ")}',
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
      context.onUpdateTask(current);

      final result = await executeStepWithRetry(step, stepResults);

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
      context.onUpdateTask(current);
      iteration++;
    }

    return finalizeIfRunning(current, stepResults);
  }
}

import 'dart:convert';
import '../../core/logging/app_logger.dart';
import '../../data/models/agent_task.dart';
import 'agent_tool_registry.dart';

class PlanGenerator {
  final AgentToolRegistry _registry;

  PlanGenerator(this._registry);

  String buildSystemPrompt() {
    final toolsDescription = _registry.toolsPrompt();
    return '''You are an AI agent task planner for RFBrowser, an AI-powered knowledge browser.
Your job is to break down user goals into a sequence of tool calls.

Available tools:
$toolsDescription

Rules:
1. Only use tools from the list above.
2. Each step must have a "tool" field matching an available tool name.
3. Each step must have an "args" object with the required parameters.
4. You may add an optional "description" field to explain what the step does.
5. For destructive tools (marked with ⚠️), add "confirm": true to the step.
6. If a step might fail, add "retryCount": N (max 3) and "onFailure": "skip" or "abort".
7. Steps can reference results from previous steps using {{step_N}} where N is the 0-based step index.
8. Keep plans concise — prefer fewer steps with richer tool usage.
9. Output ONLY valid JSON, no markdown fences or explanation text.

Output format:
{
  "steps": [
    {
      "tool": "tool_name",
      "args": {"param1": "value1", "param2": "{{step_0}}"},
      "description": "What this step does"
    }
  ]
}''';
  }

  String buildReactSystemPrompt() {
    final toolsDescription = _registry.toolsPrompt();
    return '''You are an AI agent executing tasks in RFBrowser. You work in a ReAct loop:
1. Observe the current state and previous results
2. Think about what to do next
3. Choose a tool and provide arguments
4. The tool result will be fed back to you

Available tools:
$toolsDescription

Rules:
1. Only use tools from the list above.
2. For destructive tools (marked with ⚠️), you MUST ask for user confirmation first.
3. Output ONLY valid JSON with your next action, no markdown fences or explanation.

Output format:
{
  "thought": "Your reasoning about what to do next",
  "tool": "tool_name",
  "args": {"param1": "value1"},
  "done": false
}

When you have completed the task and have a final answer, set "done": true and put the result in "tool": "final_answer", "args": {"answer": "your final answer"}.''';
  }

  List<AgentStep> parsePlan(String llmResponse) {
    final cleaned = _cleanJsonResponse(llmResponse);
    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final steps = json['steps'] as List<dynamic>? ?? [];
      return steps.map((s) {
        final step = s as Map<String, dynamic>;
        return AgentStep(
          description:
              step['description'] as String? ??
              'Use ${step['tool'] ?? 'unknown'}',
          toolName: step['tool'] as String? ?? '',
          args: (step['args'] as Map<String, dynamic>?) ?? {},
          condition: step['condition'] as String?,
          retryCount: step['retryCount'] as int? ?? 0,
          onFailure: step['onFailure'] as String?,
        );
      }).toList();
    } catch (e) {
      return _fallbackParse(cleaned);
    }
  }

  Map<String, dynamic>? parseReactResponse(String llmResponse) {
    final cleaned = _cleanJsonResponse(llmResponse);
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  String resolveStepReferences(
    Map<String, dynamic> args,
    List<String> previousResults,
  ) {
    final encoded = jsonEncode(args);
    var resolved = encoded;
    for (var i = 0; i < previousResults.length; i++) {
      resolved = resolved.replaceAll('{{step_$i}}', previousResults[i]);
    }
    return resolved;
  }

  Map<String, dynamic> parseResolvedArgs(String resolvedJson) {
    try {
      return jsonDecode(resolvedJson) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  String buildReactObservation(
    String userGoal,
    List<String> previousResults,
    int iteration,
    int maxIterations,
  ) {
    final history = <String>[];
    for (var i = 0; i < previousResults.length; i++) {
      history.add('Step $i result: ${_truncate(previousResults[i], 500)}');
    }
    return '''Goal: $userGoal

Iteration: $iteration / $maxIterations

Previous results:
${history.isEmpty ? '(none yet)' : history.join('\n')}

What should I do next?''';
  }

  List<AgentStep> _fallbackParse(String text) {
    final steps = <AgentStep>[];
    final toolPattern = RegExp(r'"tool"\s*:\s*"(\w+)"');
    final argsPattern = RegExp(r'"args"\s*:\s*(\{[^}]*\})');

    for (final match in toolPattern.allMatches(text)) {
      final toolName = match.group(1) ?? '';
      if (toolName.isEmpty || !_registry.hasTool(toolName)) continue;

      final argsMatch = argsPattern.firstMatch(text.substring(match.start));
      Map<String, dynamic> args = {};
      if (argsMatch != null) {
        try {
          args = jsonDecode(argsMatch.group(1)!) as Map<String, dynamic>;
        } catch (ex) {
          appLog.error('PlanGenerator: failed to parse tool args', error: ex);
        }
      }

      steps.add(
        AgentStep(description: 'Use $toolName', toolName: toolName, args: args),
      );
    }

    return steps;
  }

  String _cleanJsonResponse(String response) {
    var cleaned = response.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}... [truncated]';
  }
}

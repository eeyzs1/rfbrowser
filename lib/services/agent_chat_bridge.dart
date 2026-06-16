import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent/agent_tool_registry.dart';
import 'agent_service.dart';

/// Converts AgentTool definitions to OpenAI / Anthropic function-calling formats,
/// executes tool calls from AI responses, and formats results.
class AgentChatBridge {
  final AgentToolRegistry _registry;

  AgentChatBridge(this._registry);

  // ─── Format conversion ─────────────────────────────────────────────

  /// Convert all registered tools to OpenAI `tools` array format.
  List<Map<String, dynamic>> toOpenAITools() {
    return _registry.allTools.map((tool) {
      return {
        'type': 'function',
        'function': {
          'name': tool.name,
          'description': tool.description,
          'parameters': _cleanSchema(tool.parametersSchema),
        },
      };
    }).toList();
  }

  /// Convert all registered tools to Anthropic `tools` array format.
  List<Map<String, dynamic>> toAnthropicTools() {
    return _registry.allTools.map((tool) {
      return {
        'name': tool.name,
        'description': tool.description,
        'input_schema': _cleanSchema(tool.parametersSchema),
      };
    }).toList();
  }

  /// Remove fields that are not valid JSON Schema (e.g. extra metadata).
  Map<String, dynamic> _cleanSchema(Map<String, dynamic> schema) {
    if (schema.isEmpty) {
      return {'type': 'object', 'properties': {}};
    }
    final cleaned = Map<String, dynamic>.from(schema);
    cleaned.putIfAbsent('type', () => 'object');
    return cleaned;
  }

  // ─── Tool execution ─────────────────────────────────────────────────

  /// Execute a tool by name and return a formatted result map.
  Future<Map<String, dynamic>> executeTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final tool = _registry.getTool(toolName);
    if (tool == null) {
      return {
        'success': false,
        'output': 'Unknown tool: $toolName',
        'error': 'Unknown tool: $toolName',
      };
    }

    try {
      final result = await tool.execute(args);
      return {
        'success': result.success,
        'output': result.output,
        'error': result.error,
        'metadata': result.metadata,
      };
    } catch (e) {
      return {'success': false, 'output': '', 'error': '$toolName failed: $e'};
    }
  }

  // ─── OpenAI tool-call stream helpers ─────────────────────────────────

  /// Parse accumulated tool call arguments from deltas.
  /// Returns a list of completed tool call objects.
  List<Map<String, dynamic>> extractOpenAIToolCalls(
    Map<String, dynamic> delta,
  ) {
    final choices = delta['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return [];

    final toolCalls = <Map<String, dynamic>>[];
    for (final choice in choices) {
      final deltaChoice = choice['delta'] as Map<String, dynamic>?;
      if (deltaChoice == null) continue;

      final tcItems = deltaChoice['tool_calls'] as List<dynamic>?;
      if (tcItems == null) continue;

      for (final tc in tcItems) {
        toolCalls.add(Map<String, dynamic>.from(tc as Map));
      }
    }
    return toolCalls;
  }

  // ─── Anthropic tool-use helpers ─────────────────────────────────────

  /// Parse tool_use blocks from an Anthropic content block delta.
  List<Map<String, dynamic>> extractAnthropicToolUses(
    Map<String, dynamic> event,
  ) {
    final type = event['type'] as String?;
    if (type == 'content_block_start') {
      final block = event['content_block'] as Map<String, dynamic>?;
      if (block != null && block['type'] == 'tool_use') {
        return [Map<String, dynamic>.from(block)];
      }
    }
    if (type == 'content_block_delta') {
      final delta = event['delta'] as Map<String, dynamic>?;
      if (delta != null && delta['type'] == 'input_json_delta') {
        return [
          {'partial_json': delta['partial_json'] as String? ?? ''},
        ];
      }
    }
    return [];
  }

  // ─── Tool result formatting for conversation ────────────────────────

  /// Format a tool result as an OpenAI `tool` role message.
  Map<String, dynamic> toOpenAIToolMessage(
    String toolCallId,
    String toolName,
    Map<String, dynamic> result,
  ) {
    return {
      'role': 'tool',
      'tool_call_id': toolCallId,
      'content': jsonEncode(result),
    };
  }

  /// Format a tool result as an Anthropic `tool_result` content block.
  Map<String, dynamic> toAnthropicToolResult(
    String toolUseId,
    Map<String, dynamic> result,
  ) {
    return {
      'role': 'user',
      'content': [
        {
          'type': 'tool_result',
          'tool_use_id': toolUseId,
          'content': result['success'] == true
              ? result['output'] as String? ?? ''
              : 'Error: ${result['error'] ?? 'Unknown'}',
        },
      ],
    };
  }

  /// Get a human-readable summary for display in chat UI.
  String formatToolCallForDisplay(String toolName, Map<String, dynamic> args) {
    switch (toolName) {
      case 'search_notes':
        return 'Searching notes: "${args['query']}"';
      case 'create_note':
        return 'Creating note: "${args['title']}"';
      case 'navigate':
        return 'Navigating to: ${args['url']}';
      case 'extract_text':
        return 'Extracting text from: ${args['url']}';
      case 'ai_reason':
        final prompt = args['prompt'] as String? ?? '';
        return 'AI reasoning: "${prompt.length > 60 ? '${prompt.substring(0, 60)}...' : prompt}"';
      case 'web_clip':
        return 'Clipping web page: ${args['url']}';
      case 'list_notes':
        return 'Listing notes';
      case 'get_tags':
        return 'Getting all tags';
      case 'delete_note':
        return 'Deleting note: "${args['title']}"';
      case 'update_note':
        return 'Updating note: "${args['title']}"';
      case 'move_note':
        return 'Moving note: "${args['title']}"';
      case 'rename_note':
        return 'Renaming note: "${args['oldTitle']}"';
      default:
        return 'Using tool: $toolName';
    }
  }

  /// Format a tool result for display in chat UI.
  String formatToolResultForDisplay(
    String toolName,
    Map<String, dynamic> result,
  ) {
    if (result['success'] != true) {
      return 'Failed: ${result['error'] ?? 'Unknown error'}';
    }
    final output = result['output'] as String? ?? '';
    if (output.length > 200) {
      return '${output.substring(0, 200)}...';
    }
    return output;
  }
}

/// Provider that creates AgentChatBridge from the agent's tool registry.
final agentChatBridgeProvider = Provider<AgentChatBridge>((ref) {
  final agentState = ref.watch(agentProvider);
  return AgentChatBridge(agentState.toolRegistry);
});

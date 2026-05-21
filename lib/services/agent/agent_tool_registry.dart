import 'agent_tool.dart';

class AgentToolRegistry {
  final Map<String, AgentTool> _tools = {};

  Map<String, AgentTool> get tools => Map.unmodifiable(_tools);

  List<AgentTool> get allTools => _tools.values.toList();

  void register(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  void unregister(String name) {
    _tools.remove(name);
  }

  AgentTool? getTool(String name) => _tools[name];

  bool hasTool(String name) => _tools.containsKey(name);

  Future<ToolResult> execute(String toolName, Map<String, dynamic> args) async {
    final tool = _tools[toolName];
    if (tool == null) {
      return ToolResult.failure('Unknown tool: $toolName');
    }
    return tool.execute(args);
  }

  List<Map<String, dynamic>> allToolDefinitions() {
    return _tools.values.map((t) => t.toToolDefinition()).toList();
  }

  String toolsPrompt() {
    return _tools.values.map((t) => t.toPromptDescription()).join('\n\n');
  }

  void clear() {
    _tools.clear();
  }
}

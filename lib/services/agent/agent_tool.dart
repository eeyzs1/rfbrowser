class ToolResult {
  final bool success;
  final String output;
  final String? error;
  final Map<String, dynamic> metadata;

  const ToolResult({
    required this.success,
    required this.output,
    this.error,
    this.metadata = const {},
  });

  factory ToolResult.success(String output, {Map<String, dynamic>? metadata}) {
    return ToolResult(
      success: true,
      output: output,
      metadata: metadata ?? const {},
    );
  }

  factory ToolResult.failure(String error) {
    return ToolResult(success: false, output: '', error: error);
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'output': output,
    if (error != null) 'error': error,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  @override
  String toString() => success ? output : 'Error: $error';
}

abstract class AgentTool {
  final String name;
  final String description;
  final Map<String, dynamic> parametersSchema;
  final bool isDestructive;
  final String source;

  const AgentTool({
    required this.name,
    required this.description,
    this.parametersSchema = const {},
    this.isDestructive = false,
    this.source = 'builtin',
  });

  Future<ToolResult> execute(Map<String, dynamic> args);

  Map<String, dynamic> toToolDefinition() => {
    'name': name,
    'description': description,
    'parameters': parametersSchema,
    'isDestructive': isDestructive,
    'source': source,
  };

  String toPromptDescription() {
    final props = parametersSchema['properties'];
    final params = props != null
        ? Map<String, dynamic>.from(props as Map)
        : null;
    final required = parametersSchema['required'] as List<dynamic>? ?? [];
    final paramDesc =
        params?.entries
            .map((e) {
              final desc =
                  (e.value as Map<String, dynamic>)['description'] as String? ??
                  '';
              final req = required.contains(e.key)
                  ? ' (required)'
                  : ' (optional)';
              return '  - ${e.key}$req: $desc';
            })
            .join('\n') ??
        '  (no parameters)';
    return '## $name\n$description\n\nParameters:\n$paramDesc${isDestructive ? '\n⚠️ This action is destructive and requires user confirmation.' : ''}';
  }
}

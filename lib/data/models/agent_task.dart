enum TaskStatus { pending, running, paused, completed, failed }

enum TaskMode { manual, aiPlanned, reactLoop }

class AgentStep {
  final String description;
  final String? toolName;
  final Map<String, dynamic> args;
  final String? condition;
  final int retryCount;
  final String? onFailure;
  final TaskStatus status;
  final String? result;
  final DateTime? completedAt;
  final int retryAttempt;

  const AgentStep({
    required this.description,
    this.toolName,
    this.args = const {},
    this.condition,
    this.retryCount = 0,
    this.onFailure,
    this.status = TaskStatus.pending,
    this.result,
    this.completedAt,
    this.retryAttempt = 0,
  });

  AgentStep copyWith({
    String? description,
    String? toolName,
    Map<String, dynamic>? args,
    String? condition,
    int? retryCount,
    String? onFailure,
    TaskStatus? status,
    String? result,
    DateTime? completedAt,
    int? retryAttempt,
  }) {
    return AgentStep(
      description: description ?? this.description,
      toolName: toolName ?? this.toolName,
      args: args ?? this.args,
      condition: condition ?? this.condition,
      retryCount: retryCount ?? this.retryCount,
      onFailure: onFailure ?? this.onFailure,
      status: status ?? this.status,
      result: result ?? this.result,
      completedAt: completedAt ?? this.completedAt,
      retryAttempt: retryAttempt ?? this.retryAttempt,
    );
  }

  bool get needsConfirmation => onFailure == 'abort' || retryCount > 0;

  Map<String, dynamic> toJson() => {
    'description': description,
    if (toolName != null) 'toolName': toolName,
    'args': args,
    if (condition != null) 'condition': condition,
    if (retryCount > 0) 'retryCount': retryCount,
    if (onFailure != null) 'onFailure': onFailure,
    'status': status.name,
    if (result != null) 'result': result,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'retryAttempt': retryAttempt,
  };

  factory AgentStep.fromJson(Map<String, dynamic> json) => AgentStep(
    description: json['description'] as String? ?? '',
    toolName: json['toolName'] as String?,
    args: (json['args'] as Map<String, dynamic>?) ?? {},
    condition: json['condition'] as String?,
    retryCount: json['retryCount'] as int? ?? 0,
    onFailure: json['onFailure'] as String?,
    status: TaskStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => TaskStatus.pending,
    ),
    result: json['result'] as String?,
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
    retryAttempt: json['retryAttempt'] as int? ?? 0,
  );
}

class AgentTask {
  final String id;
  final String name;
  final String description;
  final TaskStatus status;
  final TaskMode mode;
  final List<AgentStep> steps;
  final Map<String, dynamic> context;
  final DateTime created;
  final DateTime? completed;
  final String? result;
  final int maxIterations;

  AgentTask({
    required this.id,
    required this.name,
    required this.description,
    this.status = TaskStatus.pending,
    this.mode = TaskMode.manual,
    this.steps = const [],
    this.context = const {},
    DateTime? created,
    this.completed,
    this.result,
    this.maxIterations = 50,
  }) : created = created ?? DateTime.now();

  AgentTask copyWith({
    String? id,
    String? name,
    String? description,
    TaskStatus? status,
    TaskMode? mode,
    List<AgentStep>? steps,
    Map<String, dynamic>? context,
    Object? completed = _sentinel,
    Object? result = _sentinel,
    int? maxIterations,
  }) {
    return AgentTask(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      steps: steps ?? this.steps,
      context: context ?? this.context,
      created: created,
      completed: identical(completed, _sentinel) ? this.completed : completed as DateTime?,
      result: identical(result, _sentinel) ? this.result : result as String?,
      maxIterations: maxIterations ?? this.maxIterations,
    );
  }

  static const _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'status': status.name,
    'mode': mode.name,
    'steps': steps.map((s) => s.toJson()).toList(),
    'context': context,
    'created': created.toIso8601String(),
    if (completed != null) 'completed': completed!.toIso8601String(),
    if (result != null) 'result': result,
    'maxIterations': maxIterations,
  };

  factory AgentTask.fromJson(Map<String, dynamic> json) => AgentTask(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    status: TaskStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => TaskStatus.pending,
    ),
    mode: TaskMode.values.firstWhere(
      (e) => e.name == json['mode'],
      orElse: () => TaskMode.manual,
    ),
    steps:
        (json['steps'] as List?)
            ?.map((s) => AgentStep.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
    context: (json['context'] as Map<String, dynamic>?) ?? {},
    created: json['created'] != null
        ? DateTime.parse(json['created'] as String)
        : DateTime.now(),
    completed: json['completed'] != null
        ? DateTime.parse(json['completed'] as String)
        : null,
    result: json['result'] as String?,
    maxIterations: json['maxIterations'] as int? ?? 50,
  );
}

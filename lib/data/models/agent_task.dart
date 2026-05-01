enum TaskStatus { pending, running, paused, completed, failed }

class AgentStep {
  final String description;
  final TaskStatus status;
  final String? result;
  final DateTime? completedAt;

  AgentStep({
    required this.description,
    this.status = TaskStatus.pending,
    this.result,
    this.completedAt,
  });

  AgentStep copyWith({
    TaskStatus? status,
    String? result,
    DateTime? completedAt,
  }) {
    return AgentStep(
      description: description,
      status: status ?? this.status,
      result: result ?? this.result,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class AgentTask {
  final String id;
  final String name;
  final String description;
  final TaskStatus status;
  final List<AgentStep> steps;
  final Map<String, dynamic> context;
  final DateTime created;
  final DateTime? completed;
  final String? result;

  AgentTask({
    required this.id,
    required this.name,
    required this.description,
    this.status = TaskStatus.pending,
    this.steps = const [],
    this.context = const {},
    DateTime? created,
    this.completed,
    this.result,
  }) : created = created ?? DateTime.now();

  AgentTask copyWith({
    TaskStatus? status,
    List<AgentStep>? steps,
    DateTime? completed,
    String? result,
  }) {
    return AgentTask(
      id: id,
      name: name,
      description: description,
      status: status ?? this.status,
      steps: steps ?? this.steps,
      context: context,
      created: created,
      completed: completed ?? this.completed,
      result: result ?? this.result,
    );
  }
}

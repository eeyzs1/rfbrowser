class Skill {
  final String id;
  final String name;
  final String description;
  final String prompt;
  final Map<String, SkillParam> params;
  final String? pluginId;
  final bool isBuiltin;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.prompt,
    this.params = const {},
    this.pluginId,
    this.isBuiltin = false,
  });

  Skill copyWith({
    String? id,
    String? name,
    String? description,
    String? prompt,
    Map<String, SkillParam>? params,
    String? pluginId,
    bool? isBuiltin,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      prompt: prompt ?? this.prompt,
      params: params ?? this.params,
      pluginId: pluginId ?? this.pluginId,
      isBuiltin: isBuiltin ?? this.isBuiltin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'prompt': prompt,
      'params': params.map((k, v) => MapEntry(k, v.toJson())),
      if (pluginId != null) 'pluginId': pluginId,
      'isBuiltin': isBuiltin,
    };
  }

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      prompt: json['prompt'] ?? '',
      params:
          (json['params'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, SkillParam.fromJson(v)),
          ) ??
          {},
      pluginId: json['pluginId'],
      isBuiltin: json['isBuiltin'] ?? false,
    );
  }
}

class SkillParam {
  final String name;
  final String type;
  final String description;
  final bool required;
  final dynamic defaultValue;

  SkillParam({
    required this.name,
    required this.type,
    required this.description,
    this.required = false,
    this.defaultValue,
  });

  SkillParam copyWith({
    String? name,
    String? type,
    String? description,
    bool? required,
    dynamic defaultValue,
  }) {
    return SkillParam(
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      required: required ?? this.required,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'description': description,
      'required': required,
      if (defaultValue != null) 'defaultValue': defaultValue,
    };
  }

  factory SkillParam.fromJson(Map<String, dynamic> json) {
    return SkillParam(
      name: json['name'] ?? '',
      type: json['type'] ?? 'string',
      description: json['description'] ?? '',
      required: json['required'] ?? false,
      defaultValue: json['defaultValue'],
    );
  }
}

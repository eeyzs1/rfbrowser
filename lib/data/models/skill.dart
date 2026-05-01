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
}

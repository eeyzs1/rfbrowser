import '../data/models/skill.dart';

/// Built-in skills shipped with the app.
///
/// Extracted from `NoteNotifier._getBuiltinSkills()` so the skill catalog
/// lives in a single data file rather than inline in service code. User
/// skills loaded from the vault are appended at runtime by `NoteNotifier`.
final List<Skill> kBuiltinSkills = [
  Skill(
    id: 'summarize-page',
    name: 'Summarize Page',
    description: 'Summarize the current web page',
    prompt: 'Please summarize the following web page content:\n\n@web[current]',
    isBuiltin: true,
  ),
  Skill(
    id: 'summarize-note',
    name: 'Summarize Note',
    description: 'Summarize the current note',
    prompt: 'Please summarize the following note:\n\n@note[current]',
    isBuiltin: true,
  ),
  Skill(
    id: 'research-topic',
    name: 'Research Topic',
    description: 'Deep research on a topic',
    prompt:
        'Conduct thorough research on the following topic and provide a comprehensive summary with key findings:\n\n{{topic}}',
    params: {
      'topic': SkillParam(
        name: 'topic',
        type: 'string',
        description: 'Topic to research',
        required: true,
      ),
    },
    isBuiltin: true,
  ),
  Skill(
    id: 'extract-key-points',
    name: 'Extract Key Points',
    description: 'Extract key points from content',
    prompt:
        'Extract the key points from the following content and format them as a bullet list:\n\n@note[current]',
    isBuiltin: true,
  ),
  Skill(
    id: 'generate-outline',
    name: 'Generate Outline',
    description: 'Generate an outline for a topic',
    prompt: 'Generate a detailed outline for the following topic:\n\n{{topic}}',
    params: {
      'topic': SkillParam(
        name: 'topic',
        type: 'string',
        description: 'Topic for the outline',
        required: true,
      ),
    },
    isBuiltin: true,
  ),
  Skill(
    id: 'auto-tag',
    name: 'Auto Tag',
    description: 'Automatically suggest tags for the current note',
    prompt:
        'Analyze the following note and suggest relevant tags. Return only the tags as a comma-separated list:\n\n@note[current]',
    isBuiltin: true,
  ),
  Skill(
    id: 'daily-review',
    name: 'Daily Review',
    description: 'Generate a daily review summary',
    prompt:
        "Review today's daily note and generate a summary of accomplishments and pending tasks:\n\n@note[daily]",
    isBuiltin: true,
  ),
];

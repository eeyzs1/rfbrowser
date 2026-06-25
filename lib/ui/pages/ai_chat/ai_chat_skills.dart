part of '../ai_chat_panel.dart';

mixin _AIChatSkillsMixin on _AIChatPanelStateBase {
  @override
  void _showSkillPicker(ThemeData theme) async {
    final knowledgeNotifier = ref.read(knowledgeProvider.notifier);

    final skills = await knowledgeNotifier.getAllSkills();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Skills'),
          ],
        ),
        contentPadding: const EdgeInsets.only(top: 16),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: skills.map((skill) {
              return ListTile(
                dense: true,
                leading: Icon(
                  skill.isBuiltin ? Icons.bolt : Icons.extension,
                  size: 16,
                  color: skill.isBuiltin
                      ? theme.colorScheme.primary
                      : theme.hintColor,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        skill.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _skillSourceBadge(skill, theme),
                  ],
                ),
                subtitle: skill.description.isNotEmpty
                    ? Text(
                        skill.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _executeSkill(skill);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _skillSourceBadge(dynamic skill, ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    final pluginId = skill.pluginId as String?;
    final isBuiltin = skill.isBuiltin == true;

    String label;
    Color color;

    if (pluginId != null && pluginId.isNotEmpty) {
      label = l.extrazerodoSkillPlugin(pluginId);
      color = const Color(0xFF8B5CF6);
    } else if (isBuiltin) {
      label = l.extrazerodoSkillBuiltin;
      color = theme.colorScheme.primary;
    } else {
      label = l.extrazerodoSkillCustom;
      color = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _executeSkill(dynamic skill) {
    final knowledge = ref.read(knowledgeProvider);
    final browser = ref.read(browserProvider);
    final activeNote = knowledge.activeNote;
    final activeTab = browser.activeTab;

    var prompt = skill.prompt as String;

    prompt = prompt.replaceAll(
      '@note[current]',
      activeNote != null
          ? 'Note "${activeNote.title}":\n${activeNote.content.length > 3000 ? '${activeNote.content.substring(0, 3000)}...(truncated)' : activeNote.content}'
          : '(No note currently open)',
    );

    prompt = prompt.replaceAll(
      '@web[current]',
      activeTab != null && activeTab.url.isNotEmpty
          ? 'Web page "${activeTab.title}" (${activeTab.url})'
          : '(No web page currently open)',
    );

    prompt = prompt.replaceAll('@note[daily]', '(Daily note not loaded)');

    if (skill.params != null && skill.params.isNotEmpty) {
      _promptForParams(skill, prompt);
    } else {
      final contextBuffer = StringBuffer();
      if (activeNote != null) {
        contextBuffer.writeln('[Current Note: ${activeNote.title}]');
      }
      if (activeTab != null && activeTab.url.isNotEmpty) {
        contextBuffer.writeln('[Current Page: ${activeTab.title}]');
      }
      ref
          .read(aiProvider.notifier)
          .sendMessage(
            prompt,
            context: contextBuffer.isNotEmpty ? contextBuffer.toString() : null,
          );
    }
  }

  void _promptForParams(dynamic skill, String basePrompt) {
    final controllers = <String, TextEditingController>{};
    for (final param in skill.params.values) {
      controllers[param.name] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(skill.name),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: skill.params.values.map((param) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[param.name],
                  decoration: InputDecoration(
                    labelText: param.name,
                    hintText: param.description,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              var prompt = basePrompt;
              controllers.forEach((key, controller) {
                prompt = prompt.replaceAll('{{$key}}', controller.text.trim());
              });
              Navigator.pop(ctx);
              ref.read(aiProvider.notifier).sendMessage(prompt);
            },
            child: const Text('Run'),
          ),
        ],
      ),
    );
  }
}

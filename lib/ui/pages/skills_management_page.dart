import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/skill.dart';
import '../../services/knowledge_service.dart';

part 'skills_management_page_widgets.dart';

class SkillsManagementPage extends ConsumerStatefulWidget {
  const SkillsManagementPage({super.key});

  @override
  ConsumerState<SkillsManagementPage> createState() =>
      _SkillsManagementPageState();
}

class _SkillsManagementPageState extends ConsumerState<SkillsManagementPage> {
  List<Skill> _skills = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() => _loading = true);
    final svc = ref.read(knowledgeProvider.notifier);
    final skills = await svc.getAllSkills();
    if (mounted) {
      setState(() {
        _skills = skills;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    final customSkills = _skills
        .where((s) => !s.isBuiltin && s.pluginId == null)
        .toList();
    final builtinSkills = _skills.where((s) => s.isBuiltin).toList();
    final pluginSkills = _skills
        .where((s) => !s.isBuiltin && s.pluginId != null)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.skills)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_skill',
        onPressed: () => _showSkillEditor(context, l),
        tooltip: l.extrazerodoSkillCreate,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _skills.isEmpty
          ? _buildEmptyState(theme, l)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (customSkills.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.edit_note,
                    title: l.extrazerodoSkillCustom,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  ...customSkills.map(
                    (s) => _SkillCard(
                      skill: s,
                      onEdit: () => _showSkillEditor(context, l, existing: s),
                      onDelete: () => _confirmDelete(context, l, s),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (builtinSkills.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.bolt,
                    title: l.extrazerodoSkillBuiltin,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(height: 8),
                  ...builtinSkills.map(
                    (s) => _SkillCard(skill: s, readOnly: true),
                  ),
                  const SizedBox(height: 24),
                ],
                if (pluginSkills.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.extension,
                    title: l.extrazerodoSkillPlugin(
                      pluginSkills.first.pluginId ?? '',
                    ),
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 8),
                  ...pluginSkills.map(
                    (s) => _SkillCard(skill: s, readOnly: true),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 48, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(l.extrazerodoSkillsN(0), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            l.extrazerodoSkillEmptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showSkillEditor(context, l),
            icon: const Icon(Icons.add),
            label: Text(l.extrazerodoSkillCreate),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l,
    Skill skill,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.extrazerodoSkillDelete),
        content: Text(l.extrazerodoSkillDeleteConfirm(skill.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(knowledgeProvider.notifier).deleteSkill(skill.id);
      await _loadSkills();
    }
  }

  void _showSkillEditor(
    BuildContext context,
    AppLocalizations l, {
    Skill? existing,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _SkillEditorDialog(existing: existing),
    ).then((_) => _loadSkills());
  }
}

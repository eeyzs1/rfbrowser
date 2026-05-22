import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/skill.dart';
import '../../services/knowledge_service.dart';

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

    final customSkills =
        _skills.where((s) => !s.isBuiltin && s.pluginId == null).toList();
    final builtinSkills = _skills.where((s) => s.isBuiltin).toList();
    final pluginSkills =
        _skills.where((s) => !s.isBuiltin && s.pluginId != null).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.skills),
      ),
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
                          onEdit: () =>
                              _showSkillEditor(context, l, existing: s),
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
                            pluginSkills.first.pluginId ?? ''),
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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
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
      BuildContext context, AppLocalizations l, Skill skill) async {
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

  void _showSkillEditor(BuildContext context, AppLocalizations l,
      {Skill? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _SkillEditorDialog(existing: existing),
    ).then((_) => _loadSkills());
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SkillCard extends StatelessWidget {
  final Skill skill;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool readOnly;

  const _SkillCard({
    required this.skill,
    this.onEdit,
    this.onDelete,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          readOnly ? Icons.bolt : Icons.edit_note,
          size: 20,
          color: readOnly ? Colors.amber.shade700 : theme.colorScheme.primary,
        ),
        title: Text(
          skill.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
        trailing: readOnly
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 18, color: theme.hintColor),
                    onPressed: onEdit,
                    tooltip: l.edit,
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                    onPressed: onDelete,
                    tooltip: l.delete,
                  ),
                ],
              ),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Prompt',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    skill.prompt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                if (skill.params.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.tune, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        l.extrazerodoSkillParams,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...skill.params.values.map(
                    (param) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: param.required
                                  ? theme.colorScheme.error.withValues(alpha: 0.1)
                                  : theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              param.required ? l.required : l.optional,
                              style: TextStyle(
                                fontSize: 9,
                                color: param.required
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            param.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              param.description,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.hintColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillEditorDialog extends ConsumerStatefulWidget {
  final Skill? existing;

  const _SkillEditorDialog({this.existing});

  @override
  ConsumerState<_SkillEditorDialog> createState() =>
      _SkillEditorDialogState();
}

class _SkillEditorDialogState extends ConsumerState<_SkillEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _promptCtrl;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _promptCtrl = TextEditingController(text: widget.existing?.prompt ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(_isEditing ? l.extrazerodoSkillEdit : l.extrazerodoSkillCreate),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: l.extrazerodoSkillNameHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: l.extrazerodoSkillDescHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _promptCtrl,
                  decoration: InputDecoration(
                    labelText: 'Prompt',
                    hintText: l.extrazerodoSkillPromptHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 6,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.required : null,
                ),
                const SizedBox(height: 8),
                Text(
                  l.extrazerodoSkillPromptTips,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final id = _isEditing
        ? widget.existing!.id
        : 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final skill = Skill(
      id: id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      prompt: _promptCtrl.text.trim(),
    );

    final notifier = ref.read(knowledgeProvider.notifier);
    if (_isEditing) {
      await notifier.updateSkill(skill);
    } else {
      await notifier.createSkill(skill);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
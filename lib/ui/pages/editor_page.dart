import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/knowledge_service.dart';
import '../../data/stores/vault_store.dart';

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  final _controller = TextEditingController();
  bool _isPreview = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_isDirty) setState(() => _isDirty = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);

    if (vaultState.currentVault == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.edit_note,
                size: 32,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text('No Vault Connected', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Open a vault to start writing notes',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final note = knowledgeState.activeNote;

    if (note == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 64, color: theme.hintColor),
            const SizedBox(height: 16),
            Text('No note selected', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Create a new note or select one from the sidebar',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _createNewNote(),
              icon: const Icon(Icons.add),
              label: const Text('New Note'),
            ),
          ],
        ),
      );
    }

    if (!_isDirty) {
      _controller.text = note.content;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  note.title,
                  style: theme.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isDirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(
                  _isPreview ? Icons.edit : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => setState(() => _isPreview = !_isPreview),
                tooltip: _isPreview ? 'Edit' : 'Preview',
              ),
              IconButton(
                icon: const Icon(Icons.save, size: 18),
                onPressed: _saveNote,
                tooltip: 'Save',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isPreview ? _buildPreview(theme, note) : _buildEditor(theme),
        ),
      ],
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.6,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Start writing...',
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: theme.hintColor,
          ),
        ),
        onChanged: (_) {
          ref
              .read(knowledgeProvider.notifier)
              .updateActiveNoteContent(_controller.text);
        },
      ),
    );
  }

  Widget _buildPreview(ThemeData theme, dynamic note) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        note.content,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
      ),
    );
  }

  void _saveNote() {
    ref.read(knowledgeProvider.notifier).saveActiveNote();
    setState(() => _isDirty = false);
  }

  void _createNewNote() async {
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Note'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Note title'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (title != null && title.isNotEmpty) {
      await ref.read(knowledgeProvider.notifier).createNote(title: title);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/knowledge_service.dart';
import '../../data/stores/vault_store.dart';

class NoteSidebar extends ConsumerStatefulWidget {
  const NoteSidebar({super.key});

  @override
  ConsumerState<NoteSidebar> createState() => _NoteSidebarState();
}

class _NoteSidebarState extends ConsumerState<NoteSidebar> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final vaultState = ref.watch(vaultProvider);
    final theme = Theme.of(context);

    if (vaultState.currentVault == null) {
      return _buildNoVaultPrompt(theme);
    }

    final notes = _filterNotes(knowledgeState.notes);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () => _createNewNote(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              hintText: 'Search notes...',
              hintStyle: theme.textTheme.bodySmall,
              prefixIcon: const Icon(Icons.search, size: 14),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 12),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Text(
                    'No notes found',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final isActive = knowledgeState.activeNote?.id == note.id;
                    return _NoteItem(
                      note: note,
                      isActive: isActive,
                      onTap: () => ref
                          .read(knowledgeProvider.notifier)
                          .openNote(note.filePath),
                      onDelete: () =>
                          _confirmDeleteNote(note.title, note.filePath),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<dynamic> _filterNotes(List notes) {
    if (_searchQuery.isEmpty) return notes;
    final q = _searchQuery.toLowerCase();
    return notes.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q)) ||
          n.content.toLowerCase().contains(q);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    if (query.length >= 2) {
      ref.read(knowledgeProvider.notifier).search(query);
    }
  }

  Widget _buildNoVaultPrompt(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_off, size: 40, color: theme.hintColor),
                  const SizedBox(height: 12),
                  Text(
                    'No Vault Connected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Open a vault to manage notes',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openVault(),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open Vault'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _createVault(),
                    icon: const Icon(Icons.create_new_folder, size: 16),
                    label: const Text('Create Vault'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openVault() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Vault Location',
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).openVault(result);
      ref.read(knowledgeProvider.notifier).loadAllNotes();
    }
  }

  Future<void> _createVault() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Vault Location',
    );
    if (result != null) {
      await ref.read(vaultProvider.notifier).createVault(result);
      ref.read(knowledgeProvider.notifier).loadAllNotes();
    }
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

  void _confirmDeleteNote(String title, String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(knowledgeProvider.notifier).deleteNote(filePath);
    }
  }
}

class _NoteItem extends StatelessWidget {
  final dynamic note;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteItem({
    required this.note,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : null,
        child: Row(
          children: [
            Icon(
              Icons.description,
              size: 14,
              color: isActive ? theme.colorScheme.primary : theme.hintColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isActive ? theme.colorScheme.primary : null,
                      fontWeight: isActive ? FontWeight.w600 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 4,
                        children: note.tags
                            .take(3)
                            .map<Widget>(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 12),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            ),
          ],
        ),
      ),
    );
  }
}

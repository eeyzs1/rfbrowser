import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/knowledge_service.dart';
import '../../data/models/note.dart';
import '../theme/design_tokens.dart';

class QuickSearchBar extends ConsumerStatefulWidget {
  final ValueChanged<Note>? onNoteSelected;

  const QuickSearchBar({super.key, this.onNoteSelected});

  @override
  ConsumerState<QuickSearchBar> createState() => _QuickSearchBarState();
}

class _QuickSearchBarState extends ConsumerState<QuickSearchBar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Note> _filterNotes() {
    final knowledgeState = ref.read(knowledgeProvider);
    if (_query.isEmpty) return const [];
    final lowerQuery = _query.toLowerCase();
    return knowledgeState.notes
        .where((n) =>
            n.title.toLowerCase().contains(lowerQuery) ||
            n.content.toLowerCase().contains(lowerQuery))
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final filtered = _filterNotes();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.md,
        vertical: DesignSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: l.searchNotes,
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
                prefixIcon: const Icon(Icons.search, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: DesignSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              style: theme.textTheme.bodyMedium,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: DesignSpacing.xs),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(DesignRadius.sm),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (context, idx) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final note = filtered[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: theme.hintColor,
                    ),
                    title: Text(
                      note.title,
                      style: theme.textTheme.bodySmall,
                    ),
                    subtitle: Text(
                      note.content.length > 80
                          ? '${note.content.substring(0, 80)}...'
                          : note.content,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    onTap: () {
                      widget.onNoteSelected?.call(note);
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

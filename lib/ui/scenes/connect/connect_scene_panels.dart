part of 'connect_scene.dart';

/// Left-side panel listing knowledge notes that can be added to the canvas.
/// Supports search filtering and shows which notes are already on the canvas.
class _CanvasNotePanel extends ConsumerStatefulWidget {
  final void Function(Note note) onAddNote;

  const _CanvasNotePanel({required this.onAddNote});

  @override
  ConsumerState<_CanvasNotePanel> createState() => _CanvasNotePanelState();
}

class _CanvasNotePanelState extends ConsumerState<_CanvasNotePanel> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final knowledgeState = ref.watch(knowledgeProvider);
    final canvasData = ref.watch(canvasProvider);
    final settings = ref.watch(settingsProvider);
    final baseFontSize = settings.editorFontSize * 0.75;

    final onCanvasNoteIds = canvasData.cards
        .where((c) => c.noteId != null)
        .map((c) => c.noteId!)
        .toSet();

    var filteredNotes = knowledgeState.notes.toList();
    if (_searchQuery.isNotEmpty) {
      final lower = _searchQuery.toLowerCase();
      filteredNotes = filteredNotes
          .where(
            (n) =>
                n.title.toLowerCase().contains(lower) ||
                n.tags.any((t) => t.toLowerCase().contains(lower)),
          )
          .toList();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l.notesOnCanvas,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filteredNotes.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l.searchNotes,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: theme.hintColor,
                          ),
                        )
                      : null,
                ),
                style: TextStyle(fontSize: baseFontSize),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              l.dragOrClickToAdd,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontSize: baseFontSize * 0.9,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredNotes.isEmpty
                ? Center(
                    child: Text(
                      l.noNotes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
                      final isOnCanvas = onCanvasNoteIds.contains(note.id);
                      return _NoteTile(
                        note: note,
                        isOnCanvas: isOnCanvas,
                        baseFontSize: baseFontSize,
                        onAdd: () => widget.onAddNote(note),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final bool isOnCanvas;
  final double baseFontSize;
  final VoidCallback onAdd;

  const _NoteTile({
    required this.note,
    required this.isOnCanvas,
    required this.baseFontSize,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    return InkWell(
      onTap: isOnCanvas ? null : onAdd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              isOnCanvas ? Icons.check_circle : Icons.add_circle_outline,
              size: 14,
              color: isOnCanvas
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.hintColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? l.untagged : note.title,
                    style: TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: FontWeight.w500,
                      color: isOnCanvas ? theme.hintColor : null,
                      decoration: isOnCanvas
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note.tags.take(3).join(', '),
                        style: TextStyle(
                          fontSize: baseFontSize * 0.85,
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (isOnCanvas)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  l.alreadyOnCanvas,
                  style: TextStyle(
                    fontSize: baseFontSize * 0.75,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

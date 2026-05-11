import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/canvas_service.dart';
import '../../../services/knowledge_service.dart';
import '../../../services/settings_service.dart';
import '../../../data/models/canvas_model.dart';
import '../../../data/models/note.dart';
import '../../widgets/filter_panel.dart';
import '../../widgets/node_detail_panel.dart';
import '../../widgets/card_properties_panel.dart';
import '../../widgets/connection_properties_panel.dart';
import '../../widgets/ai_float.dart';
import '../../widgets/resizable_panel.dart';
import '../../pages/graph_page.dart';
import '../../pages/canvas_page.dart';

enum ConnectViewMode { graph, canvas }

class ConnectScene extends ConsumerStatefulWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleRightPanel;

  const ConnectScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.onToggleLeftPanel,
    this.onToggleRightPanel,
  });

  @override
  ConsumerState<ConnectScene> createState() => _ConnectSceneState();
}

class _ConnectSceneState extends ConsumerState<ConnectScene> {
  ConnectViewMode _viewMode = ConnectViewMode.canvas;

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final canvasData = ref.watch(canvasProvider);
    final theme = Theme.of(context);

    if (_viewMode == ConnectViewMode.canvas && (canvasData.selectedCardIds.isNotEmpty || canvasData.selectedConnectionId != null) && !widget.rightPanelExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onToggleRightPanel != null) widget.onToggleRightPanel!();
      });
    }

    return Stack(
      children: [
        Row(
          children: [
            if (widget.leftPanelExpanded)
              ResizablePanel(
                initialWidth: 220,
                minWidth: 160,
                maxWidth: 380,
                child: _viewMode == ConnectViewMode.graph
                    ? const FilterPanel()
                    : _CanvasNotePanel(onAddNote: _addNoteToCanvas),
              ),
            if (!widget.leftPanelExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onToggleLeftPanel,
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(right: BorderSide(color: theme.dividerColor)),
                    ),
                    child: Icon(Icons.chevron_right, size: 14, color: theme.hintColor),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _buildViewModeSwitcher(theme),
                  Expanded(
                    child: knowledgeState.notes.isEmpty
                        ? _buildConnectEmptyState(context)
                        : _viewMode == ConnectViewMode.graph
                            ? const GraphView()
                            : const CanvasPage(),
                  ),
                ],
              ),
            ),
            if (!widget.rightPanelExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onToggleRightPanel,
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(left: BorderSide(color: theme.dividerColor)),
                    ),
                    child: Icon(Icons.chevron_left, size: 14, color: theme.hintColor),
                  ),
                ),
              ),
            if (widget.rightPanelExpanded)
              ResizablePanel(
                initialWidth: 280,
                minWidth: 200,
                maxWidth: 450,
                isLeft: false,
                child: _viewMode == ConnectViewMode.canvas
                    ? _buildCanvasRightPanel(canvasData)
                    : NodeDetailPanel(onClose: widget.onToggleRightPanel ?? () {}),
              ),
          ],
        ),
        const Positioned.fill(child: AIFloat()),
      ],
    );
  }

  Widget _buildCanvasRightPanel(CanvasData canvasData) {
    if (canvasData.selectedConnectionId != null) {
      return ConnectionPropertiesPanel(onClose: widget.onToggleRightPanel ?? () {});
    }
    if (canvasData.selectedCardIds.isNotEmpty) {
      return CardPropertiesPanel(onClose: widget.onToggleRightPanel ?? () {});
    }
    return const SizedBox.shrink();
  }

  void _addNoteToCanvas(Note note) {
    final canvasData = ref.read(canvasProvider);
    final alreadyOnCanvas = canvasData.cards.any((c) => c.noteId == note.id);
    if (alreadyOnCanvas) return;

    final existingCards = canvasData.cards;
    double x = 0;
    double y = 0;
    if (existingCards.isNotEmpty) {
      double maxX = 0;
      double maxY = 0;
      for (final card in existingCards) {
        if (card.x + card.width > maxX) maxX = card.x + card.width;
        if (card.y + card.height > maxY) maxY = card.y + card.height;
      }
      x = maxX + 40;
      y = maxY > 0 ? 0 : 0;
    }

    final card = CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: CanvasCardType.note,
      x: x,
      y: y,
      width: 280,
      height: 200,
      title: note.title,
      content: note.content.length > 500 ? '${note.content.substring(0, 500)}...' : note.content,
      noteId: note.id,
    );
    ref.read(canvasProvider.notifier).addCard(card);
  }

  Widget _buildViewModeSwitcher(ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          _viewModeTab(theme, ConnectViewMode.canvas, Icons.dashboard, l.canvas),
          _viewModeTab(theme, ConnectViewMode.graph, Icons.hub, l.graph),
        ],
      ),
    );
  }

  Widget _viewModeTab(ThemeData theme, ConnectViewMode mode, IconData icon, String label) {
    final isActive = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? theme.colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isActive ? theme.colorScheme.primary : theme.hintColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive ? theme.colorScheme.primary : theme.hintColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _viewMode == ConnectViewMode.graph ? Icons.hub : Icons.dashboard,
            size: 48,
            color: theme.hintColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _viewMode == ConnectViewMode.graph
                ? l.graphWillShowAfterNotes
                : l.canvasWillShowAfterCards,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

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
          .where((n) =>
              n.title.toLowerCase().contains(lower) ||
              n.tags.any((t) => t.toLowerCase().contains(lower)))
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
                Icon(Icons.description_outlined, size: 14, color: theme.colorScheme.primary),
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
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(Icons.close, size: 12, color: theme.hintColor),
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
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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
              color: isOnCanvas ? theme.colorScheme.primary.withValues(alpha: 0.5) : theme.hintColor,
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
                      decoration: isOnCanvas ? TextDecoration.lineThrough : null,
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

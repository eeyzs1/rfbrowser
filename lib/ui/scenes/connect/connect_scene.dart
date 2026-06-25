import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/canvas_service.dart';
import '../../../services/knowledge_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/shortcut_service.dart';
import '../../../data/models/canvas_model.dart';
import '../../../data/models/note.dart';
import '../../widgets/filter_panel.dart';
import '../../widgets/node_detail_panel.dart';
import '../../widgets/card_properties_panel.dart';
import '../../widgets/connection_properties_panel.dart';
import '../../widgets/canvas_tag_filter.dart';
import '../../widgets/resizable_panel.dart';
import '../../pages/graph_page.dart';
import '../../pages/canvas_page.dart';

part 'connect_scene_panels.dart';

enum ConnectViewMode { graph, canvas }

class ConnectScene extends ConsumerStatefulWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleRightPanel;
  final ConnectViewMode initialViewMode;

  const ConnectScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.onToggleLeftPanel,
    this.onToggleRightPanel,
    this.initialViewMode = ConnectViewMode.canvas,
  });

  @override
  ConsumerState<ConnectScene> createState() => _ConnectSceneState();
}

class _ConnectSceneState extends ConsumerState<ConnectScene> {
  late ConnectViewMode _viewMode;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
  }

  @override
  void didUpdateWidget(ConnectScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialViewMode != oldWidget.initialViewMode) {
      setState(() => _viewMode = widget.initialViewMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final canvasData = ref.watch(canvasProvider);
    final theme = Theme.of(context);

    if (_viewMode == ConnectViewMode.canvas &&
        (canvasData.selectedCardIds.isNotEmpty ||
            canvasData.selectedConnectionId != null) &&
        !widget.rightPanelExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onToggleRightPanel != null) {
          widget.onToggleRightPanel!();
        }
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
                      border: Border(
                        right: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: theme.hintColor,
                    ),
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
                      border: Border(
                        left: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      size: 14,
                      color: theme.hintColor,
                    ),
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
                    : NodeDetailPanel(
                        onClose: widget.onToggleRightPanel ?? () {},
                      ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCanvasRightPanel(CanvasData canvasData) {
    if (canvasData.selectedConnectionId != null) {
      return ConnectionPropertiesPanel(
        onClose: widget.onToggleRightPanel ?? () {},
      );
    }
    if (canvasData.selectedCardIds.isNotEmpty) {
      return CardPropertiesPanel(onClose: widget.onToggleRightPanel ?? () {});
    }
    return const CanvasTagFilterPanel();
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
      content: note.content.length > 500
          ? '${note.content.substring(0, 500)}...'
          : note.content,
      noteId: note.id,
    );
    ref.read(canvasProvider.notifier).addCard(card);
  }

  Widget _buildViewModeSwitcher(ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    final shortcutService = ref.read(shortcutServiceProvider);
    final canvasShortcut =
        shortcutService.getShortcut('connect_canvas') ?? 'Ctrl+4';
    final graphShortcut =
        shortcutService.getShortcut('connect_graph') ?? 'Ctrl+5';
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          _viewModeTab(
            theme,
            ConnectViewMode.canvas,
            Icons.dashboard,
            l.canvas,
            canvasShortcut,
          ),
          _viewModeTab(
            theme,
            ConnectViewMode.graph,
            Icons.hub,
            l.graph,
            graphShortcut,
          ),
        ],
      ),
    );
  }

  Widget _viewModeTab(
    ThemeData theme,
    ConnectViewMode mode,
    IconData icon,
    String label,
    String shortcut,
  ) {
    final isActive = _viewMode == mode;
    return Expanded(
      child: Tooltip(
        message: '$label ($shortcut)',
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          onTap: () => setState(() => _viewMode = mode),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.hintColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.hintColor,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    shortcut,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isActive
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                    ),
                  ),
                ],
              ),
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

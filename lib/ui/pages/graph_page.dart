import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/knowledge_service.dart';
import '../../services/settings_service.dart';
import '../../data/models/note.dart';
import '../../data/models/link.dart';
import '../../data/models/link_type.dart';
import '../../data/stores/vault_store.dart';
import '../../core/graph/layout_engine.dart';
import '../../core/graph/filter_engine.dart';
import '../../core/graph/graph_algorithm.dart';
import '../../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import '../widgets/graph_stats_card.dart';

part 'graph/graph_painter.dart';
part 'graph/graph_overlays.dart';
part 'graph/graph_export.dart';
part 'graph/graph_toolbar.dart';
part 'graph/graph_layout.dart';

enum GraphLayoutMode { circular, forceDirected }

enum GraphViewMode { full, local }

class GraphView extends ConsumerStatefulWidget {
  const GraphView({super.key});

  @override
  ConsumerState<GraphView> createState() => _GraphViewState();
}

abstract class _GraphViewStateBase extends ConsumerState<GraphView> {
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  String? _hoveredNode;
  String? _selectedNode;
  final _graphKey = GlobalKey();
  final _graphPaintKey = GlobalKey();
  GraphLayoutMode _layoutMode = GraphLayoutMode.forceDirected;
  GraphViewMode _viewMode = GraphViewMode.full;
  String? _localGraphCenter;
  int _localGraphDepth = 2;
  Map<String, Offset>? _cachedLayout;
  String? _cachedLayoutKey;
  bool _showStats = false;
  bool _showLegend = false;

  static const double _nodeHitRadius = 22.0;

  @override
  Widget build(BuildContext context) {
    final knowledgeState = ref.watch(knowledgeProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final notes = knowledgeState.notes;

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.hub,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: DesignSpacing.lg),
            Text(l.knowledgeGraph, style: theme.textTheme.headlineMedium),
            const SizedBox(height: DesignSpacing.sm),
            Text(l.createLinkedNotesHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: DesignSpacing.xl),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(knowledgeProvider.notifier)
                    .createNote(title: l.newNote);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.newNote),
            ),
          ],
        ),
      );
    }

    final allLinks = <GraphLink>[];
    final allDataLinks = <Link>[];
    final linkCounts = <String, int>{};
    for (final link in knowledgeState.outlinks) {
      final key = '${link.sourceId}->${link.targetId}';
      linkCounts[key] = (linkCounts[key] ?? 0) + 1;
      if (!allLinks.any(
        (l) => l.sourceId == link.sourceId && l.targetId == link.targetId,
      )) {
        // Auto-discovered = wikilink ([[...]]); manual = reference/embed/webLink
        final isAuto = link.type == LinkType.wikilink;
        allLinks.add(
          GraphLink(
            sourceId: link.sourceId,
            targetId: link.targetId,
            isAuto: isAuto,
          ),
        );
        allDataLinks.add(link);
      }
    }
    for (final link in knowledgeState.backlinks) {
      final key = '${link.sourceId}->${link.targetId}';
      linkCounts[key] = (linkCounts[key] ?? 0) + 1;
      if (!allLinks.any(
        (l) => l.sourceId == link.sourceId && l.targetId == link.targetId,
      )) {
        // Backlinks inherit auto/manual from the original link direction
        final isAuto = link.type == LinkType.wikilink;
        allLinks.add(
          GraphLink(
            sourceId: link.sourceId,
            targetId: link.targetId,
            isAuto: isAuto,
          ),
        );
        allDataLinks.add(link);
      }
    }

    List<Note> displayNotes = notes;
    List<GraphLink> displayLinks = allLinks;
    List<Link> displayDataLinks = allDataLinks;

    if (_viewMode == GraphViewMode.local && _localGraphCenter != null) {
      final localResult = knowledgeState.notes.isNotEmpty
          ? _computeLocalGraph(knowledgeState)
          : null;
      if (localResult != null) {
        final localIds = localResult.notes.map((n) => n.id).toSet();
        displayNotes = localResult.notes;
        displayLinks = allLinks
            .where(
              (l) =>
                  localIds.contains(l.sourceId) &&
                  localIds.contains(l.targetId),
            )
            .toList();
        displayDataLinks = allDataLinks
            .where(
              (l) =>
                  localIds.contains(l.sourceId) &&
                  localIds.contains(l.targetId),
            )
            .toList();
      }
    }

    final algorithm = GraphAlgorithm(
      allNotes: displayNotes,
      allLinks: displayDataLinks,
    );
    final bridgeNodes = algorithm.getBridgeNodes();
    final bridgeIds = bridgeNodes.map((b) => b.noteId).toSet();
    final graphStats = algorithm.getGraphStats();

    final layoutKey =
        '${displayNotes.map((n) => n.id).join(",")}|${displayLinks.map((l) => '${l.sourceId}->${l.targetId}').join(",")}|$_layoutMode';
    if (_cachedLayoutKey != layoutKey) {
      _cachedLayout = _computeLayout(displayNotes, displayLinks);
      _cachedLayoutKey = layoutKey;
    }

    return Container(
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          MouseRegion(
            onHover: (details) {
              final size =
                  (_graphKey.currentContext?.findRenderObject() as RenderBox?)
                      ?.size ??
                  Size.zero;
              final layout = _cachedLayout;

              String? hovered;
              if (layout != null) {
                for (final entry in layout.entries) {
                  final pos = Offset(
                    entry.value.dx * _scale + size.width / 2 + _offset.dx,
                    entry.value.dy * _scale + size.height / 2 + _offset.dy,
                  );
                  final dist = (pos - details.localPosition).distance;
                  if (dist < _nodeHitRadius * _scale) {
                    hovered = entry.key;
                    break;
                  }
                }
              }
              if (hovered != _hoveredNode) {
                setState(() => _hoveredNode = hovered);
              }
            },
            child: GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_scale * details.scale).clamp(0.3, 3.0);
                  _offset += details.focalPointDelta;
                });
              },
              onTapUp: (details) {
                final size =
                    (_graphKey.currentContext?.findRenderObject() as RenderBox?)
                        ?.size ??
                    Size.zero;
                final layout = _cachedLayout;

                String? tappedNoteId;
                if (layout != null) {
                  for (final entry in layout.entries) {
                    final pos = Offset(
                      entry.value.dx * _scale + size.width / 2 + _offset.dx,
                      entry.value.dy * _scale + size.height / 2 + _offset.dy,
                    );
                    final dist = (pos - details.localPosition).distance;
                    if (dist < _nodeHitRadius * _scale) {
                      tappedNoteId = entry.key;
                      break;
                    }
                  }
                }

                if (tappedNoteId != null) {
                  final note = displayNotes
                      .where((n) => n.id == tappedNoteId)
                      .firstOrNull;
                  if (note != null) {
                    ref.read(knowledgeProvider.notifier).openNote(note.id);
                  }
                }
              },
              child: ClipRect(
                child: RepaintBoundary(
                  key: _graphPaintKey,
                  child: CustomPaint(
                    key: _graphKey,
                    painter: GraphPainter(
                      notes: displayNotes,
                      links: displayLinks,
                      scale: _scale,
                      offset: _offset,
                      layout: _cachedLayout,
                      hoveredNode: _hoveredNode,
                      selectedNode: _selectedNode,
                      bridgeIds: bridgeIds,
                      primaryColor: theme.colorScheme.primary,
                      secondaryColor: theme.colorScheme.secondary,
                      surfaceColor: theme.colorScheme.surface,
                      onSurfaceColor: theme.colorScheme.onSurface,
                      hintColor: theme.hintColor,
                      cardColor: theme.cardColor,
                      errorColor: theme.colorScheme.error,
                      baseFontSize:
                          ref.watch(settingsProvider).editorFontSize * 0.75,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          _buildToolbar(theme, l, displayNotes, displayLinks),
          if (_hoveredNode != null)
            Positioned(
              top: DesignSpacing.xl + DesignSpacing.md,
              left: DesignSpacing.md,
              child: _NodeTooltip(
                noteId: _hoveredNode!,
                notes: displayNotes,
                linkCount: _countLinks(displayLinks, _hoveredNode!),
              ),
            ),
          if (_showLegend)
            Positioned(
              top: DesignSpacing.xl + DesignSpacing.md,
              right: DesignSpacing.md,
              child: _GraphLegend(theme: theme),
            ),
          if (_showStats)
            Positioned(
              top: 60,
              right: DesignSpacing.md,
              child: GraphStatsCard(stats: graphStats),
            ),
          if (_viewMode == GraphViewMode.local)
            Positioned(
              bottom: DesignSpacing.md,
              left: DesignSpacing.md,
              child: Material(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(DesignRadius.md),
                elevation: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Depth: ', style: theme.textTheme.bodySmall),
                    Slider(
                      value: _localGraphDepth.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_localGraphDepth',
                      onChanged: (v) => setState(() {
                        _localGraphDepth = v.toInt();
                        _cachedLayoutKey = null;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          if (bridgeNodes.isNotEmpty)
            Positioned(
              bottom: DesignSpacing.md,
              right: DesignSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignSpacing.md,
                  vertical: DesignSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: theme.colorScheme.error),
                    const SizedBox(width: DesignSpacing.xs),
                    Text(
                      '${bridgeNodes.length} bridge nodes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Abstract declarations for cross-mixin method calls
  int _countLinks(List<GraphLink> links, String noteId);
  LocalGraphResult? _computeLocalGraph(KnowledgeState knowledgeState);
  Map<String, Offset>? _computeLayout(List<Note> notes, List<GraphLink> links);

  void _handleGraphExport(
    String format,
    List<Note> displayNotes,
    List<GraphLink> displayLinks,
  );

  Widget _buildToolbar(
    ThemeData theme,
    AppLocalizations l,
    List<Note> displayNotes,
    List<GraphLink> displayLinks,
  );
}

class _GraphViewState extends _GraphViewStateBase
    with _GraphExportMixin, _GraphToolbarMixin, _GraphLayoutMixin {}

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/gestures.dart';
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
import '../../data/models/graph_stat.dart';
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
  bool _isComputingLayout = false;
  bool _showStats = false;
  bool _showLegend = false;

  // Hover throttling — defers the O(n) hit-test to ~30fps so rapid mouse
  // movement does not flood the frame loop with setState calls.
  Timer? _hoverThrottle;
  Offset? _pendingHoverPosition;

  // Memoized derived lists. Rebuilt only when the underlying knowledgeState
  // references change (identical() check) so that shouldRepaint returns false
  // on hover/zoom setState and the painter is not needlessly repainted.
  List<GraphLink> _cachedAllLinks = const [];
  List<Link> _cachedAllDataLinks = const [];
  List<Link>? _allLinksOutlinksRef;
  List<Link>? _allLinksBacklinksRef;

  List<Note> _cachedDisplayNotes = const [];
  List<GraphLink> _cachedDisplayLinks = const [];
  List<Link> _cachedDisplayDataLinks = const [];
  List<Note>? _displayNotesRef;
  List<GraphLink>? _displayLinksRef;
  GraphViewMode? _displayViewMode;
  String? _displayLocalCenter;
  int? _displayLocalDepth;

  // Memoized bridge node ids + graph stats (Tarjan DFS / BFS). Only recomputed
  // when (displayNotes, displayDataLinks) reference identity changes.
  Set<String> _cachedBridgeIds = const {};
  List<Note>? _bridgeNotesRef;
  List<Link>? _bridgeLinksRef;
  GraphStats? _cachedGraphStats;
  List<Note>? _statsNotesRef;
  List<Link>? _statsLinksRef;

  static const double _nodeHitRadius = 22.0;

  @override
  void dispose() {
    _hoverThrottle?.cancel();
    super.dispose();
  }

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

    final outlinks = knowledgeState.outlinks;
    final backlinks = knowledgeState.backlinks;

    // Build allLinks/allDataLinks only when the source link lists change.
    // Uses a Set for O(1) dedup instead of O(n²) allLinks.any(...) per link.
    if (!identical(_allLinksOutlinksRef, outlinks) ||
        !identical(_allLinksBacklinksRef, backlinks)) {
      _allLinksOutlinksRef = outlinks;
      _allLinksBacklinksRef = backlinks;
      final seen = <String>{};
      final allLinks = <GraphLink>[];
      final allDataLinks = <Link>[];
      for (final link in outlinks) {
        final key = '${link.sourceId}->${link.targetId}';
        if (seen.add(key)) {
          // Auto-discovered = wikilink ([[...]]); manual = reference/embed/webLink
          allLinks.add(
            GraphLink(
              sourceId: link.sourceId,
              targetId: link.targetId,
              isAuto: link.type == LinkType.wikilink,
            ),
          );
          allDataLinks.add(link);
        }
      }
      for (final link in backlinks) {
        final key = '${link.sourceId}->${link.targetId}';
        if (seen.add(key)) {
          // Backlinks inherit auto/manual from the original link direction
          allLinks.add(
            GraphLink(
              sourceId: link.sourceId,
              targetId: link.targetId,
              isAuto: link.type == LinkType.wikilink,
            ),
          );
          allDataLinks.add(link);
        }
      }
      _cachedAllLinks = allLinks;
      _cachedAllDataLinks = allDataLinks;
    }
    final allLinks = _cachedAllLinks;
    final allDataLinks = _cachedAllDataLinks;

    // Derive displayNotes/displayLinks only when notes, allLinks, viewMode,
    // localGraphCenter or localGraphDepth change (keeps list references stable
    // so shouldRepaint returns false on hover/zoom setState).
    if (!identical(_displayNotesRef, notes) ||
        !identical(_displayLinksRef, allLinks) ||
        _displayViewMode != _viewMode ||
        _displayLocalCenter != _localGraphCenter ||
        _displayLocalDepth != _localGraphDepth) {
      _displayNotesRef = notes;
      _displayLinksRef = allLinks;
      _displayViewMode = _viewMode;
      _displayLocalCenter = _localGraphCenter;
      _displayLocalDepth = _localGraphDepth;
      if (_viewMode == GraphViewMode.local && _localGraphCenter != null) {
        final localResult = notes.isNotEmpty
            ? _computeLocalGraph(knowledgeState)
            : null;
        if (localResult != null) {
          final localIds = localResult.notes.map((n) => n.id).toSet();
          _cachedDisplayNotes = localResult.notes;
          _cachedDisplayLinks = allLinks
              .where(
                (l) =>
                    localIds.contains(l.sourceId) &&
                    localIds.contains(l.targetId),
              )
              .toList();
          _cachedDisplayDataLinks = allDataLinks
              .where(
                (l) =>
                    localIds.contains(l.sourceId) &&
                    localIds.contains(l.targetId),
              )
              .toList();
        } else {
          _cachedDisplayNotes = notes;
          _cachedDisplayLinks = allLinks;
          _cachedDisplayDataLinks = allDataLinks;
        }
      } else {
        _cachedDisplayNotes = notes;
        _cachedDisplayLinks = allLinks;
        _cachedDisplayDataLinks = allDataLinks;
      }
    }
    final displayNotes = _cachedDisplayNotes;
    final displayLinks = _cachedDisplayLinks;
    final displayDataLinks = _cachedDisplayDataLinks;

    // Bridge nodes (Tarjan DFS) — memoized on (displayNotes, displayDataLinks)
    // so the O(V+E) traversal does not re-run on every hover/zoom setState.
    if (!identical(_bridgeNotesRef, displayNotes) ||
        !identical(_bridgeLinksRef, displayDataLinks)) {
      _bridgeNotesRef = displayNotes;
      _bridgeLinksRef = displayDataLinks;
      final algorithm = GraphAlgorithm(
        allNotes: displayNotes,
        allLinks: displayDataLinks,
      );
      _cachedBridgeIds =
          algorithm.getBridgeNodes().map((b) => b.noteId).toSet();
      // Invalidate stats cache since the underlying graph changed.
      _statsNotesRef = null;
    }
    final bridgeIds = _cachedBridgeIds;

    // Graph stats (BFS) — only computed when the stats panel is visible.
    GraphStats? graphStats;
    if (_showStats) {
      if (!identical(_statsNotesRef, displayNotes) ||
          !identical(_statsLinksRef, displayDataLinks)) {
        _statsNotesRef = displayNotes;
        _statsLinksRef = displayDataLinks;
        final algorithm = GraphAlgorithm(
          allNotes: displayNotes,
          allLinks: displayDataLinks,
        );
        _cachedGraphStats = algorithm.getGraphStats();
      }
      graphStats = _cachedGraphStats;
    }

    final layoutKey =
        '${displayNotes.map((n) => n.id).join(",")}|${displayLinks.map((l) => '${l.sourceId}->${l.targetId}').join(",")}|$_layoutMode';
    // Layout computation runs in a worker isolate for large graphs (Issue 1);
    // kick it off async and rebuild when done so the UI thread never blocks.
    if (_cachedLayoutKey != layoutKey && !_isComputingLayout) {
      _isComputingLayout = true;
      _computeLayout(displayNotes, displayLinks).then((layout) {
        _isComputingLayout = false;
        _cachedLayout = layout;
        _cachedLayoutKey = layoutKey;
        if (mounted) setState(() {});
      });
    }

    return Container(
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          MouseRegion(
            onHover: _scheduleHoverCheck,
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
              child: GraphStatsCard(stats: graphStats!),
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
          if (bridgeIds.isNotEmpty)
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
                      '${bridgeIds.length} bridge nodes',
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
  Future<Map<String, Offset>?> _computeLayout(
    List<Note> notes,
    List<GraphLink> links,
  );

  /// Throttles the hover hit-test to ~30fps (33ms) so rapid mouse movement
  /// does not trigger an O(n) scan + setState on every PointerHoverEvent.
  void _scheduleHoverCheck(PointerHoverEvent details) {
    _pendingHoverPosition = details.localPosition;
    if (_hoverThrottle?.isActive ?? false) return;
    _hoverThrottle = Timer(const Duration(milliseconds: 33), _processPendingHover);
  }

  void _processPendingHover() {
    final position = _pendingHoverPosition;
    if (position == null) return;
    _pendingHoverPosition = null;
    final size =
        (_graphKey.currentContext?.findRenderObject() as RenderBox?)?.size ??
        Size.zero;
    final layout = _cachedLayout;

    String? hovered;
    if (layout != null) {
      for (final entry in layout.entries) {
        final pos = Offset(
          entry.value.dx * _scale + size.width / 2 + _offset.dx,
          entry.value.dy * _scale + size.height / 2 + _offset.dy,
        );
        final dist = (pos - position).distance;
        if (dist < _nodeHitRadius * _scale) {
          hovered = entry.key;
          break;
        }
      }
    }
    if (hovered != _hoveredNode) {
      setState(() => _hoveredNode = hovered);
    }
  }

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

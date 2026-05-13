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
import '../../data/stores/vault_store.dart';
import '../../core/graph/layout_engine.dart';
import '../../core/graph/filter_engine.dart';
import '../../core/graph/graph_algorithm.dart';
import '../../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import '../widgets/graph_stats_card.dart';

enum GraphLayoutMode { circular, forceDirected }

enum GraphViewMode { full, local }

class GraphView extends ConsumerStatefulWidget {
  const GraphView({super.key});

  @override
  ConsumerState<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends ConsumerState<GraphView> {
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
                ref.read(knowledgeProvider.notifier).createNote(
                  title: l.newNote,
                );
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
        allLinks.add(
          GraphLink(sourceId: link.sourceId, targetId: link.targetId),
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
        allLinks.add(
          GraphLink(sourceId: link.sourceId, targetId: link.targetId),
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
                    baseFontSize: ref.watch(settingsProvider).editorFontSize * 0.75,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          ),
          Positioned(
            top: DesignSpacing.md,
            left: DesignSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSpacing.md,
                vertical: DesignSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(DesignRadius.md),
                boxShadow: [DesignShadow.sm],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hub, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: DesignSpacing.sm),
                  Text(
                    l.noteCount(displayNotes.length),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: DesignSpacing.sm),
                  IconButton(
                    icon: Icon(
                      _layoutMode == GraphLayoutMode.forceDirected
                          ? Icons.scatter_plot
                          : Icons.circle,
                      size: 14,
                    ),
                    onPressed: () => setState(() {
                      _layoutMode = _layoutMode == GraphLayoutMode.forceDirected
                          ? GraphLayoutMode.circular
                          : GraphLayoutMode.forceDirected;
                      _cachedLayoutKey = null;
                    }),
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                    tooltip: _layoutMode == GraphLayoutMode.forceDirected
                        ? 'Switch to circular'
                        : l.switchToForceLayout,
                  ),
                  IconButton(
                    icon: Icon(
                      _viewMode == GraphViewMode.full
                          ? Icons.account_tree
                          : Icons.hub,
                      size: 14,
                    ),
                    onPressed: () => setState(() {
                      _viewMode = _viewMode == GraphViewMode.full
                          ? GraphViewMode.local
                          : GraphViewMode.full;
                      if (_viewMode == GraphViewMode.local &&
                          _localGraphCenter == null) {
                        _localGraphCenter =
                            knowledgeState.activeNote?.id ?? notes.first.id;
                      }
                      _cachedLayoutKey = null;
                    }),
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                    tooltip: _viewMode == GraphViewMode.full
                        ? l.localGraph
                        : 'Full graph',
                  ),
                  const SizedBox(width: DesignSpacing.xs),
                  IconButton(
                    icon: Icon(
                      _showStats ? Icons.analytics : Icons.analytics_outlined,
                      size: 16,
                    ),
                    onPressed: () => setState(() => _showStats = !_showStats),
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                    tooltip: 'Toggle statistics',
                  ),
                  IconButton(
                    icon: Icon(
                      _showLegend ? Icons.legend_toggle : Icons.legend_toggle_outlined,
                      size: 16,
                    ),
                    onPressed: () => setState(() => _showLegend = !_showLegend),
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                    tooltip: 'Toggle legend',
                  ),
                  const SizedBox(width: DesignSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, size: 16),
                    onPressed: () =>
                        setState(() => _scale = (_scale * 1.2).clamp(0.3, 3.0)),
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, size: 16),
                    onPressed: () =>
                        setState(() => _scale = (_scale / 1.2).clamp(0.3, 3.0)),
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    onPressed: () => setState(() {
                      _offset = Offset.zero;
                      _scale = 1.0;
                    }),
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                  ),
                  const SizedBox(width: DesignSpacing.xs),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.file_download, size: 16),
                    tooltip: l.export,
                    constraints: const BoxConstraints(
                      minWidth: DesignTouchTarget.iconButtonSize,
                      minHeight: DesignTouchTarget.iconButtonSize,
                    ),
                    onSelected: (value) => _handleGraphExport(value, displayNotes, displayLinks),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'png',
                        child: Row(
                          children: [
                            Icon(Icons.image, size: 14, color: theme.hintColor),
                            const SizedBox(width: 8),
                            Text(l.exportGraphPng),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'svg',
                        child: Row(
                          children: [
                            Icon(Icons.code, size: 14, color: theme.hintColor),
                            const SizedBox(width: 8),
                            Text(l.exportGraphSvg),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'json',
                        child: Row(
                          children: [
                            Icon(Icons.data_object, size: 14, color: theme.hintColor),
                            const SizedBox(width: 8),
                            Text(l.exportGraphJson),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignSpacing.md,
                  vertical: DesignSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                  boxShadow: [DesignShadow.sm],
                ),
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

  int _countLinks(List<GraphLink> links, String noteId) {
    return links
        .where((l) => l.sourceId == noteId || l.targetId == noteId)
        .length;
  }

  LocalGraphResult? _computeLocalGraph(KnowledgeState knowledgeState) {
    return ref
        .read(knowledgeProvider.notifier)
        .getLocalGraph(_localGraphCenter!, depth: _localGraphDepth);
  }

  Map<String, Offset>? _computeLayout(List<Note> notes, List<GraphLink> links) {
    if (notes.isEmpty) return null;

    if (_layoutMode == GraphLayoutMode.circular) {
      final positions = <String, Offset>{};
      for (var i = 0; i < notes.length; i++) {
        final angle = (i / notes.length) * 2 * pi;
        final radius = 80.0 * (1 + (i % 3) * 0.5);
        positions[notes[i].id] = Offset(
          radius * cos(angle),
          radius * sin(angle),
        );
      }
      return positions;
    }

    final linkCounts = <String, int>{};
    for (final l in links) {
      final key = '${l.sourceId}->${l.targetId}';
      linkCounts[key] = (linkCounts[key] ?? 0) + 1;
    }

    final layoutNodes = notes.map((n) => LayoutNode(id: n.id)).toList();
    final layoutEdges = links.map((l) {
      final key = '${l.sourceId}->${l.targetId}';
      final weight = linkCounts[key]?.toDouble() ?? 1.0;
      return LayoutEdge(
        sourceId: l.sourceId,
        targetId: l.targetId,
        weight: weight,
      );
    }).toList();

    final layout = ForceDirectedLayout.adaptive(notes.length, seed: 42);
    final result = layout.compute(layoutNodes, layoutEdges);
    return result.positions;
  }

  void _handleGraphExport(
    String format,
    List<Note> displayNotes,
    List<GraphLink> displayLinks,
  ) {
    switch (format) {
      case 'png':
        _exportGraphToPng();
      case 'svg':
        _exportGraphToSvg(displayNotes, displayLinks);
      case 'json':
        _exportGraphToJson(displayNotes, displayLinks);
    }
  }

  Future<void> _exportGraphToPng() async {
    final l = AppLocalizations.of(context)!;
    try {
      final boundary = _graphPaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.exportFailedNotRendered)),
          );
        }
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.exportFailedPng)),
          );
        }
        return;
      }
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
      final dir = Directory('$vaultPath/attachments');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/graph_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      image.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.exportedTo(file.path)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.pngExportFailed('$e'))),
        );
      }
    }
  }

  void _exportGraphToSvg(List<Note> displayNotes, List<GraphLink> displayLinks) {
    final l = AppLocalizations.of(context)!;
    final layout = _cachedLayout;
    if (layout == null || displayNotes.isEmpty) return;

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final hintColor = theme.hintColor;
    final surfaceColor = theme.colorScheme.surface;

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final pos in layout.values) {
      if (pos.dx - 30 < minX) minX = pos.dx - 30;
      if (pos.dy - 30 < minY) minY = pos.dy - 30;
      if (pos.dx + 30 > maxX) maxX = pos.dx + 30;
      if (pos.dy + 30 > maxY) maxY = pos.dy + 30;
    }
    if (minX == double.infinity) { minX = 0; minY = 0; maxX = 400; maxY = 400; }
    final padding = 20.0;
    final width = maxX - minX + padding * 2;
    final height = maxY - minY + padding * 2;

    final svgBuffer = StringBuffer();
    svgBuffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    svgBuffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="${minX - padding} ${minY - padding} $width $height">');
    svgBuffer.writeln('  <rect x="${minX - padding}" y="${minY - padding}" width="$width" height="$height" fill="${_colorToHex(surfaceColor)}" />');

    for (final link in displayLinks) {
      final fromPos = layout[link.sourceId];
      final toPos = layout[link.targetId];
      if (fromPos == null || toPos == null) continue;
      svgBuffer.writeln('  <line x1="${fromPos.dx}" y1="${fromPos.dy}" x2="${toPos.dx}" y2="${toPos.dy}" stroke="${_colorToHex(hintColor)}" stroke-width="1" opacity="0.4" />');
    }

    for (final note in displayNotes) {
      final pos = layout[note.id];
      if (pos == null) continue;
      final r = 8.0;
      svgBuffer.writeln('  <circle cx="${pos.dx}" cy="${pos.dy}" r="$r" fill="${_colorToHex(primaryColor)}" />');
      final escapedTitle = note.title.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
      svgBuffer.writeln('  <text x="${pos.dx}" y="${pos.dy + r + 12}" text-anchor="middle" font-size="10" fill="${_colorToHex(hintColor)}">$escapedTitle</text>');
    }

    svgBuffer.writeln('</svg>');

    _saveGraphExportFile('graph_${DateTime.now().millisecondsSinceEpoch}.svg', svgBuffer.toString(), l);
  }

  void _exportGraphToJson(List<Note> displayNotes, List<GraphLink> displayLinks) {
    final l = AppLocalizations.of(context)!;
    final layout = _cachedLayout;

    final nodes = displayNotes.map((n) => {
      'id': n.id,
      'title': n.title,
      'tags': n.tags,
      if (layout != null && layout.containsKey(n.id)) 'position': {
        'x': layout[n.id]!.dx,
        'y': layout[n.id]!.dy,
      },
    }).toList();

    final edges = displayLinks.map((e) => {
      'source': e.sourceId,
      'target': e.targetId,
    }).toList();

    final data = JsonEncoder.withIndent('  ').convert({
      'nodes': nodes,
      'edges': edges,
      'exportedAt': DateTime.now().toIso8601String(),
    });

    _saveGraphExportFile('graph_${DateTime.now().millisecondsSinceEpoch}.json', data, l);
  }

  void _saveGraphExportFile(String filename, String content, AppLocalizations l) async {
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
      final dir = Directory('$vaultPath/attachments');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.exportedTo(file.path)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

class _NodeTooltip extends StatelessWidget {
  final String noteId;
  final List<Note> notes;
  final int linkCount;

  const _NodeTooltip({
    required this.noteId,
    required this.notes,
    required this.linkCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = notes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSpacing.md,
        vertical: DesignSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(DesignRadius.md),
        boxShadow: [DesignShadow.md],
      ),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            note.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DesignSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 12, color: theme.hintColor),
              const SizedBox(width: DesignSpacing.xs),
              Text(
                '$linkCount connections',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: DesignSpacing.xs),
            Wrap(
              spacing: DesignSpacing.xs,
              children: note.tags
                  .take(3)
                  .map(
                    (tag) => Text(
                      '#$tag',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _GraphLegend extends StatelessWidget {
  final ThemeData theme;

  const _GraphLegend({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(DesignRadius.md),
        boxShadow: [DesignShadow.sm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Legend',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DesignSpacing.sm),
          _legendItem(theme.colorScheme.primary, 'Normal node'),
          _legendItem(theme.colorScheme.secondary, 'Hovered node'),
          _legendItem(theme.colorScheme.error, 'Bridge node (critical path)'),
          const SizedBox(height: DesignSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text('Small = few links', style: theme.textTheme.labelSmall),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text('Large = many links', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: DesignSpacing.sm),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class GraphLink {
  final String sourceId;
  final String targetId;
  GraphLink({required this.sourceId, required this.targetId});
}

class GraphPainter extends CustomPainter {
  final List<Note> notes;
  final List<GraphLink> links;
  final double scale;
  final Offset offset;
  final Map<String, Offset>? layout;
  final String? hoveredNode;
  final String? selectedNode;
  final Set<String> bridgeIds;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;
  final Color hintColor;
  final Color cardColor;
  final Color errorColor;
  final double baseFontSize;

  GraphPainter({
    required this.notes,
    required this.links,
    required this.scale,
    required this.offset,
    this.layout,
    this.hoveredNode,
    this.selectedNode,
    this.bridgeIds = const {},
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
    required this.hintColor,
    required this.cardColor,
    required this.errorColor,
    this.baseFontSize = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty) return;

    final centerX = size.width / 2 + offset.dx;
    final centerY = size.height / 2 + offset.dy;
    final nodePositions = <String, Offset>{};
    final nodeRadius = 6.0 * scale;

    final linkCount = <String, int>{};
    for (final link in links) {
      linkCount[link.sourceId] = (linkCount[link.sourceId] ?? 0) + 1;
      linkCount[link.targetId] = (linkCount[link.targetId] ?? 0) + 1;
    }

    if (layout != null) {
      for (final entry in layout!.entries) {
        nodePositions[entry.key] = Offset(
          entry.value.dx * scale + centerX,
          entry.value.dy * scale + centerY,
        );
      }
    } else {
      final spacing = 80.0 * scale;
      for (var i = 0; i < notes.length; i++) {
        final angle = (i / notes.length) * 2 * pi;
        final radius = spacing * (1 + (i % 3) * 0.5);
        final x = centerX + radius * cos(angle);
        final y = centerY + radius * sin(angle);
        nodePositions[notes[i].id] = Offset(x, y);
      }
    }

    final edgePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..strokeWidth = 1.0 * scale
      ..style = PaintingStyle.stroke;

    for (final link in links) {
      final sourcePos = nodePositions[link.sourceId];
      final targetPos = nodePositions[link.targetId];
      if (sourcePos != null && targetPos != null) {
        canvas.drawLine(sourcePos, targetPos, edgePaint);
      }
    }

    final redColor = errorColor;

    for (final note in notes) {
      final pos = nodePositions[note.id];
      if (pos == null) continue;

      final connections = linkCount[note.id] ?? 0;
      final r = (nodeRadius + connections * 1.5).clamp(
        nodeRadius,
        nodeRadius * 3,
      );
      final isHovered = hoveredNode == note.id;
      final isSelected = selectedNode == note.id;
      final isBridge = bridgeIds.contains(note.id);

      final nodePaint = Paint()
        ..color = isBridge
            ? redColor
            : isSelected
            ? primaryColor
            : isHovered
            ? secondaryColor
            : primaryColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;

      final bridgePaint = Paint()
        ..color = redColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;

      if (isHovered) {
        final hoverPaint = Paint()
          ..color = secondaryColor.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, _GraphViewState._nodeHitRadius * scale, hoverPaint);
      }

      if (isBridge) {
        canvas.drawCircle(pos, r * 1.8, bridgePaint);
      } else if (connections > 2) {
        canvas.drawCircle(pos, r * 2, glowPaint);
      }
      canvas.drawCircle(pos, r, nodePaint);

      if (isBridge && scale > 0.4) {
        final starSpan = TextSpan(
          text: '\u2605',
          style: TextStyle(
            color: redColor,
            fontSize: (baseFontSize * 1.2 * scale).clamp(8, 16),
          ),
        );
        final starPainter = TextPainter(
          text: starSpan,
          textDirection: TextDirection.ltr,
        );
        starPainter.layout();
        starPainter.paint(
          canvas,
          Offset(
            pos.dx - starPainter.width / 2,
            pos.dy - r - starPainter.height,
          ),
        );
      }

      if (scale > 0.5) {
        final textSpan = TextSpan(
          text: note.title,
          style: TextStyle(
            color: isSelected
                ? primaryColor
                : isBridge
                ? redColor
                : onSurfaceColor.withValues(alpha: 0.8),
            fontSize: (baseFontSize * scale).clamp(8, 14),
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout(maxWidth: 100 * scale);
        textPainter.paint(
          canvas,
          Offset(pos.dx - textPainter.width / 2, pos.dy + r + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) =>
      oldDelegate.notes != notes ||
      oldDelegate.links != links ||
      oldDelegate.scale != scale ||
      oldDelegate.offset != offset ||
      oldDelegate.layout != layout ||
      oldDelegate.hoveredNode != hoveredNode ||
      oldDelegate.selectedNode != selectedNode ||
      oldDelegate.bridgeIds != bridgeIds;
}

// ignore_for_file: unused_element, unused_element_parameter

part of '../graph_page.dart';

/// Top-level isolate entry point for JSON serialization of the graph.
///
/// Runs `JsonEncoder.withIndent` off the UI thread so that large graphs
/// (hundreds of nodes/edges) do not block the frame loop (Rule 6.1).
String _encodeGraphJson(Map<String, dynamic> data) {
  return JsonEncoder.withIndent('  ').convert(data);
}

/// Mixin providing graph export functionality (PNG / SVG / JSON).
mixin _GraphExportMixin on _GraphViewStateBase {
  @override
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
      final boundary =
          _graphPaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.exportFailedNotRendered)));
        }
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.exportFailedPng)));
        }
        return;
      }
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
      final dir = Directory('$vaultPath/attachments');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(
        '${dir.path}/graph_${DateTime.now().millisecondsSinceEpoch}.png',
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.pngExportFailed('$e'))));
      }
    }
  }

  void _exportGraphToSvg(
    List<Note> displayNotes,
    List<GraphLink> displayLinks,
  ) {
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
    if (minX == double.infinity) {
      minX = 0;
      minY = 0;
      maxX = 400;
      maxY = 400;
    }
    final padding = 20.0;
    final width = maxX - minX + padding * 2;
    final height = maxY - minY + padding * 2;

    final svgBuffer = StringBuffer();
    svgBuffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    svgBuffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="${minX - padding} ${minY - padding} $width $height">',
    );
    svgBuffer.writeln(
      '  <rect x="${minX - padding}" y="${minY - padding}" width="$width" height="$height" fill="${_colorToHex(surfaceColor)}" />',
    );

    for (final link in displayLinks) {
      final fromPos = layout[link.sourceId];
      final toPos = layout[link.targetId];
      if (fromPos == null || toPos == null) continue;
      svgBuffer.writeln(
        '  <line x1="${fromPos.dx}" y1="${fromPos.dy}" x2="${toPos.dx}" y2="${toPos.dy}" stroke="${_colorToHex(hintColor)}" stroke-width="1" opacity="0.4" />',
      );
    }

    for (final note in displayNotes) {
      final pos = layout[note.id];
      if (pos == null) continue;
      final r = 8.0;
      svgBuffer.writeln(
        '  <circle cx="${pos.dx}" cy="${pos.dy}" r="$r" fill="${_colorToHex(primaryColor)}" />',
      );
      final escapedTitle = note.title
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      svgBuffer.writeln(
        '  <text x="${pos.dx}" y="${pos.dy + r + 12}" text-anchor="middle" font-size="10" fill="${_colorToHex(hintColor)}">$escapedTitle</text>',
      );
    }

    svgBuffer.writeln('</svg>');

    _saveGraphExportFile(
      'graph_${DateTime.now().millisecondsSinceEpoch}.svg',
      svgBuffer.toString(),
      l,
    );
  }

  Future<void> _exportGraphToJson(
    List<Note> displayNotes,
    List<GraphLink> displayLinks,
  ) async {
    final l = AppLocalizations.of(context)!;
    final layout = _cachedLayout;

    final nodes = displayNotes
        .map(
          (n) => {
            'id': n.id,
            'title': n.title,
            'tags': n.tags,
            if (layout != null && layout.containsKey(n.id))
              'position': {'x': layout[n.id]!.dx, 'y': layout[n.id]!.dy},
          },
        )
        .toList();

    final edges = displayLinks
        .map((e) => {'source': e.sourceId, 'target': e.targetId})
        .toList();

    final data = <String, dynamic>{
      'nodes': nodes,
      'edges': edges,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    // JSON encoding (with indentation) of large graphs can take >100ms;
    // run it in a worker isolate to keep the UI thread free (Rule 6.1).
    final json = await compute(_encodeGraphJson, data);

    _saveGraphExportFile(
      'graph_${DateTime.now().millisecondsSinceEpoch}.json',
      json,
      l,
    );
  }

  void _saveGraphExportFile(
    String filename,
    String content,
    AppLocalizations l,
  ) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

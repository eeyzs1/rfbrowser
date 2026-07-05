import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../data/models/canvas_model.dart';

/// Serializable input for the SVG export isolate.
class _SvgExportInput {
  final CanvasData data;
  final String canvasName;
  const _SvgExportInput(this.data, this.canvasName);
}

/// Top-level XML escape helper (used by both instance and isolate code paths).
String _xmlEscape(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Top-level function executed in a worker isolate via [compute].
/// Generates the SVG string off the UI thread.
String _exportToSvgIsolate(_SvgExportInput input) {
  final data = input.data;
  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  double minX = double.infinity,
      minY = double.infinity,
      maxX = double.negativeInfinity,
      maxY = double.negativeInfinity;
  for (final card in data.cards) {
    minX = minX < card.x ? minX : card.x;
    minY = minY < card.y ? minY : card.y;
    final rx = card.x + card.width;
    final ry = card.y + card.height;
    maxX = maxX > rx ? maxX : rx;
    maxY = maxY > ry ? maxY : ry;
  }
  if (minX == double.infinity) {
    minX = 0;
    minY = 0;
    maxX = 800;
    maxY = 600;
  }
  final pad = 40.0;
  final w = maxX - minX + pad * 2;
  final h = maxY - minY + pad * 2;
  buffer.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="${minX - pad} ${minY - pad} $w $h">',
  );
  // Issue 15a: Build cardById map once instead of O(n) per connection.
  final cardById = {for (final c in data.cards) c.id: c};
  for (final conn in data.connections) {
    final from = cardById[conn.fromCardId];
    final to = cardById[conn.toCardId];
    if (from == null || to == null) continue;
    final (fs, ts) = CanvasConnection.computeSides(from, to);
    final fp = fs.point(from.rect, conn.fromSideOffset);
    final tp = ts.point(to.rect, conn.toSideOffset);
    buffer.writeln(
      '<line x1="${fp.dx}" y1="${fp.dy}" x2="${tp.dx}" y2="${tp.dy}" stroke="#666" stroke-width="2"/>',
    );
    if (conn.label.isNotEmpty) {
      final mx = (fp.dx + tp.dx) / 2;
      final my = (fp.dy + tp.dy) / 2;
      buffer.writeln(
        '<text x="$mx" y="$my" text-anchor="middle" font-size="12" fill="#666">${_xmlEscape(conn.label)}</text>',
      );
    }
  }
  for (final card in data.cards) {
    final hex =
        '#${(card.colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final strokeHex =
        '#${(card.style?.borderColor ?? 0xFFE0E0E0 & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final r = card.style?.borderRadius ?? 8.0;
    buffer.writeln(
      '<rect x="${card.x}" y="${card.y}" width="${card.width}" height="${card.height}" rx="$r" fill="$hex" stroke="$strokeHex" stroke-width="1"/>',
    );
    if (card.title.isNotEmpty) {
      buffer.writeln(
        '<text x="${card.x + 12}" y="${card.y + 20}" font-size="14" font-weight="bold" fill="#333">${_xmlEscape(card.title)}</text>',
      );
    }
    if (card.content.isNotEmpty) {
      final lines = card.content.split('\n').take(5);
      var cy = card.y + 40;
      for (final line in lines) {
        buffer.writeln(
          '<text x="${card.x + 12}" y="$cy" font-size="12" fill="#666">${_xmlEscape(line)}</text>',
        );
        cy += 16;
      }
    }
  }
  buffer.writeln('</svg>');
  return buffer.toString();
}

class CanvasExportService {
  const CanvasExportService();

  /// Issue 15b: Runs SVG generation in a worker isolate via [compute].
  Future<String> exportToSvg(CanvasData data, String canvasName) {
    return compute(_exportToSvgIsolate, _SvgExportInput(data, canvasName));
  }

  Future<String> exportToPdf(CanvasData data, String canvasName) {
    return exportToSvg(data, canvasName);
  }

  String exportToMarkdown(CanvasData data, String canvasName) {
    final buffer = StringBuffer();
    buffer.writeln('# Canvas: $canvasName');
    buffer.writeln();
    buffer.writeln('## Cards');
    buffer.writeln();
    buffer.writeln('| # | Type | Title | Position | Layer |');
    buffer.writeln('|---|------|-------|----------|-------|');
    // Issue 16: Build layer name lookup once instead of O(n) per card.
    final layerNameById = {for (final l in data.layers) l.id: l.name};
    // Issue 15a: Build cardById map once for connection title lookups.
    final cardById = {for (final c in data.cards) c.id: c};
    for (int i = 0; i < data.cards.length; i++) {
      final c = data.cards[i];
      final layerName = c.layerId != null
          ? (layerNameById[c.layerId] ?? '-')
          : '-';
      buffer.writeln(
        '| ${i + 1} | ${c.type.label} | ${c.title} | (${c.x.round()}, ${c.y.round()}) | $layerName |',
      );
    }
    buffer.writeln();
    buffer.writeln('## Connections');
    buffer.writeln();
    for (final conn in data.connections) {
      final from = cardById[conn.fromCardId]?.title ?? conn.fromCardId;
      final to = cardById[conn.toCardId]?.title ?? conn.toCardId;
      final label = conn.label.isNotEmpty ? ' "${conn.label}"' : '';
      buffer.writeln('- $from →$label $to ${conn.isAuto ? "(auto)" : ""}');
    }
    return buffer.toString();
  }

  String exportToHtml(CanvasData data) {
    final sb = StringBuffer();
    sb.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
    sb.writeln('<title>Canvas Export</title>');
    sb.writeln(
      '<style>body{margin:0;background:#f5f5f5;display:flex;justify-content:center;align-items:center;min-height:100vh}',
    );
    sb.writeln(
      '.card{position:absolute;border:1px solid #ddd;border-radius:8px;padding:8px;background:white;font-family:sans-serif;font-size:13px}',
    );
    sb.writeln(
      '.conn{stroke:#333;stroke-width:2;fill:none}</style></head><body>',
    );
    sb.writeln(
      '<svg width="1200" height="800" style="position:absolute;top:0;left:0">',
    );
    // Issue 15a: Build cardById map once instead of O(n) per connection.
    final cardById = {for (final c in data.cards) c.id: c};
    for (final conn in data.connections) {
      final from = cardById[conn.fromCardId];
      final to = cardById[conn.toCardId];
      if (from == null || to == null) continue;
      final fx = from.x + from.width * from.connectionPointOffsetX;
      final fy = from.y + from.height * from.connectionPointOffsetY;
      final tx = to.x + to.width * to.connectionPointOffsetX;
      final ty = to.y + to.height * to.connectionPointOffsetY;
      sb.writeln('<line x1="$fx" y1="$fy" x2="$tx" y2="$ty" class="conn"/>');
    }
    sb.writeln('</svg>');
    for (final card in data.cards) {
      final bg =
          '#${(card.colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      sb.writeln(
        '<div class="card" style="left:${card.x}px;top:${card.y}px;width:${card.width}px;height:${card.height}px;background:$bg">',
      );
      if (card.title.isNotEmpty) sb.writeln('<b>${card.title}</b><br>');
      if (card.content.isNotEmpty) sb.writeln(card.content);
      sb.writeln('</div>');
    }
    sb.writeln('</body></html>');
    return sb.toString();
  }

  Future<String> exportToJpeg(CanvasData data, String canvasName) =>
      exportToSvg(data, canvasName);

  Future<String> exportToWebp(CanvasData data, String canvasName) =>
      exportToSvg(data, canvasName);

  String encodeToUrl(CanvasData data) {
    final json = data.toJsonString();
    final encoded = base64Encode(utf8.encode(json));
    return 'rfbrowser://canvas?data=$encoded';
  }

  Future<(String, String)> exportWithEmbeddedData(
    CanvasData data,
    String canvasName,
  ) async {
    final json = data.toJsonString();
    final svg = await exportToSvg(data, canvasName);
    final svgWithMeta = svg.replaceFirst(
      '</svg>',
      '<metadata>rfbrowser:${base64Encode(utf8.encode(json))}</metadata></svg>',
    );
    return (svgWithMeta, json);
  }

  static CanvasData? decodeFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final data = uri.queryParameters['data'];
    if (data == null) return null;
    try {
      final json = utf8.decode(base64Decode(data));
      return CanvasData.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  static CanvasData? importFromCsv(String csv) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return null;
    final cards = <CanvasCard>[];
    final connections = <CanvasConnection>[];
    for (int i = 0; i < lines.length; i++) {
      final parts = lines[i].split(',').map((p) => p.trim()).toList();
      if (parts.length < 2) continue;
      final id = 'csv_$i';
      cards.add(
        CanvasCard(
          id: id,
          type: CanvasCardType.rectangle,
          x: (i % 5) * 200.0,
          y: (i ~/ 5) * 120.0,
          width: 160,
          height: 60,
          title: parts[0],
          content: parts.length > 1 ? parts.sublist(1).join(', ') : '',
        ),
      );
      if (i > 0 && parts.length > 1) {
        for (int j = 0; j < i; j++) {
          final prevParts = lines[j].split(',').map((p) => p.trim()).toList();
          if (prevParts.isNotEmpty && parts.contains(prevParts[0])) {
            connections.add(
              CanvasConnection(
                id: 'csv_c_${j}_$i',
                fromCardId: 'csv_$j',
                toCardId: id,
              ),
            );
          }
        }
      }
    }
    if (cards.isEmpty) return null;
    return CanvasData(cards: cards, connections: connections);
  }

  static CanvasData? importFromMermaid(String mermaid) {
    final lines = mermaid
        .split('\n')
        .map((l) => l.trim())
        .where(
          (l) =>
              l.isNotEmpty &&
              !l.startsWith('graph') &&
              !l.startsWith('flowchart'),
        )
        .toList();
    if (lines.isEmpty) return null;
    final nodeMap = <String, String>{};
    final cards = <CanvasCard>[];
    final connections = <CanvasConnection>[];
    int col = 0, row = 0;
    for (final line in lines) {
      final arrowMatch = RegExp(r'(\w+)\s*-->?\s*(\w+)');
      final match = arrowMatch.firstMatch(line);
      if (match != null) {
        final fromId = match.group(1)!;
        final toId = match.group(2)!;
        if (!nodeMap.containsKey(fromId)) {
          final cardId = 'mr_${nodeMap.length}';
          nodeMap[fromId] = cardId;
          cards.add(
            CanvasCard(
              id: cardId,
              type: CanvasCardType.rectangle,
              x: col * 200.0,
              y: row * 100.0,
              width: 160,
              height: 60,
              title: fromId,
            ),
          );
          col++;
          if (col >= 5) {
            col = 0;
            row++;
          }
        }
        if (!nodeMap.containsKey(toId)) {
          final cardId = 'mr_${nodeMap.length}';
          nodeMap[toId] = cardId;
          cards.add(
            CanvasCard(
              id: cardId,
              type: CanvasCardType.rectangle,
              x: col * 200.0,
              y: row * 100.0,
              width: 160,
              height: 60,
              title: toId,
            ),
          );
          col++;
          if (col >= 5) {
            col = 0;
            row++;
          }
        }
        connections.add(
          CanvasConnection(
            id: 'mr_c_${connections.length}',
            fromCardId: nodeMap[fromId]!,
            toCardId: nodeMap[toId]!,
          ),
        );
      }
    }
    if (cards.isEmpty) return null;
    return CanvasData(cards: cards, connections: connections);
  }

  static CanvasData? importFromEmbeddedSvg(String svgContent) {
    final metaMatch = RegExp(
      r'<metadata>rfbrowser:([A-Za-z0-9+/=]+)</metadata>',
    ).firstMatch(svgContent);
    if (metaMatch == null) return null;
    try {
      final json = utf8.decode(base64Decode(metaMatch.group(1)!));
      return CanvasData.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  static CanvasData? importFromSvg(String svgContent) {
    final embedded = importFromEmbeddedSvg(svgContent);
    if (embedded != null) return embedded;
    final rects = <CanvasCard>[];
    final rectRegex = RegExp(
      r'<rect[^>]*x="([^"]*)"[^>]*y="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"',
    );
    for (final m in rectRegex.allMatches(svgContent)) {
      rects.add(
        CanvasCard(
          id: 'svg_${rects.length}',
          type: CanvasCardType.rectangle,
          x: double.tryParse(m.group(1) ?? '0') ?? 0,
          y: double.tryParse(m.group(2) ?? '0') ?? 0,
          width: double.tryParse(m.group(3) ?? '100') ?? 100,
          height: double.tryParse(m.group(4) ?? '60') ?? 60,
        ),
      );
    }
    if (rects.isEmpty) return null;
    return CanvasData(cards: rects);
  }

  static CanvasData? importFromVsdx(String vsdxPath) {
    return null;
  }
}

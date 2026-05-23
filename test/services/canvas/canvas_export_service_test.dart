import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/services/canvas/canvas_export_service.dart';

CanvasData makeSampleData() {
  final cards = [
    CanvasCard(
      id: 'c1',
      type: CanvasCardType.rectangle,
      x: 100,
      y: 100,
      width: 200,
      height: 100,
      title: 'Card 1',
      content: 'Content line 1\nContent line 2',
      colorValue: 0xFFCCDDEE,
    ),
    CanvasCard(
      id: 'c2',
      type: CanvasCardType.roundedRect,
      x: 400,
      y: 200,
      width: 150,
      height: 80,
      title: 'Card 2',
      content: '',
      colorValue: 0xFFDDEEFF,
      style: const CanvasCardStyle(borderRadius: 12, borderColor: 0xFF999999),
    ),
  ];
  final connections = [
    CanvasConnection(
      id: 'conn1',
      fromCardId: 'c1',
      toCardId: 'c2',
      label: 'links to',
    ),
  ];
  final layers = [
    CanvasLayer(id: 'l1', name: 'Layer 1', order: 0),
    CanvasLayer(id: 'l2', name: 'Layer 2', order: 1),
  ];
  return CanvasData(cards: cards, connections: connections, layers: layers);
}

void main() {
  const service = CanvasExportService();

  group('CanvasExportService', () {
    group('exportToSvg', () {
      test('generates valid SVG with cards and connections', () {
        final svg = service.exportToSvg(makeSampleData(), 'TestCanvas');
        expect(svg, startsWith('<?xml'));
        expect(svg, contains('<svg xmlns="http://www.w3.org/2000/svg"'));
        expect(svg, contains('<rect'));
        expect(svg, contains('<line'));
        expect(svg, contains('Card 1'));
        expect(svg, contains('links to'));
        expect(svg, endsWith('</svg>\n'));
      });

      test('handles empty canvas gracefully', () {
        final svg = service.exportToSvg(CanvasData(), 'Empty');
        expect(svg, contains('<svg'));
        expect(svg, contains('width'));
        expect(svg, contains('height'));
      });

      test('includes connection label as text', () {
        final svg = service.exportToSvg(makeSampleData(), 'T');
        expect(svg, contains('<text'));
        expect(svg, contains('links to'));
      });

      test('skips connections with missing cards', () {
        final data = CanvasData(
          cards: [
            CanvasCard(
              id: 'c1',
              type: CanvasCardType.rectangle,
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
          ],
          connections: [
            CanvasConnection(id: 'conn', fromCardId: 'c1', toCardId: 'missing'),
          ],
        );
        final svg = service.exportToSvg(data, 'T');
        expect(svg, isNot(contains('<line')));
      });

      test('computes bounding box from card positions', () {
        final svg = service.exportToSvg(makeSampleData(), 'T');
        expect(svg, contains('viewBox'));
      });

      test('escapes XML special characters in content', () {
        final data = CanvasData(
          cards: [
            CanvasCard(
              id: 'c1',
              type: CanvasCardType.rectangle,
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              title: 'A < B & C > "D"',
              content: '',
            ),
          ],
        );
        final svg = service.exportToSvg(data, 'T');
        expect(svg, contains('A &lt; B &amp; C &gt; &quot;D&quot;'));
      });
    });

    group('exportToPdf', () {
      test('returns SVG content as PDF placeholder', () {
        final pdf = service.exportToPdf(makeSampleData(), 'T');
        expect(pdf, isNotEmpty);
      });
    });

    group('exportToJpeg', () {
      test('returns SVG content as JPEG placeholder', () {
        final jpeg = service.exportToJpeg(makeSampleData(), 'T');
        expect(jpeg, isNotEmpty);
      });
    });

    group('exportToWebp', () {
      test('returns SVG content as WebP placeholder', () {
        final webp = service.exportToWebp(makeSampleData(), 'T');
        expect(webp, isNotEmpty);
      });
    });

    group('exportToMarkdown', () {
      test('generates markdown table with cards and connections', () {
        final md = service.exportToMarkdown(makeSampleData(), 'MyCanvas');
        expect(md, contains('# Canvas: MyCanvas'));
        expect(md, contains('## Cards'));
        expect(md, contains('| # | Type | Title | Position | Layer |'));
        expect(md, contains('Card 1'));
        expect(md, contains('Card 2'));
        expect(md, contains('## Connections'));
        expect(md, contains('Card 1'));
      });

      test('shows layer name when layerId is set', () {
        final data = CanvasData(
          cards: [
            CanvasCard(
              id: 'c1',
              type: CanvasCardType.rectangle,
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              title: 'C1',
              layerId: 'l1',
            ),
          ],
          layers: [CanvasLayer(id: 'l1', name: 'MyLayer', order: 0)],
        );
        final md = service.exportToMarkdown(data, 'T');
        expect(md, contains('MyLayer'));
      });

      test('marks auto connections', () {
        final data = CanvasData(
          cards: [
            CanvasCard(
              id: 'c1',
              type: CanvasCardType.rectangle,
              x: 0,
              y: 0,
              width: 100,
              height: 50,
            ),
            CanvasCard(
              id: 'c2',
              type: CanvasCardType.rectangle,
              x: 100,
              y: 0,
              width: 100,
              height: 50,
            ),
          ],
          connections: [
            CanvasConnection(
              id: 'a1',
              fromCardId: 'c1',
              toCardId: 'c2',
              isAuto: true,
            ),
          ],
        );
        final md = service.exportToMarkdown(data, 'T');
        expect(md, contains('(auto)'));
      });
    });

    group('encodeToUrl / decodeFromUrl', () {
      test('round-trips canvas data through URL encoding', () {
        final data = makeSampleData();
        final url = service.encodeToUrl(data);
        expect(url, startsWith('rfbrowser://canvas?data='));

        final decoded = CanvasExportService.decodeFromUrl(url);
        expect(decoded, isNotNull);
        expect(decoded!.cards.length, 2);
        expect(decoded.connections.length, 1);
      });

      test('decodeFromUrl returns null for invalid URLs', () {
        expect(CanvasExportService.decodeFromUrl('not-a-url'), isNull);
        expect(CanvasExportService.decodeFromUrl('data:text'), isNull);
      });

      test('decodeFromUrl returns null when data param missing', () {
        expect(
          CanvasExportService.decodeFromUrl('rfbrowser://canvas?x=1'),
          isNull,
        );
      });
    });

    group('exportWithEmbeddedData', () {
      test('embeds metadata in SVG', () {
        final (svg, json) = service.exportWithEmbeddedData(
          makeSampleData(),
          'T',
        );
        expect(svg, contains('<metadata>rfbrowser:'));
        expect(json, isNotEmpty);
      });

      test('importFromEmbeddedSvg recovers data', () {
        final (svg, _) = service.exportWithEmbeddedData(makeSampleData(), 'T');
        final recovered = CanvasExportService.importFromEmbeddedSvg(svg);
        expect(recovered, isNotNull);
        expect(recovered!.cards.length, 2);
      });

      test('importFromEmbeddedSvg returns null for plain SVG', () {
        final plainSvg = '<svg></svg>';
        expect(CanvasExportService.importFromEmbeddedSvg(plainSvg), isNull);
      });
    });

    group('importFromSvg', () {
      test('prefers embedded data over rect parsing', () {
        final (svg, _) = service.exportWithEmbeddedData(makeSampleData(), 'T');
        final result = CanvasExportService.importFromSvg(svg);
        expect(result!.cards.length, 2);
        expect(result.connections.length, 1);
      });

      test('parses rect elements from plain SVG', () {
        final svg = '<svg><rect x="10" y="20" width="100" height="50"/></svg>';
        final result = CanvasExportService.importFromSvg(svg);
        expect(result, isNotNull);
        expect(result!.cards.length, 1);
        expect(result.cards[0].x, 10);
        expect(result.cards[0].y, 20);
        expect(result.cards[0].width, 100);
        expect(result.cards[0].height, 50);
      });

      test('returns null for SVG without parsable elements', () {
        final svg = '<svg></svg>';
        expect(CanvasExportService.importFromSvg(svg), isNull);
      });
    });

    group('importFromCsv', () {
      test('parses CSV into cards', () {
        final csv = 'Item A, Description A\nItem B, Description B';
        final result = CanvasExportService.importFromCsv(csv);
        expect(result, isNotNull);
        expect(result!.cards.length, 2);
        expect(result.cards[0].title, 'Item A');
        expect(result.cards[0].content, 'Description A');
      });

      test(
        'creates connections when current row references previous row title',
        () {
          final csv = 'Item A, Item B\nItem C, Item A';
          final result = CanvasExportService.importFromCsv(csv);
          expect(result, isNotNull);
          expect(result!.connections, isNotEmpty);
        },
      );

      test('returns null for empty CSV', () {
        expect(CanvasExportService.importFromCsv(''), isNull);
      });

      test('positions cards in a grid', () {
        final csv = List.generate(10, (i) => 'Item $i, Desc $i').join('\n');
        final result = CanvasExportService.importFromCsv(csv);
        expect(result!.cards.length, 10);
        expect(result.cards[0].x, 0);
        expect(result.cards[5].y, 120);
      });
    });

    group('importFromMermaid', () {
      test('parses simple flow chart', () {
        final mermaid = 'graph TD\n  A --> B\n  B --> C';
        final result = CanvasExportService.importFromMermaid(mermaid);
        expect(result, isNotNull);
        expect(result!.cards.length, 3);
        expect(result.connections.length, 2);
      });

      test('creates cards for nodes', () {
        final mermaid = 'graph LR\n  Start --> End';
        final result = CanvasExportService.importFromMermaid(mermaid);
        expect(result!.cards.any((c) => c.title == 'Start'), isTrue);
        expect(result.cards.any((c) => c.title == 'End'), isTrue);
      });

      test('returns null for empty mermaid content', () {
        expect(CanvasExportService.importFromMermaid(''), isNull);
        expect(CanvasExportService.importFromMermaid('graph TD'), isNull);
      });
    });

    group('importFromVsdx', () {
      test('returns null placeholder', () {
        expect(CanvasExportService.importFromVsdx('file.vsdx'), isNull);
      });
    });

    group('exportToHtml', () {
      test('generates HTML with cards as divs', () {
        final html = service.exportToHtml(makeSampleData());
        expect(html, contains('<!DOCTYPE html>'));
        expect(html, contains('<div class="card"'));
        expect(html, contains('Card 1'));
      });

      test('includes SVG connections overlay', () {
        final html = service.exportToHtml(makeSampleData());
        expect(html, contains('<line'));
      });
    });
  });
}

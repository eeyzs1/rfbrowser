import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/link.dart';
import 'package:rfbrowser/data/models/link_type.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/services/knowledge_service.dart';
import 'package:rfbrowser/core/graph/graph_algorithm.dart';
import 'package:rfbrowser/ui/pages/graph_page.dart';
import 'package:rfbrowser/ui/pages/canvas_page.dart';
import 'package:rfbrowser/ui/widgets/canvas_painter.dart';

Note _mkNote(String id, [String content = '']) =>
    Note(id: id, title: id, filePath: '$id.md', content: content);

Link _mkLink(String from, String to) =>
    Link(sourceId: from, targetId: to, type: LinkType.wikilink);

GraphLink _mkGLink(String from, String to) =>
    GraphLink(sourceId: from, targetId: to);

List<Note> _ns(List<String> ids) => ids.map((id) => _mkNote(id)).toList();

void main() {
  group('G5: GraphPage compliance', () {
    test('shouldRepaint returns false for same object (P-2)', () {
      final notes = _ns(['A', 'B']);
      final links = [_mkGLink('A', 'B')];

      final p = GraphPainter(
        notes: notes, links: links, scale: 1.0, offset: Offset.zero,
        primaryColor: Colors.blue, secondaryColor: Colors.cyan,
        surfaceColor: Colors.white, onSurfaceColor: Colors.black,
        hintColor: Colors.grey, cardColor: Colors.white, errorColor: Colors.red, bridgeIds: {},
      );

      expect(p.shouldRepaint(p), isFalse);
    });

    test('shouldRepaint returns true for different data (P-2)', () {
      final notes = _ns(['A', 'B']);
      final links = [_mkGLink('A', 'B')];

      final p1 = GraphPainter(
        notes: notes, links: links, scale: 1.0, offset: Offset.zero,
        primaryColor: Colors.blue, secondaryColor: Colors.cyan,
        surfaceColor: Colors.white, onSurfaceColor: Colors.black,
        hintColor: Colors.grey, cardColor: Colors.white, errorColor: Colors.red, bridgeIds: {},
      );
      final p2 = GraphPainter(
        notes: notes, links: links, scale: 2.0, offset: Offset.zero,
        primaryColor: Colors.blue, secondaryColor: Colors.cyan,
        surfaceColor: Colors.white, onSurfaceColor: Colors.black,
        hintColor: Colors.grey, cardColor: Colors.white, errorColor: Colors.red, bridgeIds: {},
      );

      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('bridge node detection finds articulation edges', () {
      final notes = _ns(['A', 'B', 'C', 'D']);
      final links = [
        _mkLink('A', 'B'), _mkLink('B', 'C'), _mkLink('D', 'B'),
      ];

      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);
      final bridges = algo.getBridgeNodes();

      expect(bridges.isNotEmpty, isTrue);
      final bridgeIds = bridges.map((b) => b.noteId).toSet();
      expect(bridgeIds.contains('B'), isTrue);
    });

    test('getGraphStats returns correct counts', () {
      final notes = _ns(['A', 'B']);
      final links = [_mkLink('A', 'B')];

      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);
      final stats = algo.getGraphStats();

      expect(stats.totalNodes, 2);
      expect(stats.totalEdges, 1);
    });

    test('shortestPath finds path between connected nodes', () {
      final notes = _ns(['A', 'B', 'C']);
      final links = [_mkLink('A', 'B'), _mkLink('B', 'C')];

      final algo = GraphAlgorithm(allNotes: notes, allLinks: links);
      final path = algo.shortestPath('A', 'C');

      expect(path.length, 3);
      expect(path.first, 'A');
      expect(path.last, 'C');
    });

    test('GraphView widget exists', () {
      expect(const GraphView(), isA<GraphView>());
    });
  });

  group('G6: CanvasPage compliance', () {
    test('CanvasCard with noteId supports live note data (A-5)', () {
      final card = CanvasCard(
        id: 'card-1', type: CanvasCardType.note,
        title: 'Stale Title', content: '', noteId: 'live-note',
      );

      expect(card.noteId, 'live-note');
      expect(card.id, 'card-1');
      expect(card.type, CanvasCardType.note);
    });

    test('shouldRepaint returns false for same object (P-2)', () {
      final cards = [CanvasCard(id: '1', type: CanvasCardType.note)];
      final knowledge = KnowledgeState();

      final p = CanvasPainter(
        cards: cards, connections: [], autoConnections: [],
        cameraX: 0, cameraY: 0, scale: 1.0, viewW: 400, viewH: 300,
        gridSize: 20, visibleWorldRect: const Rect.fromLTWH(0, 0, 400, 300),
        searchMatchedIds: [], searchActiveIndex: 0,
        primaryColor: Colors.blue, dividerColor: Colors.grey,
        scaffoldBg: Colors.white, isDark: false, hintColor: Colors.grey,
        knowledgeState: knowledge,
        baseFontSize: 14.0,
      );

      expect(p.shouldRepaint(p), isFalse);
    });

    test('shouldRepaint returns true for different camera (P-2)', () {
      final cards = [CanvasCard(id: '1', type: CanvasCardType.note)];
      final knowledge = KnowledgeState();

      final p1 = CanvasPainter(
        cards: cards, connections: [], autoConnections: [],
        cameraX: 0, cameraY: 0, scale: 1.0, viewW: 400, viewH: 300,
        gridSize: 20, visibleWorldRect: const Rect.fromLTWH(0, 0, 400, 300),
        searchMatchedIds: [], searchActiveIndex: 0,
        primaryColor: Colors.blue, dividerColor: Colors.grey,
        scaffoldBg: Colors.white, isDark: false, hintColor: Colors.grey,
        knowledgeState: knowledge,
        baseFontSize: 14.0,
      );
      final p2 = CanvasPainter(
        cards: cards, connections: [], autoConnections: [],
        cameraX: 10, cameraY: 0, scale: 1.0, viewW: 400, viewH: 300,
        gridSize: 20, visibleWorldRect: const Rect.fromLTWH(0, 0, 400, 300),
        searchMatchedIds: [], searchActiveIndex: 0,
        primaryColor: Colors.blue, dividerColor: Colors.grey,
        scaffoldBg: Colors.white, isDark: false, hintColor: Colors.grey,
        knowledgeState: knowledge,
        baseFontSize: 14.0,
      );

      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('auto connections flagged distinct from manual (A-6)', () {
      final auto = CanvasConnection(
        id: 'ac', fromCardId: 'A', toCardId: 'B',
        fromSide: ConnectionSide.right, toSide: ConnectionSide.left,
        isAuto: true,
      );
      final manual = CanvasConnection(
        id: 'mc', fromCardId: 'A', toCardId: 'B',
        fromSide: ConnectionSide.right, toSide: ConnectionSide.left,
        isAuto: false,
      );

      expect(auto.isAuto, isTrue);
      expect(manual.isAuto, isFalse);
      expect(auto.isAuto, isNot(manual.isAuto));
    });

    test('CanvasCard rect computed correctly', () {
      final card = CanvasCard(
        id: 'c', type: CanvasCardType.note,
        x: 100, y: 200, width: 300, height: 150,
      );

      final r = card.rect;
      expect(r.left, 100.0);
      expect(r.top, 200.0);
      expect(r.width, 300.0);
      expect(r.height, 150.0);
      expect(card.center, Offset(250.0, 275.0));
    });

    test('CanvasConnection sides correctly set', () {
      final conn = CanvasConnection(
        id: 'c', fromCardId: 'A', toCardId: 'B',
        fromSide: ConnectionSide.right, toSide: ConnectionSide.left,
      );

      expect(conn.fromSide, ConnectionSide.right);
      expect(conn.toSide, ConnectionSide.left);
    });

    test('CanvasView widget exists', () {
      expect(const CanvasView(), isA<CanvasView>());
    });
  });

  group('G12: Performance & Security compliance', () {
    test('P-2: CanvasPainter self shouldRepaint is false', () {
      final knowledge = KnowledgeState();

      final p = CanvasPainter(
        cards: [], connections: [], autoConnections: [],
        cameraX: 0, cameraY: 0, scale: 1.0, viewW: 400, viewH: 300,
        gridSize: 20, visibleWorldRect: const Rect.fromLTWH(0, 0, 400, 300),
        searchMatchedIds: [], searchActiveIndex: 0,
        primaryColor: Colors.blue, dividerColor: Colors.grey,
        scaffoldBg: Colors.white, isDark: false, hintColor: Colors.grey,
        knowledgeState: knowledge,
        baseFontSize: 14.0,
      );

      expect(p.shouldRepaint(p), isFalse);
    });

    test('U-2: CanvasPainter is valid CustomPainter', () {
      final knowledge = KnowledgeState();
      final painter = CanvasPainter(
        cards: [], connections: [], autoConnections: [],
        cameraX: 0, cameraY: 0, scale: 1.0, viewW: 400, viewH: 300,
        gridSize: 20, visibleWorldRect: const Rect.fromLTWH(0, 0, 400, 300),
        searchMatchedIds: [], searchActiveIndex: 0,
        primaryColor: Colors.blue, dividerColor: Colors.grey,
        scaffoldBg: Colors.white, isDark: false, hintColor: Colors.grey,
        knowledgeState: knowledge,
        baseFontSize: 14.0,
      );

      expect(painter, isA<CustomPainter>());
    });
  });
}

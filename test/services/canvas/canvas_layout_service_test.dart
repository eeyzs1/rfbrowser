import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/services/canvas/canvas_layout_service.dart';

void main() {
  group('CanvasLayoutService', () {
    const service = CanvasLayoutService();

    group('snapToGrid', () {
      test('snaps values to nearest 20', () {
        expect(service.snapToGrid(0), 0.0);
        expect(service.snapToGrid(9), 0.0);
        expect(service.snapToGrid(10), 20.0);
        expect(service.snapToGrid(30), 40.0);
        expect(service.snapToGrid(101), 100.0);
        expect(service.snapToGrid(-5), 0.0);
        expect(service.snapToGrid(-15), -20.0);
      });
    });

    group('computeLayout', () {
      List<CanvasCard> makeCards(int count) {
        return List.generate(
          count,
          (i) => CanvasCard(
            id: 'c$i',
            type: CanvasCardType.rectangle,
            x: 0,
            y: 0,
            width: 100,
            height: 50,
            title: 'Card $i',
          ),
        );
      }

      List<CanvasConnection> makeChain(List<CanvasCard> cards) {
        final conns = <CanvasConnection>[];
        for (int i = 1; i < cards.length; i++) {
          conns.add(
            CanvasConnection(
              id: 'conn_$i',
              fromCardId: cards[i - 1].id,
              toCardId: cards[i].id,
            ),
          );
        }
        return conns;
      }

      test('returns empty map for empty cards list', () {
        final result = service.computeLayout(
          [],
          [],
          AutoLayoutType.forceDirected,
        );
        expect(result, isEmpty);
      });

      test('switches between layout types', () {
        final cards = makeCards(3);
        final connections = makeChain(cards);
        final fd = service.computeLayout(
          cards,
          connections,
          AutoLayoutType.forceDirected,
        );
        final hierarchy = service.computeLayout(
          cards,
          connections,
          AutoLayoutType.hierarchical,
        );
        final grid = service.computeLayout(
          cards,
          connections,
          AutoLayoutType.grid,
        );
        expect(fd.length, 3);
        expect(hierarchy.length, 3);
        expect(grid.length, 3);
      });

      test('force directed produces positions for all cards', () {
        final cards = makeCards(5);
        final connections = makeChain(cards);
        final result = service.computeLayout(
          cards,
          connections,
          AutoLayoutType.forceDirected,
          snapToGrid: false,
        );
        expect(result.length, 5);
        for (final card in cards) {
          expect(result.containsKey(card.id), isTrue);
        }
      });

      test('force directed positions are finite', () {
        final cards = makeCards(10);
        final result = service.computeLayout(
          cards,
          [],
          AutoLayoutType.forceDirected,
          snapToGrid: false,
        );
        for (final offset in result.values) {
          expect(offset.dx.isFinite, isTrue);
          expect(offset.dy.isFinite, isTrue);
        }
      });

      test('force directed single card returns origin', () {
        final cards = makeCards(1);
        final result = service.computeLayout(
          cards,
          [],
          AutoLayoutType.forceDirected,
          snapToGrid: false,
        );
        expect(result['c0'], Offset.zero);
      });

      test('hierarchical respects direction connections', () {
        final cards = makeCards(4);
        final connections = [
          CanvasConnection(id: 'e1', fromCardId: 'c0', toCardId: 'c1'),
          CanvasConnection(id: 'e2', fromCardId: 'c1', toCardId: 'c2'),
          CanvasConnection(id: 'e3', fromCardId: 'c0', toCardId: 'c3'),
        ];
        final result = service.computeLayout(
          cards,
          connections,
          AutoLayoutType.hierarchical,
          snapToGrid: false,
        );
        expect(result.length, 4);
        expect(result['c0']!.dy, lessThan(result['c1']!.dy));
        expect(result['c1']!.dy, lessThan(result['c2']!.dy));
      });

      test('hierarchical handles cards without incoming connections', () {
        final cards = makeCards(3);
        final connections = [
          CanvasConnection(id: 'e1', fromCardId: 'c0', toCardId: 'c1'),
        ];
        final result = service.computeLayout(
          cards,
          connections,
          AutoLayoutType.hierarchical,
          snapToGrid: false,
        );
        expect(result.length, 3);
        expect(result.containsKey('c2'), isTrue);
      });

      test('hierarchical handles cyclic connections gracefully', () {
        final cards = makeCards(2);
        final connections = [
          CanvasConnection(id: 'e1', fromCardId: 'c0', toCardId: 'c1'),
          CanvasConnection(id: 'e2', fromCardId: 'c1', toCardId: 'c0'),
        ];
        final result = service.computeLayout(
          cards,
          connections,
          AutoLayoutType.hierarchical,
          snapToGrid: false,
        );
        expect(result.length, 2);
      });

      test('grid layout arranges cards in rows and columns', () {
        final cards = makeCards(6);
        final result = service.computeLayout(
          cards,
          [],
          AutoLayoutType.grid,
          snapToGrid: false,
        );
        expect(result.length, 6);
        final sorted = result.entries.toList()
          ..sort((a, b) => a.value.dy.compareTo(b.value.dy));
        expect(sorted[0].value.dy, lessThan(sorted[3].value.dy));
      });

      test('snap to grid rounds positions', () {
        final cards = makeCards(3);
        final result = service.computeLayout(
          cards,
          [],
          AutoLayoutType.grid,
          snapToGrid: true,
        );
        for (final offset in result.values) {
          expect(offset.dx % 20, 0.0);
          expect(offset.dy % 20, 0.0);
        }
      });

      test('force directed with many cards does not overflow', () {
        final cards = makeCards(50);
        final result = service.computeLayout(
          cards,
          [],
          AutoLayoutType.forceDirected,
          snapToGrid: false,
        );
        for (final offset in result.values) {
          expect(offset.dx.isFinite, isTrue);
          expect(offset.dy.isFinite, isTrue);
          expect(offset.dx.abs(), lessThan(1e6));
          expect(offset.dy.abs(), lessThan(1e6));
        }
      });
    });
  });
}

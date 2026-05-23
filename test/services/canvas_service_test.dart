import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/data/stores/vault_store.dart';
import 'package:rfbrowser/services/canvas_service.dart';

class TestVaultNotifier extends VaultNotifier {
  final VaultState _state;
  TestVaultNotifier(this._state);
  @override
  VaultState build() => _state;
  @override
  set state(VaultState newState) => super.state = newState;
}

ProviderContainer createContainer() {
  return ProviderContainer(
    overrides: [
      vaultProvider.overrideWith(() => TestVaultNotifier(VaultState())),
    ],
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CanvasData', () {
    test('default state has empty collections', () {
      final data = CanvasData();
      expect(data.cards, isEmpty);
      expect(data.connections, isEmpty);
      expect(data.groups, isEmpty);
      expect(data.layers, isEmpty);
      expect(data.selectedCardIds, isEmpty);
      expect(data.inlineEditingCardId, isNull);
      expect(data.selectedConnectionId, isNull);
    });

    test('default settings have expected defaults', () {
      final data = CanvasData();
      expect(data.settings.autoConnectionsEnabled, true);
      expect(data.settings.snapToGrid, true);
      expect(data.settings.gridVisible, true);
      expect(data.settings.rulersVisible, false);
      expect(data.settings.backgroundColorValue, isNull);
      expect(data.settings.defaultCardStyle, isNull);
      expect(data.settings.defaultConnectionStyle, isNull);
    });

    test('copyWith updates cards', () {
      final card = CanvasCard(id: 'c1', type: CanvasCardType.text);
      final data = CanvasData().copyWith(cards: [card]);
      expect(data.cards, hasLength(1));
      expect(data.cards.first.id, 'c1');
    });

    test('copyWith clearSelectedCardIds sets empty list', () {
      final data = CanvasData(
        selectedCardIds: ['c1', 'c2'],
      ).copyWith(clearSelectedCardIds: true);
      expect(data.selectedCardIds, isEmpty);
    });

    test('copyWith clearSelectedCardIds overrides selectedCardIds', () {
      final data = CanvasData(
        selectedCardIds: ['c1', 'c2'],
      ).copyWith(clearSelectedCardIds: true, selectedCardIds: ['c3']);
      expect(data.selectedCardIds, []);
    });

    test('copyWith clearInlineEditingCardId sets null', () {
      final data = CanvasData(
        inlineEditingCardId: 'c1',
      ).copyWith(clearInlineEditingCardId: true);
      expect(data.inlineEditingCardId, isNull);
    });

    test('copyWith clearSelectedConnectionId sets null', () {
      final data = CanvasData(
        selectedConnectionId: 'conn1',
      ).copyWith(clearSelectedConnectionId: true);
      expect(data.selectedConnectionId, isNull);
    });

    test('toJsonString and fromJsonString roundtrip', () {
      final original = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text, x: 10, y: 20)],
        connections: [
          CanvasConnection(id: 'conn1', fromCardId: 'c1', toCardId: 'c2'),
        ],
        groups: [
          CanvasGroup(id: 'g1', name: 'Test Group', cardIds: ['c1']),
        ],
        settings: CanvasSettings(gridVisible: false),
      );
      final json = original.toJsonString();
      final restored = CanvasData.fromJsonString(json);
      expect(restored.cards, hasLength(1));
      expect(restored.cards.first.id, 'c1');
      expect(restored.cards.first.x, 10);
      expect(restored.cards.first.y, 20);
      expect(restored.connections, hasLength(1));
      expect(restored.connections.first.id, 'conn1');
      expect(restored.groups, hasLength(1));
      expect(restored.groups.first.name, 'Test Group');
      expect(restored.settings.gridVisible, false);
    });

    test('fromJsonString returns default on invalid JSON', () {
      final data = CanvasData.fromJsonString('not json');
      expect(data.cards, isEmpty);
    });

    test('fromJsonString returns default on empty JSON without keys', () {
      final data = CanvasData.fromJsonString('{}');
      expect(data.cards, isEmpty);
      expect(data.connections, isEmpty);
    });
  });

  group('CanvasNotifier - basic', () {
    test('build returns CanvasData', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.state.cards, isEmpty);
    });

    test('canUndo and canRedo are initially false', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.canUndo, false);
      expect(notifier.canRedo, false);
    });

    test('activeCanvasName defaults to default', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.activeCanvasName, 'default');
    });

    test('canvasNames defaults to [default]', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.canvasNames, ['default']);
    });
  });

  group('CanvasNotifier - settings toggles', () {
    test('toggleAutoConnections toggles setting', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.state.settings.autoConnectionsEnabled, true);
      notifier.toggleAutoConnections();
      expect(notifier.state.settings.autoConnectionsEnabled, false);
      notifier.toggleAutoConnections();
      expect(notifier.state.settings.autoConnectionsEnabled, true);
    });

    test('toggleSnapToGrid toggles setting', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.state.settings.snapToGrid, true);
      notifier.toggleSnapToGrid();
      expect(notifier.state.settings.snapToGrid, false);
    });

    test('toggleGridVisible toggles setting', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.state.settings.gridVisible, true);
      notifier.toggleGridVisible();
      expect(notifier.state.settings.gridVisible, false);
    });

    test('toggleRulers toggles setting', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.state.settings.rulersVisible, false);
      notifier.toggleRulers();
      expect(notifier.state.settings.rulersVisible, true);
    });

    test('autoConnectionsEnabled getter matches state', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.autoConnectionsEnabled, true);
      notifier.toggleAutoConnections();
      expect(notifier.autoConnectionsEnabled, false);
    });

    test('setBackgroundColor sets color', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.setBackgroundColor(0xFFABCDEF);
      expect(notifier.state.settings.backgroundColorValue, 0xFFABCDEF);
    });

    test('setBackgroundColor(null) clears background color', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.setBackgroundColor(0xFFABCDEF);
      notifier.setBackgroundColor(null);
      expect(notifier.state.settings.backgroundColorValue, isNull);
    });

    test('setDefaultCardStyle sets style', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final style = const CanvasCardStyle(fillColor: 0xFFCCCCCC);
      notifier.setDefaultCardStyle(style);
      expect(notifier.state.settings.defaultCardStyle?.fillColor, 0xFFCCCCCC);
    });

    test('setDefaultCardStyle(null) clears style', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.setDefaultCardStyle(
        const CanvasCardStyle(fillColor: 0xFFCCCCCC),
      );
      notifier.setDefaultCardStyle(null);
      expect(notifier.state.settings.defaultCardStyle, isNull);
    });

    test('setDefaultConnectionStyle sets style', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final style = const CanvasConnectionStyle(strokeWidth: 5.0);
      notifier.setDefaultConnectionStyle(style);
      expect(notifier.state.settings.defaultConnectionStyle?.strokeWidth, 5.0);
    });

    test('setDefaultConnectionStyle(null) clears style', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.setDefaultConnectionStyle(
        const CanvasConnectionStyle(strokeWidth: 5.0),
      );
      notifier.setDefaultConnectionStyle(null);
      expect(notifier.state.settings.defaultConnectionStyle, isNull);
    });
  });

  group('CanvasNotifier - card selection', () {
    test('selectCard(null) clears selection', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCards(['c1', 'c2']);
      notifier.selectCard(null);
      expect(notifier.state.selectedCardIds, isEmpty);
    });

    test('selectCard(id) selects single card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCard('c1');
      expect(notifier.state.selectedCardIds, ['c1']);
    });

    test('selectCard(id) clears selected connection', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectConnection('conn1');
      notifier.selectCard('c1');
      expect(notifier.state.selectedConnectionId, isNull);
    });

    test('selectCard(id, additive: true) adds card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCard('c1');
      notifier.selectCard('c2', additive: true);
      expect(notifier.state.selectedCardIds, containsAll(['c1', 'c2']));
    });

    test('selectCard(id, additive: true) removes existing card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCard('c1');
      notifier.selectCard('c2', additive: true);
      notifier.selectCard('c1', additive: true);
      expect(notifier.state.selectedCardIds, ['c2']);
    });

    test('selectCards selects multiple', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCards(['c1', 'c2', 'c3']);
      expect(notifier.state.selectedCardIds, ['c1', 'c2', 'c3']);
    });

    test('selectCards clears selected connection', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectConnection('conn1');
      notifier.selectCards(['c1']);
      expect(notifier.state.selectedConnectionId, isNull);
    });

    test('addToSelection adds card without duplicates', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCard('c1');
      notifier.addToSelection('c2');
      notifier.addToSelection('c1');
      expect(notifier.state.selectedCardIds, ['c1', 'c2']);
    });

    test('removeFromSelection removes card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCards(['c1', 'c2', 'c3']);
      notifier.removeFromSelection('c2');
      expect(notifier.state.selectedCardIds, ['c1', 'c3']);
    });

    test('selectAll selects all cards', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text),
          CanvasCard(id: 'c2', type: CanvasCardType.text),
          CanvasCard(id: 'c3', type: CanvasCardType.text),
        ],
      );
      notifier.selectAll();
      expect(notifier.state.selectedCardIds, containsAll(['c1', 'c2', 'c3']));
    });

    test('clearSelection clears both selections', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCards(['c1']);
      notifier.selectConnection('conn1');
      notifier.clearSelection();
      expect(notifier.state.selectedCardIds, isEmpty);
      expect(notifier.state.selectedConnectionId, isNull);
    });

    test('selectConnection selects and clears card selection', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectCards(['c1']);
      notifier.selectConnection('conn1');
      expect(notifier.state.selectedConnectionId, 'conn1');
      expect(notifier.state.selectedCardIds, isEmpty);
    });

    test('selectConnection(null) clears', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.selectConnection('conn1');
      notifier.selectConnection(null);
      expect(notifier.state.selectedConnectionId, isNull);
    });
  });

  group('CanvasNotifier - inline editing', () {
    test('startInlineEditing sets selection and editing card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.startInlineEditing('c1');
      expect(notifier.state.inlineEditingCardId, 'c1');
      expect(notifier.state.selectedCardIds, ['c1']);
    });

    test('finishInlineEditing clears editing card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.startInlineEditing('c1');
      notifier.finishInlineEditing();
      expect(notifier.state.inlineEditingCardId, isNull);
    });
  });

  group('CanvasNotifier - createCard', () {
    test('createCard creates card with default values', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final card = notifier.createCard(
        CanvasCardType.text,
        const Offset(100, 200),
      );
      expect(card.type, CanvasCardType.text);
      expect(card.x, 100);
      expect(card.y, 200);
      expect(card.width, CanvasCardType.text.defaultWidth);
      expect(card.height, CanvasCardType.text.defaultHeight);
      expect(card.title, CanvasCardType.text.label);
    });

    test('createCard with custom title', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final card = notifier.createCard(
        CanvasCardType.text,
        const Offset(0, 0),
        title: 'Custom Title',
      );
      expect(card.title, 'Custom Title');
    });

    test('createCard with noteId', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final card = notifier.createCard(
        CanvasCardType.note,
        const Offset(0, 0),
        noteId: 'note-123',
      );
      expect(card.noteId, 'note-123');
    });

    test('createCard respects default style', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final style = const CanvasCardStyle(fillColor: 0xFF123456);
      notifier.setDefaultCardStyle(style);
      final card = notifier.createCard(CanvasCardType.text, const Offset(0, 0));
      expect(card.style?.fillColor, 0xFF123456);
    });

    test('createCard generates unique ids', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final card1 = notifier.createCard(
        CanvasCardType.text,
        const Offset(0, 0),
      );
      await Future.delayed(const Duration(milliseconds: 2));
      final card2 = notifier.createCard(
        CanvasCardType.text,
        const Offset(0, 0),
      );
      expect(card1.id, isNot(card2.id));
    });
  });

  group('CanvasNotifier - createConnection', () {
    test('createConnection returns empty connection if card not found', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final conn = notifier.createConnection('nonexistent', 'nonexistent2');
      expect(conn.id, '');
    });

    test('createConnection returns valid connection with existing cards', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            x: 0,
            y: 0,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            x: 200,
            y: 0,
            width: 100,
            height: 100,
          ),
        ],
      );
      final conn = notifier.createConnection('c1', 'c2', label: 'Test Label');
      expect(conn.id, isNotEmpty);
      expect(conn.fromCardId, 'c1');
      expect(conn.toCardId, 'c2');
      expect(conn.label, 'Test Label');
      expect(conn.isAuto, false);
    });

    test('createConnection respects default connection style', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            x: 0,
            y: 0,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            x: 200,
            y: 0,
            width: 100,
            height: 100,
          ),
        ],
      );
      final connStyle = const CanvasConnectionStyle(
        pathType: ConnectionPath.straight,
        arrowStyle: ArrowStyle.diamond,
      );
      notifier.setDefaultConnectionStyle(connStyle);
      final conn = notifier.createConnection('c1', 'c2');
      expect(conn.style?.pathType, ConnectionPath.straight);
      expect(conn.style?.arrowStyle, ArrowStyle.diamond);
    });
  });

  group('CanvasNotifier - cardById, groupForCard', () {
    test('cardById returns card if found', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Test')],
      );
      final card = notifier.cardById('c1');
      expect(card, isNotNull);
      expect(card!.title, 'Test');
    });

    test('cardById returns null if not found', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final card = notifier.cardById('nonexistent');
      expect(card, isNull);
    });

    test('groupForCard returns group containing card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
        groups: [
          CanvasGroup(id: 'g1', name: 'G1', cardIds: ['c1', 'c2']),
        ],
      );
      final group = notifier.groupForCard('c1');
      expect(group, isNotNull);
      expect(group!.name, 'G1');
    });

    test('groupForCard returns null if no group contains card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
        groups: [
          CanvasGroup(id: 'g1', name: 'G1', cardIds: ['c2']),
        ],
      );
      final group = notifier.groupForCard('c1');
      expect(group, isNull);
    });

    test('groupCardIds returns card ids for group', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        groups: [
          CanvasGroup(id: 'g1', name: 'G1', cardIds: ['c1', 'c2']),
        ],
      );
      expect(notifier.groupCardIds('g1'), ['c1', 'c2']);
    });

    test('groupCardIds returns empty for non-existent group', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.groupCardIds('nonexistent'), isEmpty);
    });
  });

  group('CanvasNotifier - searchCards', () {
    test('searchCards with empty query returns all cards', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Alpha'),
          CanvasCard(id: 'c2', type: CanvasCardType.text, title: 'Beta'),
        ],
      );
      final results = notifier.searchCards('');
      expect(results, hasLength(2));
    });

    test('searchCards matches title', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Alpha'),
          CanvasCard(id: 'c2', type: CanvasCardType.text, title: 'Beta'),
          CanvasCard(id: 'c3', type: CanvasCardType.text, title: 'Gamma'),
        ],
      );
      final results = notifier.searchCards('alpha');
      expect(results, hasLength(1));
      expect(results.first.id, 'c1');
    });

    test('searchCards matches content', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            title: 'X',
            content: 'Hello World',
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            title: 'Y',
            content: 'Goodbye',
          ),
        ],
      );
      final results = notifier.searchCards('world');
      expect(results, hasLength(1));
      expect(results.first.id, 'c1');
    });

    test('searchCards is case insensitive', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'ALPHA'),
        ],
      );
      expect(notifier.searchCards('alpha'), hasLength(1));
      expect(notifier.searchCards('ALPHA'), hasLength(1));
      expect(notifier.searchCards('AlPhA'), hasLength(1));
    });
  });

  group('CanvasNotifier - alignCards', () {
    late ProviderContainer container;
    late CanvasNotifier notifier;

    setUp(() {
      container = createContainer();
      notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            x: 10,
            y: 10,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            x: 200,
            y: 50,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c3',
            type: CanvasCardType.text,
            x: 350,
            y: 80,
            width: 100,
            height: 100,
          ),
        ],
      );
    });

    test('alignCards with <2 cards returns early', () {
      notifier.alignCards(['c1'], AlignmentType.left);
      expect(notifier.state.cards.firstWhere((c) => c.id == 'c1').x, 10);
    });

    test('alignCards left aligns to min x', () {
      notifier.alignCards(['c1', 'c2', 'c3'], AlignmentType.left);
      final cards = notifier.state.cards;
      final leftX = cards.firstWhere((c) => c.id == 'c1').x;
      expect(leftX, 10);
      for (final id in ['c2', 'c3']) {
        expect(cards.firstWhere((c) => c.id == id).x, leftX);
      }
    });

    test('alignCards right aligns to max right edge', () {
      notifier.alignCards(['c1', 'c2', 'c3'], AlignmentType.right);
      final cards = notifier.state.cards;
      final expectedRight = 350 + 100;
      for (final id in ['c1', 'c2']) {
        final card = cards.firstWhere((c) => c.id == id);
        expect(card.x + card.width, closeTo(expectedRight, 0.01));
      }
    });

    test('alignCards top aligns to min y', () {
      notifier.alignCards(['c1', 'c2', 'c3'], AlignmentType.top);
      final cards = notifier.state.cards;
      final topY = cards.firstWhere((c) => c.id == 'c1').y;
      expect(topY, 10);
      for (final id in ['c2', 'c3']) {
        expect(cards.firstWhere((c) => c.id == id).y, topY);
      }
    });

    test('alignCards bottom aligns to max bottom edge', () {
      notifier.alignCards(['c1', 'c2', 'c3'], AlignmentType.bottom);
      final cards = notifier.state.cards;
      final expectedBottom = 80 + 100;
      for (final id in ['c1', 'c2']) {
        final card = cards.firstWhere((c) => c.id == id);
        expect(card.y + card.height, closeTo(expectedBottom, 0.01));
      }
    });

    test('alignCards centerH aligns to average center x', () {
      notifier.alignCards(['c1', 'c2', 'c3'], AlignmentType.centerH);
      final cards = notifier.state.cards;
      final avgCenterX = (10 + 50 + 200 + 50 + 350 + 50) / 3;
      for (final card in cards) {
        expect(card.center.dx, closeTo(avgCenterX, 0.01));
      }
    });

    test('alignCards centerV aligns to average center y', () {
      notifier.alignCards(['c1', 'c2', 'c3'], AlignmentType.centerV);
      final cards = notifier.state.cards;
      final avgCenterY = (10 + 50 + 50 + 50 + 80 + 50) / 3;
      for (final card in cards) {
        expect(card.center.dy, closeTo(avgCenterY, 0.01));
      }
    });

    test('alignCards does not affect non-selected cards', () {
      final originalX = notifier.state.cards.firstWhere((c) => c.id == 'c3').x;
      notifier.alignCards(['c1', 'c2'], AlignmentType.left);
      final card3 = notifier.state.cards.firstWhere((c) => c.id == 'c3');
      expect(card3.x, originalX);
    });
  });

  group('CanvasNotifier - distributeCards', () {
    test('distributeCards with <3 cards returns early', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            x: 0,
            y: 0,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            x: 200,
            y: 0,
            width: 100,
            height: 100,
          ),
        ],
      );
      notifier.distributeCards(['c1', 'c2'], DistributeType.horizontal);
      expect(notifier.state.cards.firstWhere((c) => c.id == 'c1').x, 0);
    });

    test('distributeCards horizontal evenly spaces cards', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            x: 10,
            y: 0,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            x: 150,
            y: 0,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c3',
            type: CanvasCardType.text,
            x: 400,
            y: 0,
            width: 100,
            height: 100,
          ),
        ],
      );
      notifier.distributeCards(['c1', 'c2', 'c3'], DistributeType.horizontal);
      final cards = notifier.state.cards;
      final sorted = cards.toList()..sort((a, b) => a.x.compareTo(b.x));
      final totalGap = 400 - 10 - 300;
      final expectedGap = totalGap / 2;
      expect(sorted[0].x, 10);
      expect(sorted[1].x, closeTo(10 + 100 + expectedGap, 0.01));
      expect(sorted[2].x, closeTo(10 + 200 + totalGap, 0.01));
    });

    test('distributeCards vertical evenly spaces cards', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            x: 0,
            y: 10,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            x: 0,
            y: 150,
            width: 100,
            height: 100,
          ),
          CanvasCard(
            id: 'c3',
            type: CanvasCardType.text,
            x: 0,
            y: 400,
            width: 100,
            height: 100,
          ),
        ],
      );
      notifier.distributeCards(['c1', 'c2', 'c3'], DistributeType.vertical);
      final cards = notifier.state.cards;
      final sorted = cards.toList()..sort((a, b) => a.y.compareTo(b.y));
      final totalGap = 400 - 10 - 300;
      final expectedGap = totalGap / 2;
      expect(sorted[0].y, 10);
      expect(sorted[1].y, closeTo(10 + 100 + expectedGap, 0.01));
      expect(sorted[2].y, closeTo(10 + 200 + totalGap, 0.01));
    });
  });

  group('CanvasNotifier - batch updates', () {
    test('batchUpdateCardColor updates selected cards', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            colorValue: 0xFFFFFFFF,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            colorValue: 0xFFFFFFFF,
          ),
          CanvasCard(
            id: 'c3',
            type: CanvasCardType.text,
            colorValue: 0xFFFFFFFF,
          ),
        ],
      );
      notifier.batchUpdateCardColor(['c1', 'c3'], 0xFF333333);
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').colorValue,
        0xFF333333,
      );
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c2').colorValue,
        0xFFFFFFFF,
      );
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c3').colorValue,
        0xFF333333,
      );
    });

    test('batchMoveCards moves selected cards', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, x: 0, y: 0),
          CanvasCard(id: 'c2', type: CanvasCardType.text, x: 100, y: 100),
        ],
      );
      notifier.batchMoveCards({'c1': (50.0, 60.0), 'c2': (150.0, 160.0)});
      final c1 = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      final c2 = notifier.state.cards.firstWhere((c) => c.id == 'c2');
      expect(c1.x, 50);
      expect(c1.y, 60);
      expect(c2.x, 150);
      expect(c2.y, 160);
    });
  });

  group('CanvasNotifier - tags', () {
    test('addTag adds tag to card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, tags: ['existing']),
        ],
      );
      notifier.addTag('c1', 'new-tag');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').tags,
        containsAll(['existing', 'new-tag']),
      );
    });

    test('addTag does not add duplicate tag', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, tags: ['tag1']),
        ],
      );
      notifier.addTag('c1', 'tag1');
      expect(notifier.state.cards.firstWhere((c) => c.id == 'c1').tags, [
        'tag1',
      ]);
    });

    test('addTag does nothing for non-existent card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.addTag('nonexistent', 'tag');
    });

    test('removeTag removes tag from card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            tags: ['tag1', 'tag2'],
          ),
        ],
      );
      notifier.removeTag('c1', 'tag1');
      expect(notifier.state.cards.firstWhere((c) => c.id == 'c1').tags, [
        'tag2',
      ]);
    });

    test('removeTag does nothing for non-existent card', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.removeTag('nonexistent', 'tag');
    });
  });

  group('CanvasNotifier - card properties', () {
    test('setHyperlink sets hyperlink', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setHyperlink('c1', 'https://example.com');
      expect(
        notifier.state.cards
            .firstWhere((c) => c.id == 'c1')
            .metadata
            ?.hyperlink,
        'https://example.com',
      );
    });

    test('setHyperlink(null) clears hyperlink', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setHyperlink('c1', 'https://example.com');
      notifier.setHyperlink('c1', null);
      expect(
        notifier.state.cards
            .firstWhere((c) => c.id == 'c1')
            .metadata
            ?.hyperlink,
        isNull,
      );
    });

    test('setMetadata sets metadata', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      final meta = const CanvasCardMetadata(properties: {'key': 'value'});
      notifier.setMetadata('c1', meta);
      expect(
        notifier.state.cards
            .firstWhere((c) => c.id == 'c1')
            .metadata
            ?.properties,
        {'key': 'value'},
      );
    });

    test('setTextAlign sets alignment', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            textAlignH: TextAlignH.left,
            textAlignV: TextAlignV.top,
          ),
        ],
      );
      notifier.setTextAlign('c1', h: TextAlignH.center, v: TextAlignV.middle);
      final card = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      expect(card.textAlignH, TextAlignH.center);
      expect(card.textAlignV, TextAlignV.middle);
    });

    test('setTextAlign with partial params preserves existing', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            textAlignH: TextAlignH.left,
            textAlignV: TextAlignV.top,
          ),
        ],
      );
      notifier.setTextAlign('c1', h: TextAlignH.right);
      final card = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      expect(card.textAlignH, TextAlignH.right);
      expect(card.textAlignV, TextAlignV.top);
    });

    test('setFontFamily sets font', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setFontFamily('c1', 'Courier New');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').fontFamily,
        'Courier New',
      );
    });

    test('setTextColor sets text color', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setTextColor('c1', 0xFF123456);
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').textColorValue,
        0xFF123456,
      );
    });

    test('toggleAutoNumber toggles', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, autoNumber: false),
        ],
      );
      notifier.toggleAutoNumber('c1');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').autoNumber,
        true,
      );
      notifier.toggleAutoNumber('c1');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').autoNumber,
        false,
      );
    });

    test('setLatexFormula sets formula', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setLatexFormula('c1', 'E=mc^2');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').latexFormula,
        'E=mc^2',
      );
    });

    test('setLatexFormula(null) clears', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setLatexFormula('c1', 'E=mc^2');
      notifier.setLatexFormula('c1', null);
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').latexFormula,
        isNull,
      );
    });

    test('setHtmlContent sets html', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setHtmlContent('c1', '<b>bold</b>');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').htmlContent,
        '<b>bold</b>',
      );
    });

    test('setHtmlContent(null) clears', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setHtmlContent('c1', '<b>bold</b>');
      notifier.setHtmlContent('c1', null);
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').htmlContent,
        isNull,
      );
    });

    test('setCustomSvg sets svg', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setCustomSvg('c1', '<svg></svg>');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').customSvgData,
        '<svg></svg>',
      );
    });

    test('setCustomSvg(null) clears', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setCustomSvg('c1', '<svg></svg>');
      notifier.setCustomSvg('c1', null);
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').customSvgData,
        isNull,
      );
    });

    test('addSvgAsCustomShape sets svg', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.addSvgAsCustomShape('c1', '<svg>shape</svg>');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').customSvgData,
        '<svg>shape</svg>',
      );
    });
  });

  group('CanvasNotifier - other card methods', () {
    test('setFreehandPoints sets points', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.freehand)],
      );
      final points = [const Offset(10, 20), const Offset(30, 40)];
      notifier.setFreehandPoints('c1', points);
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').freehandPoints,
        points,
      );
    });

    test('setTableSize resizes table', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.table)],
      );
      notifier.setTableSize('c1', 5, 4);
      final card = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      expect(card.tableRows, 5);
      expect(card.tableCols, 4);
      expect(card.tableCells, hasLength(20));
    });

    test('setTableSize preserves existing cells', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.table,
            tableRows: 2,
            tableCols: 2,
            tableCells: const [
              CanvasTableCell(text: 'A'),
              CanvasTableCell(text: 'B'),
              CanvasTableCell(text: 'C'),
              CanvasTableCell(text: 'D'),
            ],
          ),
        ],
      );
      notifier.setTableSize('c1', 3, 3);
      final card = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      expect(card.tableRows, 3);
      expect(card.tableCols, 3);
      expect(card.tableCells, hasLength(9));
      expect(card.tableCells[0].text, 'A');
      expect(card.tableCells[1].text, 'B');
      expect(card.tableCells[2].text, 'C');
      expect(card.tableCells[3].text, 'D');
      expect(card.tableCells[4].text, '');
    });

    test('setTableCell sets cell text', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.table,
            tableRows: 2,
            tableCols: 2,
            tableCells: const [
              CanvasTableCell(text: ''),
              CanvasTableCell(text: ''),
              CanvasTableCell(text: ''),
              CanvasTableCell(text: ''),
            ],
          ),
        ],
      );
      notifier.setTableCell('c1', 0, 1, 'Hello');
      final card = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      expect(card.tableCells[1].text, 'Hello');
    });

    test('toggleVerticalText toggles', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, verticalText: false),
        ],
      );
      notifier.toggleVerticalText('c1');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').verticalText,
        true,
      );
      notifier.toggleVerticalText('c1');
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').verticalText,
        false,
      );
    });

    test('enumerateAllCards numbers autoNumber cards', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(
            id: 'c1',
            type: CanvasCardType.text,
            title: 'First',
            autoNumber: true,
          ),
          CanvasCard(
            id: 'c2',
            type: CanvasCardType.text,
            title: 'Second',
            autoNumber: false,
          ),
          CanvasCard(
            id: 'c3',
            type: CanvasCardType.text,
            title: 'Third',
            autoNumber: true,
          ),
        ],
      );
      notifier.enumerateAllCards();
      final c1 = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      final c2 = notifier.state.cards.firstWhere((c) => c.id == 'c2');
      final c3 = notifier.state.cards.firstWhere((c) => c.id == 'c3');
      expect(c1.title, '1. First');
      expect(c2.title, 'Second');
      expect(c3.title, '2. Third');
    });

    test('setRichContent sets segments', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      final segments = [
        const RichTextSegment(text: 'Hello', type: RichTextSegmentType.bold),
        const RichTextSegment(text: ' World'),
      ];
      notifier.setRichContent('c1', segments);
      expect(
        notifier.state.cards.firstWhere((c) => c.id == 'c1').richContent,
        segments,
      );
    });

    test('setConnectionPointOffset sets offsets clamped', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setConnectionPointOffset('c1', 0.7, 1.5);
      final card = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      expect(card.connectionPointOffsetX, 0.7);
      expect(card.connectionPointOffsetY, 1.0);
    });

    test('setConnectionPointOffset clamps to 0', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.setConnectionPointOffset('c1', -0.5, -0.2);
      final card = notifier.state.cards.firstWhere((c) => c.id == 'c1');
      expect(card.connectionPointOffsetX, 0.0);
      expect(card.connectionPointOffsetY, 0.0);
    });
  });

  group('CanvasNotifier - undo/redo', () {
    test('undo after adding card restores previous state', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final card = CanvasCard(id: 'c1', type: CanvasCardType.text);
      await notifier.addCard(card);
      expect(notifier.state.cards, hasLength(1));
      notifier.undo();
      expect(notifier.state.cards, isEmpty);
      expect(notifier.canRedo, true);
    });

    test('redo restores undone state', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final card = CanvasCard(id: 'c1', type: CanvasCardType.text);
      await notifier.addCard(card);
      notifier.undo();
      notifier.redo();
      expect(notifier.state.cards, hasLength(1));
      expect(notifier.canRedo, false);
    });

    test('undo does nothing when stack empty', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final previousState = notifier.state;
      notifier.undo();
      expect(notifier.state, previousState);
    });

    test('redo does nothing when stack empty', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final previousState = notifier.state;
      notifier.redo();
      expect(notifier.state, previousState);
    });

    test('new action after undo clears redo stack', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      await notifier.addCard(CanvasCard(id: 'c1', type: CanvasCardType.text));
      notifier.undo();
      expect(notifier.canRedo, true);
      await notifier.addCard(CanvasCard(id: 'c2', type: CanvasCardType.text));
      expect(notifier.canRedo, false);
    });
  });

  group('CanvasNotifier - add/remove cards & connections', () {
    test('addCard adds card to state', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final card = CanvasCard(id: 'c1', type: CanvasCardType.text);
      await notifier.addCard(card);
      expect(notifier.state.cards, [card]);
    });

    test('updateCard updates existing card', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      await notifier.addCard(
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'Old'),
      );
      await notifier.updateCard(
        CanvasCard(id: 'c1', type: CanvasCardType.text, title: 'New'),
      );
      expect(notifier.state.cards.first.title, 'New');
    });

    test('removeCard removes card and associated connections', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      await notifier.addCard(CanvasCard(id: 'c1', type: CanvasCardType.text));
      await notifier.addCard(CanvasCard(id: 'c2', type: CanvasCardType.text));
      await notifier.addConnection(
        CanvasConnection(id: 'conn1', fromCardId: 'c1', toCardId: 'c2'),
      );
      await notifier.removeCard('c1');
      expect(notifier.state.cards, hasLength(1));
      expect(notifier.state.cards.first.id, 'c2');
      expect(notifier.state.connections, isEmpty);
    });

    test('addConnection adds connection', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final conn = CanvasConnection(
        id: 'conn1',
        fromCardId: 'c1',
        toCardId: 'c2',
      );
      await notifier.addConnection(conn);
      expect(notifier.state.connections, [conn]);
    });

    test('removeConnection removes connection', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final conn = CanvasConnection(
        id: 'conn1',
        fromCardId: 'c1',
        toCardId: 'c2',
      );
      await notifier.addConnection(conn);
      await notifier.removeConnection('conn1');
      expect(notifier.state.connections, isEmpty);
    });

    test('updateConnection updates connection in memory', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        connections: [
          CanvasConnection(id: 'conn1', fromCardId: 'c1', toCardId: 'c2'),
        ],
      );
      notifier.updateConnection(
        CanvasConnection(
          id: 'conn1',
          fromCardId: 'c1',
          toCardId: 'c2',
          label: 'Updated',
        ),
      );
      expect(notifier.state.connections.first.label, 'Updated');
    });
  });

  group('CanvasNotifier - waypoints', () {
    test('addWaypoint adds waypoint', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        connections: [
          CanvasConnection(id: 'conn1', fromCardId: 'c1', toCardId: 'c2'),
        ],
      );
      notifier.addWaypoint('conn1', const Offset(50, 100));
      expect(notifier.state.connections.first.waypoints, [
        const Offset(50, 100),
      ]);
    });

    test('addWaypoint with insertIndex inserts at position', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        connections: [
          CanvasConnection(
            id: 'conn1',
            fromCardId: 'c1',
            toCardId: 'c2',
            waypoints: [const Offset(10, 20), const Offset(30, 40)],
          ),
        ],
      );
      notifier.addWaypoint('conn1', const Offset(50, 60), insertIndex: 1);
      expect(notifier.state.connections.first.waypoints, [
        const Offset(10, 20),
        const Offset(50, 60),
        const Offset(30, 40),
      ]);
    });

    test('removeWaypoint removes waypoint at index', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        connections: [
          CanvasConnection(
            id: 'conn1',
            fromCardId: 'c1',
            toCardId: 'c2',
            waypoints: [const Offset(10, 20), const Offset(30, 40)],
          ),
        ],
      );
      notifier.removeWaypoint('conn1', 0);
      expect(notifier.state.connections.first.waypoints, [
        const Offset(30, 40),
      ]);
    });

    test('removeWaypoint with invalid index does nothing', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        connections: [
          CanvasConnection(
            id: 'conn1',
            fromCardId: 'c1',
            toCardId: 'c2',
            waypoints: [const Offset(10, 20)],
          ),
        ],
      );
      notifier.removeWaypoint('conn1', 5);
      expect(notifier.state.connections.first.waypoints, hasLength(1));
    });

    test('moveWaypoint moves waypoint', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        connections: [
          CanvasConnection(
            id: 'conn1',
            fromCardId: 'c1',
            toCardId: 'c2',
            waypoints: [const Offset(10, 20)],
          ),
        ],
      );
      notifier.moveWaypoint('conn1', 0, const Offset(99, 88));
      expect(notifier.state.connections.first.waypoints, [
        const Offset(99, 88),
      ]);
    });
  });

  group('CanvasNotifier - groups', () {
    test('groupCards with <2 cards returns early', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      await notifier.groupCards(['c1']);
      expect(notifier.state.groups, isEmpty);
    });

    test('groupCards creates group with 2+ cards', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      await notifier.groupCards(['c1', 'c2']);
      expect(notifier.state.groups, hasLength(1));
      expect(notifier.state.groups.first.cardIds, ['c1', 'c2']);
    });

    test('groupCards with name sets custom name', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      await notifier.groupCards(['c1', 'c2'], name: 'Custom');
      expect(notifier.state.groups.first.name, 'Custom');
    });

    test('ungroupCards removes group', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        groups: [
          CanvasGroup(id: 'g1', name: 'G1', cardIds: ['c1', 'c2']),
        ],
      );
      await notifier.ungroupCards('g1');
      expect(notifier.state.groups, isEmpty);
    });

    test('renameGroup renames group', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        groups: [
          CanvasGroup(id: 'g1', name: 'Old Name', cardIds: ['c1']),
        ],
      );
      notifier.renameGroup('g1', 'New Name');
      expect(notifier.state.groups.first.name, 'New Name');
    });
  });

  group('CanvasNotifier - batch delete', () {
    test('batchDeleteCards removes cards', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text),
          CanvasCard(id: 'c2', type: CanvasCardType.text),
          CanvasCard(id: 'c3', type: CanvasCardType.text),
        ],
      );
      await notifier.batchDeleteCards(['c1', 'c3']);
      expect(notifier.state.cards, hasLength(1));
      expect(notifier.state.cards.first.id, 'c2');
    });

    test('batchDeleteCards removes connections', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text),
          CanvasCard(id: 'c2', type: CanvasCardType.text),
        ],
        connections: [
          CanvasConnection(id: 'conn1', fromCardId: 'c1', toCardId: 'c2'),
          CanvasConnection(id: 'conn2', fromCardId: 'c2', toCardId: 'c1'),
        ],
      );
      await notifier.batchDeleteCards(['c1']);
      expect(notifier.state.connections, isEmpty);
    });

    test('batchDeleteCards updates groups', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text),
          CanvasCard(id: 'c2', type: CanvasCardType.text),
        ],
        groups: [
          CanvasGroup(id: 'g1', name: 'G1', cardIds: ['c1', 'c2']),
        ],
      );
      await notifier.batchDeleteCards(['c1']);
      expect(notifier.state.groups.first.cardIds, ['c2']);
    });

    test('batchDeleteCards removes empty groups', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
        groups: [
          CanvasGroup(id: 'g1', name: 'G1', cardIds: ['c1']),
        ],
      );
      await notifier.batchDeleteCards(['c1']);
      expect(notifier.state.groups, isEmpty);
    });

    test('batchDeleteCards with empty list returns early', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final cards = [CanvasCard(id: 'c1', type: CanvasCardType.text)];
      notifier.state = CanvasData(cards: cards);
      await notifier.batchDeleteCards([]);
      expect(notifier.state.cards, hasLength(1));
    });
  });

  group('CanvasNotifier - clearCanvas', () {
    test('clearCanvas resets state', () async {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      await notifier.clearCanvas();
      expect(notifier.state.cards, isEmpty);
      expect(notifier.state.connections, isEmpty);
    });
  });

  group('CanvasNotifier - deriveAutoConnections', () {
    test('returns empty when auto connections disabled', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.toggleAutoConnections();
      final result = notifier.deriveAutoConnections([], null);
      expect(result, isEmpty);
    });

    test('returns empty when linkResolver is null', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final result = notifier.deriveAutoConnections([], null);
      expect(result, isEmpty);
    });

    test('returns empty when fewer than 2 cards with noteId', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.note, noteId: 'note1'),
        ],
      );
      final result = notifier.deriveAutoConnections([], null);
      expect(result, isEmpty);
    });
  });

  group('CanvasNotifier - tag filter', () {
    test('setSelectedLayer with null shows all', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        layers: [CanvasLayer(id: 'l1', name: 'Work', order: 0)],
      );
      notifier.setSelectedLayer(null);
      expect(notifier.state.selectedLayerId, isNull);
    });

    test('setSelectedLayer filters by layer id', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        layers: [CanvasLayer(id: 'l1', name: 'Work', order: 0)],
      );
      notifier.setSelectedLayer('l1');
      expect(notifier.state.selectedLayerId, 'l1');
    });

    test(
      'setSelectedLayer with unassigned sentinel filters to null layerId cards',
      () {
        final container = createContainer();
        final notifier = container.read(canvasProvider.notifier);
        notifier.setSelectedLayer(CanvasData.unassignedSentinel);
        expect(notifier.state.selectedLayerId, CanvasData.unassignedSentinel);
      },
    );

    test('unassignedCardCount counts cards without layerId', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text),
          CanvasCard(id: 'c2', type: CanvasCardType.text, layerId: 'l1'),
          CanvasCard(id: 'c3', type: CanvasCardType.text),
        ],
        layers: [CanvasLayer(id: 'l1', name: 'L1', order: 0)],
      );
      expect(notifier.unassignedCardCount, 2);
    });

    test('unassignedCardCount returns 0 when all cards have layerId', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, layerId: 'l1'),
          CanvasCard(id: 'c2', type: CanvasCardType.text, layerId: 'l2'),
        ],
        layers: [
          CanvasLayer(id: 'l1', name: 'L1', order: 0),
          CanvasLayer(id: 'l2', name: 'L2', order: 1),
        ],
      );
      expect(notifier.unassignedCardCount, 0);
    });

    test('selectedLayerId persisted in toJsonString and fromJsonString', () {
      final data = CanvasData(
        layers: [CanvasLayer(id: 'l1', name: 'Work', order: 0)],
        selectedLayerId: 'l1',
      );
      final json = data.toJsonString();
      final restored = CanvasData.fromJsonString(json);
      expect(restored.selectedLayerId, 'l1');
    });

    test('selectedLayerId null not persisted in JSON', () {
      final data = CanvasData(selectedLayerId: null);
      final json = data.toJsonString();
      expect(json.contains('selectedLayerId'), isFalse);
    });

    test('unassignedSentinel persisted and restored correctly', () {
      final data = CanvasData(selectedLayerId: CanvasData.unassignedSentinel);
      final json = data.toJsonString();
      final restored = CanvasData.fromJsonString(json);
      expect(restored.selectedLayerId, CanvasData.unassignedSentinel);
    });

    test('old JSON without selectedLayerId defaults to null', () {
      final json =
          '{"cards":[],"connections":[],"groups":[],"layers":[],"settings":{"autoConnectionsEnabled":true,"snapToGrid":true,"gridVisible":true,"lastModified":"2026-01-01T00:00:00.000"}}';
      final data = CanvasData.fromJsonString(json);
      expect(data.selectedLayerId, isNull);
    });

    test('cardCountForLayer delegates to layers service', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      notifier.state = CanvasData(
        cards: [
          CanvasCard(id: 'c1', type: CanvasCardType.text, layerId: 'l1'),
          CanvasCard(id: 'c2', type: CanvasCardType.text, layerId: 'l1'),
          CanvasCard(id: 'c3', type: CanvasCardType.text, layerId: 'l2'),
        ],
        layers: [
          CanvasLayer(id: 'l1', name: 'L1', order: 0),
          CanvasLayer(id: 'l2', name: 'L2', order: 1),
        ],
      );
      expect(notifier.cardCountForLayer('l1'), 2);
      expect(notifier.cardCountForLayer('l2'), 1);
    });

    test('isLayerLocked returns false (always)', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.isLayerLocked('c1'), false);
    });

    test('isLayerVisible returns true (always)', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      expect(notifier.isLayerVisible('c1'), true);
    });
  });

  group('CanvasNotifier - loadTemplate / loadFromData', () {
    test('loadFromData replaces state', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final newData = CanvasData(
        cards: [CanvasCard(id: 'c1', type: CanvasCardType.text)],
      );
      notifier.loadFromData(newData);
      expect(notifier.state.cards, hasLength(1));
      expect(notifier.state.cards.first.id, 'c1');
    });

    test('loadTemplate does nothing for unknown template', () {
      final container = createContainer();
      final notifier = container.read(canvasProvider.notifier);
      final originalState = notifier.state;
      notifier.loadTemplate('nonexistent_template');
      expect(notifier.state, originalState);
    });
  });
}

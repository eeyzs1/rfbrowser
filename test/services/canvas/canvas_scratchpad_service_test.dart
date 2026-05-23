import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/services/canvas/canvas_scratchpad_service.dart';

void main() {
  group('CanvasScratchpadService', () {
    late String tempVaultDir;
    const service = CanvasScratchpadService();

    setUp(() async {
      tempVaultDir = p.join(
        Directory.systemTemp.path,
        'rfbrowser_test_scratchpad_${DateTime.now().millisecondsSinceEpoch}',
      );
      await Directory(tempVaultDir).create(recursive: true);
      await Directory(p.join(tempVaultDir, '.rf')).create(recursive: true);
    });

    tearDown(() {
      if (Directory(tempVaultDir).existsSync()) {
        Directory(tempVaultDir).deleteSync(recursive: true);
      }
    });

    group('loadScratchpad', () {
      test('returns empty list for empty vault', () async {
        final items = await service.loadScratchpad(tempVaultDir);
        expect(items, isEmpty);
      });

      test('loads previously saved items', () async {
        final item = ScratchpadItem(
          id: 's1',
          name: 'Rectangle',
          type: CanvasCardType.rectangle,
          width: 100,
          height: 50,
          colorValue: 0xFFAABBCC,
        );
        await service.saveScratchpadItem(tempVaultDir, item);

        final loaded = await service.loadScratchpad(tempVaultDir);
        expect(loaded.length, 1);
        expect(loaded[0].id, 's1');
        expect(loaded[0].name, 'Rectangle');
        expect(loaded[0].width, 100);
        expect(loaded[0].height, 50);
        expect(loaded[0].colorValue, 0xFFAABBCC);
      });
    });

    group('saveScratchpadItem', () {
      test('appends new item to scratchpad', () async {
        await service.saveScratchpadItem(
          tempVaultDir,
          ScratchpadItem(
            id: 's1',
            name: 'First',
            type: CanvasCardType.rectangle,
            width: 100,
            height: 50,
            colorValue: 0xFFFFFFFF,
          ),
        );
        await service.saveScratchpadItem(
          tempVaultDir,
          ScratchpadItem(
            id: 's2',
            name: 'Second',
            type: CanvasCardType.ellipse,
            width: 80,
            height: 40,
            colorValue: 0xFF000000,
          ),
        );

        final loaded = await service.loadScratchpad(tempVaultDir);
        expect(loaded.length, 2);
      });

      test('persists items to JSON file', () async {
        await service.saveScratchpadItem(
          tempVaultDir,
          ScratchpadItem(
            id: 's1',
            name: 'Sticky',
            type: CanvasCardType.text,
            width: 120,
            height: 80,
            colorValue: 0xFFFFEEAA,
          ),
        );

        final file = File(p.join(tempVaultDir, '.rf', 'scratchpad.json'));
        expect(await file.exists(), isTrue);
        final json = jsonDecode(await file.readAsString()) as List;
        expect(json.length, 1);
        expect(json[0]['name'], 'Sticky');
      });
    });

    group('removeScratchpadItem', () {
      test('removes item by id', () async {
        await service.saveScratchpadItem(
          tempVaultDir,
          ScratchpadItem(
            id: 's1',
            name: 'A',
            type: CanvasCardType.rectangle,
            width: 100,
            height: 50,
            colorValue: 0xFFFFFFFF,
          ),
        );
        await service.saveScratchpadItem(
          tempVaultDir,
          ScratchpadItem(
            id: 's2',
            name: 'B',
            type: CanvasCardType.rectangle,
            width: 100,
            height: 50,
            colorValue: 0xFFFFFFFF,
          ),
        );

        await service.removeScratchpadItem(tempVaultDir, 's1');
        final loaded = await service.loadScratchpad(tempVaultDir);
        expect(loaded.length, 1);
        expect(loaded[0].id, 's2');
      });

      test('handles removing non-existent item', () async {
        await service.removeScratchpadItem(tempVaultDir, 'nonexistent');
        final loaded = await service.loadScratchpad(tempVaultDir);
        expect(loaded, isEmpty);
      });
    });

    group('createCardFromScratchpad', () {
      test('creates card from scratchpad item', () {
        final item = ScratchpadItem(
          id: 's1',
          name: 'Test Shape',
          type: CanvasCardType.ellipse,
          width: 120,
          height: 60,
          colorValue: 0xFF998877,
          style: const CanvasCardStyle(borderRadius: 5),
        );

        final card = service.createCardFromScratchpad(
          item,
          const Offset(300, 400),
        );
        expect(card.type, CanvasCardType.ellipse);
        expect(card.x, 300);
        expect(card.y, 400);
        expect(card.width, 120);
        expect(card.height, 60);
        expect(card.colorValue, 0xFF998877);
        expect(card.title, 'Test Shape');
        expect(card.style?.borderRadius, 5);
        expect(card.id, startsWith('card_'));
      });

      test('creates unique card IDs', () {
        final item = ScratchpadItem(
          id: 's1',
          name: 'Test',
          type: CanvasCardType.rectangle,
          width: 100,
          height: 50,
          colorValue: 0xFFFFFFFF,
        );
        final card1 = service.createCardFromScratchpad(item, Offset.zero);
        final card2 = service.createCardFromScratchpad(item, Offset.zero);
        expect(card1.id, isNot(card2.id));
      });

      test('handles item without style', () {
        final item = ScratchpadItem(
          id: 's1',
          name: 'Simple',
          type: CanvasCardType.rectangle,
          width: 100,
          height: 50,
          colorValue: 0xFF000000,
        );
        final card = service.createCardFromScratchpad(item, Offset.zero);
        expect(card.style, isNull);
      });
    });
  });
}

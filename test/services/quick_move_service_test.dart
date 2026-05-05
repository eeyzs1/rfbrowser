import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/services/quick_move_service.dart';
import 'package:rfbrowser/data/models/quick_move.dart';

void main() {
  group('QuickMoveNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    QuickMoveNotifier notifier() =>
        container.read(quickMoveProvider.notifier);

    QuickMoveState state() => container.read(quickMoveProvider);

    test('initial state contains presets', () {
      expect(state().moves.length, greaterThanOrEqualTo(5));
    });

    test('createMove adds a new move', () {
      final beforeCount = state().moves.length;
      notifier().createMove('test', 'prompt {input}');
      expect(
        container.read(quickMoveProvider).moves.length,
        beforeCount + 1,
      );
    });

    test('updateMove modifies existing move', () async {
      final move = await notifier().createMove('original', 'prompt {input}');
      await notifier().updateMove(move.id, name: 'updated');

      final updated = container.read(quickMoveProvider).byId[move.id];
      expect(updated!.name, 'updated');
    });

    test('deleteMove removes the move', () async {
      final move = await notifier().createMove('toDelete', 'prompt {input}');
      final beforeCount = state().moves.length;

      await notifier().deleteMove(move.id);

      expect(container.read(quickMoveProvider).moves.length, beforeCount - 1);
      expect(
        container.read(quickMoveProvider).byId[move.id],
        isNull,
      );
    });

    test('reorderMove changes position', () async {
      final a = await notifier().createMove('A', '');
      await notifier().createMove('B', '');
      await notifier().createMove('C', '');

      final presetCount =
          container.read(quickMoveProvider).moves.where((m) => m.type == QuickMoveType.preset).length;

      notifier().reorderMove(a.id, presetCount + 2);

      final moves = container.read(quickMoveProvider).moves;
      final userMoves =
          moves.where((m) => m.type == QuickMoveType.user).toList();
      expect(userMoves[0].name, 'B');
      expect(userMoves[1].name, 'C');
      expect(userMoves[2].name, 'A');
    });

    test('restoreDefaults re-adds deleted presets', () async {
      final currentState = state();
      final presets = currentState.moves
          .where((m) => m.type == QuickMoveType.preset)
          .toList();
      for (final p in presets) {
        await notifier().deleteMove(p.id);
      }

      var current = container.read(quickMoveProvider);
      final presetCountAfterDelete =
          current.moves.where((m) => m.type == QuickMoveType.preset).length;
      expect(presetCountAfterDelete, 0);

      await notifier().restoreDefaults();

      current = container.read(quickMoveProvider);
      final presetCountAfterRestore =
          current.moves.where((m) => m.type == QuickMoveType.preset).length;
      expect(presetCountAfterRestore, greaterThanOrEqualTo(5));
    });

    test('recordUsage increments useCount and updates lastUsedAt', () async {
      final move = await notifier().createMove('test', '');
      final originalCount = move.useCount;

      notifier().recordUsage(move.id);

      final updated = container.read(quickMoveProvider).byId[move.id];
      expect(updated!.useCount, originalCount + 1);
      expect(updated.lastUsedAt, isNotNull);
    });

    test('findMatch returns matching moves', () async {
      await notifier().createMove('翻译助手', '');
      await notifier().createMove('other', '');

      final results = notifier().findMatch('翻');
      expect(results.any((m) => m.name.contains('翻')), isTrue);
    });

    test('findMatch with empty string returns all', () {
      final results = notifier().findMatch('');
      expect(results.length, state().moves.length);
    });

    test('resolvePrompt returns resolved string', () {
      final move = QuickMove(
        name: 'test',
        promptTemplate: 'Hello {input}',
      );
      final result = notifier().resolvePrompt(move, {'input': 'World'});
      expect(result, 'Hello World');
    });

    test('exportToJson produces valid JSON', () {
      final json = notifier().exportToJson();
      expect(json.isNotEmpty, isTrue);
      expect(json.startsWith('{'), isTrue);
    });

    test('importFromJson restores state from valid JSON', () async {
      const json =
          '{"moves":[{"id":"test","name":"Imported","promptTemplate":"{input}","iconCodePoint":59582,"colorValue":4278190080,"type":"user","createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-01T00:00:00.000","useCount":0}]}';
      final success = await notifier().importFromJson(json);
      expect(success, isTrue);

      final current = container.read(quickMoveProvider);
      expect(
        current.moves.any((m) => m.name == 'Imported'),
        isTrue,
      );
    });

    test('importFromJson with invalid JSON returns false', () async {
      final before = container.read(quickMoveProvider);
      final success = await notifier().importFromJson('not json');
      expect(success, isFalse);
      final after = container.read(quickMoveProvider);
      expect(after.moves.length, before.moves.length);
    });
  });

  group('quickMoveContextProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial context has all nulls', () {
      final ctx = container.read(quickMoveContextProvider);
      expect(ctx.currentUrl, isNull);
      expect(ctx.pageTitle, isNull);
      expect(ctx.pageContent, isNull);
      expect(ctx.selectedText, isNull);
      expect(ctx.noteContent, isNull);
    });

    test('can update context fields', () {
      container.read(quickMoveContextProvider.notifier).update(
            QuickMoveContext(
              currentUrl: 'https://example.com',
              pageTitle: 'Test Page',
            ),
          );

      final ctx = container.read(quickMoveContextProvider);
      expect(ctx.currentUrl, 'https://example.com');
      expect(ctx.pageTitle, 'Test Page');
    });
  });
}

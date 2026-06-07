import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/services/quick_move_service.dart';
import 'package:rfbrowser/data/models/quick_move.dart';

void main() {
  group('Quick Move Integration', () {
    late ProviderContainer container;
    late QuickMoveNotifier notifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      notifier = container.read(quickMoveProvider.notifier);
      // Wait for the async _loadFromStore() in build() to complete
      await Future.delayed(Duration.zero);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has preset quick moves', () {
      final state = container.read(quickMoveProvider);
      expect(state.moves, isNotEmpty);
      expect(state.moves.any((m) => m.type == QuickMoveType.preset), isTrue);
    });

    test('createMove adds a user quick move', () async {
      final move = await notifier.createMove('Summarize', '请总结以下内容：');

      final state = container.read(quickMoveProvider);
      expect(state.moves.any((m) => m.id == move.id), isTrue);
      expect(move.name, 'Summarize');
      expect(move.promptTemplate, '请总结以下内容：');
      expect(move.type, QuickMoveType.user);
    });

    test('createMove with custom icon and color', () async {
      final move = await notifier.createMove(
        'Translate',
        '翻译以下内容：',
        iconCodePoint: 0xe0a2,
        colorValue: 0xFF8B5CF6,
      );

      expect(move.iconCodePoint, 0xe0a2);
      expect(move.colorValue, 0xFF8B5CF6);
    });

    test('updateMove modifies existing move', () async {
      final move = await notifier.createMove('Old Name', 'Old prompt');

      await notifier.updateMove(move.id, name: 'New Name');

      final state = container.read(quickMoveProvider);
      final updated = state.moves.firstWhere((m) => m.id == move.id);
      expect(updated.name, 'New Name');
    });

    test('updateMove changes prompt template', () async {
      final move = await notifier.createMove('Test', 'Prompt 1');

      await notifier.updateMove(move.id, promptTemplate: 'Prompt 2');

      final state = container.read(quickMoveProvider);
      final updated = state.moves.firstWhere((m) => m.id == move.id);
      expect(updated.promptTemplate, 'Prompt 2');
    });

    test('updateMove changes icon and color', () async {
      final move = await notifier.createMove('Test', 'Prompt');

      await notifier.updateMove(
        move.id,
        iconCodePoint: 0xe5d2,
        colorValue: 0xFF10B981,
      );

      final state = container.read(quickMoveProvider);
      final updated = state.moves.firstWhere((m) => m.id == move.id);
      expect(updated.iconCodePoint, 0xe5d2);
      expect(updated.colorValue, 0xFF10B981);
    });

    test('deleteMove removes a user quick move', () async {
      final move = await notifier.createMove('Temp', 'Temp prompt');

      await notifier.deleteMove(move.id);

      final state = container.read(quickMoveProvider);
      expect(state.moves.any((m) => m.id == move.id), isFalse);
    });

    test('deleteMove does not remove preset moves', () async {
      final state = container.read(quickMoveProvider);
      final presetCount = state.moves.where((m) => m.type == QuickMoveType.preset).length;
      expect(presetCount, greaterThan(0));

      final preset = state.moves.firstWhere((m) => m.type == QuickMoveType.preset);
      await notifier.deleteMove(preset.id);

      final afterState = container.read(quickMoveProvider);
      expect(afterState.moves.any((m) => m.id == preset.id), isTrue);
    });

    test('reorderMove changes move position', () async {
      final m1 = await notifier.createMove('A', 'Prompt A');
      final m2 = await notifier.createMove('B', 'Prompt B');

      final state = container.read(quickMoveProvider);
      final idx1 = state.moves.indexWhere((m) => m.id == m1.id);
      final idx2 = state.moves.indexWhere((m) => m.id == m2.id);

      notifier.reorderMove(m1.id, idx2);

      final afterState = container.read(quickMoveProvider);
      final newIdx1 = afterState.moves.indexWhere((m) => m.id == m1.id);
      expect(newIdx1, isNot(idx1));
    });

    test('full quick move lifecycle: create, update, delete', () async {
      final move = await notifier.createMove('Lifecycle', 'Original prompt');
      expect(container.read(quickMoveProvider).moves.any((m) => m.id == move.id), isTrue);

      await notifier.updateMove(move.id, name: 'Updated', promptTemplate: 'Updated prompt');
      final updated = container.read(quickMoveProvider).moves.firstWhere((m) => m.id == move.id);
      expect(updated.name, 'Updated');
      expect(updated.promptTemplate, 'Updated prompt');

      await notifier.deleteMove(move.id);
      expect(container.read(quickMoveProvider).moves.any((m) => m.id == move.id), isFalse);
    });
  });
}
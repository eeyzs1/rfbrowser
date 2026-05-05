import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/quick_move.dart';

void main() {
  group('QuickMove', () {
    test('fromJson and toJson round-trip', () {
      final move = QuickMove(
        name: '翻译',
        promptTemplate: 'Translate: {input}',
        iconCodePoint: 0xe8e2,
        colorValue: 0xFF64748B,
        type: QuickMoveType.user,
      );

      final json = move.toJson();
      final restored = QuickMove.fromJson(json);

      expect(restored.id, move.id);
      expect(restored.name, move.name);
      expect(restored.promptTemplate, move.promptTemplate);
      expect(restored.iconCodePoint, move.iconCodePoint);
      expect(restored.colorValue, move.colorValue);
      expect(restored.type, move.type);
    });

    test('resolvePrompt replaces placeholders', () {
      final move = QuickMove(
        name: 'test',
        promptTemplate: 'Hello {input}, from {pageUrl}',
      );

      final result = move.resolvePrompt({
        'input': 'World',
        'pageUrl': 'https://example.com',
      });

      expect(result, 'Hello World, from https://example.com');
    });

    test('resolvePrompt handles missing placeholders gracefully', () {
      final move = QuickMove(
        name: 'test',
        promptTemplate: '{input} {missing} end',
      );

      final result = move.resolvePrompt({'input': 'hi'});

      expect(result, 'hi {missing} end');
    });

    test('resolvePrompt returns template unchanged when no placeholders', () {
      final move = QuickMove(
        name: 'test',
        promptTemplate: 'No placeholders',
      );

      final result = move.resolvePrompt({});

      expect(result, 'No placeholders');
    });

    test('resolvePrompt handles repeated placeholders', () {
      final move = QuickMove(
        name: 'test',
        promptTemplate: '{input}{input}',
      );

      final result = move.resolvePrompt({'input': 'x'});

      expect(result, 'xx');
    });

    test('copyWith updates fields and preserves others', () {
      final move = QuickMove(
        id: 'test-id',
        name: 'original',
        promptTemplate: 'original template',
      );

      final updated = move.copyWith(name: 'updated');

      expect(updated.id, 'test-id');
      expect(updated.name, 'updated');
      expect(updated.promptTemplate, 'original template');
    });
  });

  group('QuickMoveState', () {
    test('matching with empty string returns all moves', () {
      final state = QuickMoveState.initial();
      final results = state.matching('');
      expect(results.length, state.moves.length);
    });

    test('matching with partial text filters moves', () {
      final state = QuickMoveState.initial();
      final results = state.matching('翻');
      expect(results.length, greaterThanOrEqualTo(1));
      expect(results.every((m) => m.name.contains('翻')), isTrue);
    });

    test('matching is case-insensitive', () {
      final moves = [
        QuickMove(id: '1', name: 'Translate', promptTemplate: ''),
        QuickMove(id: '2', name: 'TRANSLATE', promptTemplate: ''),
      ];
      final state = QuickMoveState(moves: moves);

      final results = state.matching('translate');
      expect(results.length, 2);
    });

    test('matching with no matches returns empty list', () {
      final state = QuickMoveState.initial();
      final results = state.matching('nonexistent_xyz');
      expect(results, isEmpty);
    });

    test('byLastUsed sorts by lastUsedAt descending', () {
      final now = DateTime.now();
      final moves = [
        QuickMove(
          id: '1',
          name: 'A',
          promptTemplate: '',
          lastUsedAt: now.subtract(const Duration(hours: 2)),
          useCount: 1,
        ),
        QuickMove(
          id: '2',
          name: 'B',
          promptTemplate: '',
          lastUsedAt: now,
          useCount: 1,
        ),
        QuickMove(
          id: '3',
          name: 'C',
          promptTemplate: '',
          lastUsedAt: now.subtract(const Duration(hours: 1)),
          useCount: 1,
        ),
      ];
      final state = QuickMoveState(moves: moves);

      final sorted = state.byLastUsed;
      expect(sorted[0].name, 'B');
      expect(sorted[1].name, 'C');
      expect(sorted[2].name, 'A');
    });

    test('fromJson and toJson round-trip', () {
      final state = QuickMoveState.initial();
      final json = state.toJson();
      final restored = QuickMoveState.fromJson(json);

      expect(restored.moves.length, state.moves.length);
      for (var i = 0; i < restored.moves.length; i++) {
        expect(restored.moves[i].id, state.moves[i].id);
      }
    });

    test('copyWith rebuilds byId map', () {
      final moves = [
        QuickMove(id: '1', name: 'A', promptTemplate: ''),
      ];
      final state = QuickMoveState(moves: moves);
      final updated = state.copyWith(moves: [
        QuickMove(id: '1', name: 'A_updated', promptTemplate: ''),
        QuickMove(id: '2', name: 'B', promptTemplate: ''),
      ]);

      expect(updated.byId.length, 2);
      expect(updated.byId['1']!.name, 'A_updated');
      expect(updated.byId['2']!.name, 'B');
    });
  });

  group('QuickMove.defaultPresets', () {
    test('returns at least 5 presets', () {
      final presets = QuickMove.defaultPresets();
      expect(presets.length, greaterThanOrEqualTo(5));
    });

    test('all presets have {input} in promptTemplate', () {
      final presets = QuickMove.defaultPresets();
      for (final p in presets) {
        expect(p.promptTemplate.contains('{input}'), isTrue,
            reason: '${p.name} should contain {input}');
      }
    });

    test('all presets have unique IDs', () {
      final presets = QuickMove.defaultPresets();
      final ids = presets.map((p) => p.id).toSet();
      expect(ids.length, presets.length);
    });

    test('all presets are QuickMoveType.preset', () {
      final presets = QuickMove.defaultPresets();
      for (final p in presets) {
        expect(p.type, QuickMoveType.preset);
      }
    });
  });

  group('QuickMoveContext', () {
    test('copyWith updates individual fields', () {
      final ctx = QuickMoveContext();
      final updated = ctx.copyWith(
        currentUrl: 'https://example.com',
        selectedText: 'hello',
      );

      expect(updated.currentUrl, 'https://example.com');
      expect(updated.selectedText, 'hello');
      expect(updated.pageTitle, isNull);
    });

    test('copyWith with clear flags sets fields to null', () {
      final ctx = QuickMoveContext(currentUrl: 'https://example.com');
      final cleared = ctx.copyWith(clearCurrentUrl: true);

      expect(cleared.currentUrl, isNull);
    });
  });
}

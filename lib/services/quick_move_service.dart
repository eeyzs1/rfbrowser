import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/quick_move.dart';
import '../data/stores/quick_move_store.dart';

class QuickMoveNotifier extends Notifier<QuickMoveState> {
  QuickMoveStore get _store => QuickMoveStore();

  @override
  QuickMoveState build() {
    _loadFromStore();
    return QuickMoveState.initial();
  }

  Future<void> _loadFromStore() async {
    final stored = await _store.load();
    state = stored;
  }

  Future<QuickMove> createMove(
    String name,
    String promptTemplate, {
    int? iconCodePoint,
    int? colorValue,
  }) async {
    final move = QuickMove(
      name: name,
      promptTemplate: promptTemplate,
      iconCodePoint: iconCodePoint ?? 0xe0a2,
      colorValue: colorValue ?? 0xFF0EA5E9,
      type: QuickMoveType.user,
    );
    final updatedMoves = [...state.moves, move];
    state = state.copyWith(moves: updatedMoves);
    await _store.save(state);
    return move;
  }

  Future<void> updateMove(
    String id, {
    String? name,
    String? promptTemplate,
    int? iconCodePoint,
    int? colorValue,
  }) async {
    final idx = state.moves.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    final move = state.moves[idx];
    final updated = move.copyWith(
      name: name ?? move.name,
      promptTemplate: promptTemplate ?? move.promptTemplate,
      iconCodePoint: iconCodePoint ?? move.iconCodePoint,
      colorValue: colorValue ?? move.colorValue,
    );
    final updatedMoves = List<QuickMove>.from(state.moves);
    updatedMoves[idx] = updated;
    state = state.copyWith(moves: updatedMoves);
    await _store.save(state);
  }

  Future<void> deleteMove(String id) async {
    final updatedMoves = state.moves.where((m) => m.id != id).toList();
    state = state.copyWith(moves: updatedMoves);
    await _store.save(state);
  }

  void reorderMove(String id, int newIndex) {
    final currentIndex = state.moves.indexWhere((m) => m.id == id);
    if (currentIndex < 0) return;

    final updatedMoves = List<QuickMove>.from(state.moves);
    final move = updatedMoves.removeAt(currentIndex);
    final clampedIndex = newIndex.clamp(0, updatedMoves.length);
    updatedMoves.insert(clampedIndex, move);
    state = state.copyWith(moves: updatedMoves);
  }

  Future<void> restoreDefaults() async {
    final presets = QuickMove.defaultPresets();
    final userMoves = state.moves
        .where((m) => m.type == QuickMoveType.user)
        .toList();
    final existingPresetIds =
        state.moves.where((m) => m.type == QuickMoveType.preset).map((m) => m.id).toSet();
    final mergedPresets = presets.where((p) => !existingPresetIds.contains(p.id)).toList();
    final updatedMoves = [...userMoves, ...mergedPresets];
    state = state.copyWith(moves: updatedMoves);
    await _store.save(state);
  }

  void recordUsage(String id) {
    final idx = state.moves.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    final move = state.moves[idx];
    final updated = move.copyWith(
      lastUsedAt: DateTime.now(),
      useCount: move.useCount + 1,
    );
    final updatedMoves = List<QuickMove>.from(state.moves);
    updatedMoves[idx] = updated;
    state = state.copyWith(moves: updatedMoves);
  }

  String resolvePrompt(QuickMove move, Map<String, String> args) {
    return move.resolvePrompt(args);
  }

  List<QuickMove> findMatch(String prefix) {
    return state.matching(prefix);
  }

  String exportToJson() {
    return _store.exportToJson(state);
  }

  Future<bool> importFromJson(String json) async {
    final success = await _store.importFromJson(json);
    if (success) {
      await _loadFromStore();
    }
    return success;
  }
}

final quickMoveProvider =
    NotifierProvider<QuickMoveNotifier, QuickMoveState>(QuickMoveNotifier.new);

class QuickMoveContextNotifier extends Notifier<QuickMoveContext> {
  @override
  QuickMoveContext build() => QuickMoveContext();

  void update(QuickMoveContext context) {
    state = context;
  }
}

final quickMoveContextProvider =
    NotifierProvider<QuickMoveContextNotifier, QuickMoveContext>(
        QuickMoveContextNotifier.new);

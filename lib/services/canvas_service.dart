import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/model/canvas_model.dart';

class CanvasNotifier extends Notifier<CanvasData> {
  Timer? _debounceTimer;

  @override
  CanvasData build() => const CanvasData();

  Future<void> loadCanvas() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('canvas_data');
    if (json != null) {
      state = CanvasData.fromJsonString(json);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('canvas_data', state.toJsonString());
  }

  void _debouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _save();
    });
  }

  void updateCardInMemory(CanvasCard card) {
    final cards = state.cards.map((c) => c.id == card.id ? card : c).toList();
    state = state.copyWith(cards: cards);
    _debouncedSave();
  }

  Future<void> persist() async {
    _debounceTimer?.cancel();
    await _save();
  }

  Future<void> addCard(CanvasCard card) async {
    state = state.copyWith(cards: [...state.cards, card]);
    await _save();
  }

  Future<void> updateCard(CanvasCard card) async {
    final cards = state.cards.map((c) => c.id == card.id ? card : c).toList();
    state = state.copyWith(cards: cards);
    await _save();
  }

  Future<void> removeCard(String cardId) async {
    state = state.copyWith(
      cards: state.cards.where((c) => c.id != cardId).toList(),
      connections: state.connections
          .where((c) => c.fromCardId != cardId && c.toCardId != cardId)
          .toList(),
    );
    await _save();
  }

  Future<void> addConnection(CanvasConnection conn) async {
    state = state.copyWith(connections: [...state.connections, conn]);
    await _save();
  }

  Future<void> removeConnection(String connId) async {
    state = state.copyWith(
      connections: state.connections.where((c) => c.id != connId).toList(),
    );
    await _save();
  }

  Future<void> clearCanvas() async {
    state = const CanvasData();
    await _save();
  }

  CanvasCard? cardById(String id) {
    try {
      return state.cards.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasData>(
  CanvasNotifier.new,
);

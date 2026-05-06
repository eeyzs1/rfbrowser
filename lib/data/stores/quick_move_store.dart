import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_move.dart';

class QuickMoveStore {
  static const _key = 'quick_moves_state';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<QuickMoveState> load() async {
    final prefs = await _ensurePrefs;
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) {
      return QuickMoveState.initial();
    }
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return QuickMoveState.fromJson(json);
    } catch (_) {
      return QuickMoveState.initial();
    }
  }

  Future<void> save(QuickMoveState state) async {
    final prefs = await _ensurePrefs;
    final jsonStr = jsonEncode(state.toJson());
    await prefs.setString(_key, jsonStr);
  }

  String exportToJson(QuickMoveState state) {
    return jsonEncode(state.toJson());
  }

  Future<bool> importFromJson(String json) async {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final state = QuickMoveState.fromJson(decoded);
      await save(state);
      return true;
    } catch (_) {
      return false;
    }
  }
}

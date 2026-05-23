import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../data/models/canvas_model.dart';

class CanvasScratchpadService {
  const CanvasScratchpadService();

  Future<List<ScratchpadItem>> loadScratchpad(String vaultPath) async {
    try {
      final file = File(p.join(vaultPath, '.rf', 'scratchpad.json'));
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString()) as List;
      return json
          .map((e) => ScratchpadItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveScratchpadItem(String vaultPath, ScratchpadItem item) async {
    final items = await loadScratchpad(vaultPath);
    items.add(item);
    await _saveScratchpad(vaultPath, items);
  }

  Future<void> removeScratchpadItem(String vaultPath, String itemId) async {
    final items = await loadScratchpad(vaultPath);
    items.removeWhere((i) => i.id == itemId);
    await _saveScratchpad(vaultPath, items);
  }

  Future<void> _saveScratchpad(
    String vaultPath,
    List<ScratchpadItem> items,
  ) async {
    try {
      final dir = Directory(p.join(vaultPath, '.rf'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'scratchpad.json'));
      await file.writeAsString(
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );
    } catch (_) {
      debugPrint('Canvas: failed to save scratchpad');
    }
  }

  CanvasCard createCardFromScratchpad(ScratchpadItem item, Offset pos) {
    return CanvasCard(
      id: 'card_${const Uuid().v4()}',
      type: item.type,
      x: pos.dx,
      y: pos.dy,
      width: item.width,
      height: item.height,
      colorValue: item.colorValue,
      style: item.style,
      title: item.name,
    );
  }
}

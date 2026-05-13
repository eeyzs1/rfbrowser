part of '../canvas_service.dart';

mixin CanvasScratchpadMixin on _CanvasNotifierBase {
  @override
  Future<List<ScratchpadItem>> loadScratchpad() async {
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return [];
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

  @override
  Future<void> saveScratchpadItem(ScratchpadItem item) async {
    final items = await loadScratchpad();
    items.add(item);
    await _saveScratchpad(items);
  }

  @override
  Future<void> removeScratchpadItem(String itemId) async {
    final items = await loadScratchpad();
    items.removeWhere((i) => i.id == itemId);
    await _saveScratchpad(items);
  }

  @override
  Future<void> _saveScratchpad(List<ScratchpadItem> items) async {
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath == null) return;
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

  @override
  CanvasCard createCardFromScratchpad(ScratchpadItem item, Offset pos) {
    return CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
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

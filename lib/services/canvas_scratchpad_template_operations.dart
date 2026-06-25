part of 'canvas_service.dart';

/// Scratchpad and template delegation.
mixin CanvasScratchpadTemplateOperations on CanvasNotifierBase {
  // === Scratchpad delegation ===

  Future<List<ScratchpadItem>> loadScratchpad() async {
    final vaultPath = ref.read(vaultProvider).currentVault?.path;
    if (vaultPath == null) return [];
    return _scratchpadService.loadScratchpad(vaultPath);
  }

  Future<void> saveScratchpadItem(ScratchpadItem item) async {
    final vaultPath = ref.read(vaultProvider).currentVault?.path;
    if (vaultPath == null) return;
    await _scratchpadService.saveScratchpadItem(vaultPath, item);
  }

  Future<void> removeScratchpadItem(String itemId) async {
    final vaultPath = ref.read(vaultProvider).currentVault?.path;
    if (vaultPath == null) return;
    await _scratchpadService.removeScratchpadItem(vaultPath, itemId);
  }

  CanvasCard createCardFromScratchpad(ScratchpadItem item, Offset pos) {
    return _scratchpadService.createCardFromScratchpad(item, pos);
  }

  // === Templates delegation ===

  void loadTemplate(String templateName) {
    final template = CanvasTemplatesService.builtInTemplates[templateName];
    if (template == null) return;
    _mutateAndDebounce(() => template);
  }

  void loadFromData(CanvasData data) {
    _mutateAndDebounce(() => data);
  }
}

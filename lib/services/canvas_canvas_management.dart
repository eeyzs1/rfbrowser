part of 'canvas_service.dart';

/// Multi-canvas management (create/switch/delete/rename) and clearCanvas.
mixin CanvasCanvasManagement on CanvasNotifierBase {
  Future<bool> createCanvas(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _canvasNames.contains(trimmed)) return false;
    _canvasNames.add(trimmed);
    await _saveCanvasList();
    return true;
  }

  Future<void> switchCanvas(String name) async {
    if (!_canvasNames.contains(name) || name == _activeCanvasName) return;
    await _save();
    _activeCanvasName = name;
    await _saveCanvasList();
    await _loadFromFile();
  }

  Future<bool> deleteCanvas(String name) async {
    if (_canvasNames.length <= 1) return false;
    if (!_canvasNames.contains(name)) return false;
    _canvasNames.remove(name);
    if (_activeCanvasName == name) {
      _activeCanvasName = _canvasNames.first;
      await _loadFromFile();
    }
    await _saveCanvasList();
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath != null) {
        final file = File(
          p.join(vaultPath, '.rf', 'canvases', '$name.canvas.json'),
        );
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      appLog.error('Canvas: failed to delete canvas file for "$name"');
    }
    return true;
  }

  Future<bool> renameCanvas(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || _canvasNames.contains(trimmed)) return false;
    if (!_canvasNames.contains(oldName)) return false;
    final index = _canvasNames.indexOf(oldName);
    _canvasNames[index] = trimmed;
    if (_activeCanvasName == oldName) {
      _activeCanvasName = trimmed;
    }
    await _saveCanvasList();
    try {
      final vaultPath = ref.read(vaultProvider).currentVault?.path;
      if (vaultPath != null) {
        final oldFile = File(
          p.join(vaultPath, '.rf', 'canvases', '$oldName.canvas.json'),
        );
        final newFile = File(
          p.join(vaultPath, '.rf', 'canvases', '$trimmed.canvas.json'),
        );
        if (await oldFile.exists()) await oldFile.rename(newFile.path);
      }
    } catch (_) {
      appLog.error(
        'Canvas: failed to rename canvas file from "$oldName" to "$newName"',
      );
    }
    return true;
  }

  Future<void> clearCanvas() async {
    await _mutateAndPersist(() => CanvasData());
  }
}

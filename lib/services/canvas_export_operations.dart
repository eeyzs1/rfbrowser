part of 'canvas_service.dart';

/// Export delegation (non-static methods). Static import methods remain in
/// [CanvasNotifier] because Dart mixins cannot declare static members.
mixin CanvasExportOperations on CanvasNotifierBase {
  String exportToSvg() => _exportService.exportToSvg(state, _activeCanvasName);

  String exportToPdf() => _exportService.exportToPdf(state, _activeCanvasName);

  String exportToMarkdown() =>
      _exportService.exportToMarkdown(state, _activeCanvasName);

  String exportToHtml() => _exportService.exportToHtml(state);

  String exportToJpeg() =>
      _exportService.exportToJpeg(state, _activeCanvasName);

  String exportToWebp() =>
      _exportService.exportToWebp(state, _activeCanvasName);

  String encodeToUrl() => _exportService.encodeToUrl(state);

  (String, String) exportWithEmbeddedData() =>
      _exportService.exportWithEmbeddedData(state, _activeCanvasName);
}

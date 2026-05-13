part of '../canvas_service.dart';

mixin CanvasExportMixin on _CanvasNotifierBase {
    @override
    String exportToPdf() {
      final svg = exportToSvg();
      return svg;
    }

    @override
    String encodeToUrl() {
      final json = state.toJsonString();
      final encoded = base64Encode(utf8.encode(json));
      return 'rfbrowser://canvas?data=$encoded';
    }





}

part of 'canvas_service.dart';

/// Default card/connection style and background color operations.
mixin CanvasStyleOperations on CanvasNotifierBase {
  void setDefaultCardStyle(CanvasCardStyle? style) {
    state = _styleService.withDefaultCardStyle(state, style);
    _debouncedSave();
  }

  void setDefaultConnectionStyle(CanvasConnectionStyle? style) {
    state = _styleService.withDefaultConnectionStyle(state, style);
    _debouncedSave();
  }

  void setBackgroundColor(int? colorValue) {
    state = _styleService.withBackgroundColor(state, colorValue);
    _debouncedSave();
  }
}

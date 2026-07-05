part of '../canvas_page.dart';

/// Mixin containing the canvas keyboard shortcut bindings setup.
mixin _CanvasViewBuildMixin on _CanvasViewStateBase {
  // Issue 18: Cache the bindings map keyed by the shortcuts config snapshot.
  // The bindings reference stable methods on `this`, so they remain valid
  // across rebuilds as long as the shortcut config hasn't changed.
  Map<ShortcutActivator, VoidCallback>? _canvasBindingsCache;
  String? _canvasBindingsCacheKey;

  /// Builds the map of keyboard shortcut bindings for the canvas.
  Map<ShortcutActivator, VoidCallback> _buildCanvasBindings() {
    final shortcutSvc = ref.read(shortcutServiceProvider);
    final undoStr = shortcutSvc.getShortcut('canvas_undo') ?? 'Ctrl+Z';
    final redoStr = shortcutSvc.getShortcut('canvas_redo') ?? 'Ctrl+Y';
    final deleteStr = shortcutSvc.getShortcut('canvas_delete') ?? 'Delete';
    final selectAllStr =
        shortcutSvc.getShortcut('canvas_select_all') ?? 'Ctrl+A';
    final groupStr = shortcutSvc.getShortcut('canvas_group') ?? 'Ctrl+G';
    final ungroupStr =
        shortcutSvc.getShortcut('canvas_ungroup') ?? 'Ctrl+Shift+U';

    // Issue 18: Reuse cached bindings when the shortcut config is unchanged.
    final cacheKey = [
      undoStr,
      redoStr,
      deleteStr,
      selectAllStr,
      groupStr,
      ungroupStr,
    ].join('|');
    if (_canvasBindingsCache != null && _canvasBindingsCacheKey == cacheKey) {
      return _canvasBindingsCache!;
    }

    final undoActivator = parseShortcut(undoStr);
    final redoActivator = parseShortcut(redoStr);
    final deleteActivator = parseShortcut(deleteStr);
    final selectAllActivator = parseShortcut(selectAllStr);
    final groupActivator = parseShortcut(groupStr);
    final ungroupActivator = parseShortcut(ungroupStr);

    final Map<ShortcutActivator, VoidCallback> canvasBindings = {};
    canvasBindings[const SingleActivator(LogicalKeyboardKey.f3)] = _searchNext;
    canvasBindings[const SingleActivator(LogicalKeyboardKey.f3, shift: true)] =
        _searchPrev;
    if (undoActivator != null) canvasBindings[undoActivator] = _undo;
    if (redoActivator != null) canvasBindings[redoActivator] = _redo;
    canvasBindings[const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        )] =
        _redo;
    canvasBindings[const SingleActivator(LogicalKeyboardKey.escape)] = () {
      if (_styleBrushMode) {
        setState(() {
          _styleBrushMode = false;
          _copiedStyle = null;
        });
        return;
      }
      if (_connectingFromCardId != null) {
        setState(() {
          _connectingFromCardId = null;
          _connectingFromSide = null;
          _isDraggingFromPort = false;
          _connectingPreviewEnd = null;
          _hoveredConnectionSide = null;
        });
        return;
      }
      if (ref.read(canvasProvider).selectedConnectionId != null) {
        ref.read(canvasProvider.notifier).selectConnection(null);
        return;
      }
      _finishInlineEditing();
    };
    if (deleteActivator != null) {
      canvasBindings[deleteActivator] = _deleteSelectedCards;
    }
    if (selectAllActivator != null) {
      canvasBindings[selectAllActivator] = _selectAll;
    }
    if (groupActivator != null) {
      canvasBindings[groupActivator] = _groupSelected;
    }
    if (ungroupActivator != null) {
      canvasBindings[ungroupActivator] = _ungroupSelected;
    }
    _canvasBindingsCache = canvasBindings;
    _canvasBindingsCacheKey = cacheKey;
    return canvasBindings;
  }
}

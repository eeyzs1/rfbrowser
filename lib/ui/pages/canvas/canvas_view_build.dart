part of '../canvas_page.dart';

/// Mixin containing the canvas keyboard shortcut bindings setup.
mixin _CanvasViewBuildMixin on _CanvasViewStateBase {
  /// Builds the map of keyboard shortcut bindings for the canvas.
  Map<ShortcutActivator, VoidCallback> _buildCanvasBindings() {
    final shortcutSvc = ref.read(shortcutServiceProvider);
    final undoActivator = parseShortcut(
      shortcutSvc.getShortcut('canvas_undo') ?? 'Ctrl+Z',
    );
    final redoActivator = parseShortcut(
      shortcutSvc.getShortcut('canvas_redo') ?? 'Ctrl+Y',
    );
    final deleteActivator = parseShortcut(
      shortcutSvc.getShortcut('canvas_delete') ?? 'Delete',
    );
    final selectAllActivator = parseShortcut(
      shortcutSvc.getShortcut('canvas_select_all') ?? 'Ctrl+A',
    );
    final groupActivator = parseShortcut(
      shortcutSvc.getShortcut('canvas_group') ?? 'Ctrl+G',
    );
    final ungroupActivator = parseShortcut(
      shortcutSvc.getShortcut('canvas_ungroup') ?? 'Ctrl+Shift+U',
    );

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
    return canvasBindings;
  }
}

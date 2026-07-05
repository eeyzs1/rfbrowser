part of 'canvas_service.dart';

/// Auto-layout delegation and canvas display settings toggles.
mixin CanvasLayoutSettingsOperations on CanvasNotifierBase {
  Future<void> autoLayout(AutoLayoutType type) async {
    if (state.cards.isEmpty) return;
    // Issue 11: Run force-directed layout (O(50×n²)) in a worker isolate
    // when there are more than 50 cards. Lighter algorithms stay sync.
    final heavy =
        type == AutoLayoutType.forceDirected && state.cards.length > 50;
    Map<String, Offset> positions;
    if (heavy) {
      _isAutoLayouting = true;
      state = state.copyWith(); // notify listeners to show progress overlay
      try {
        positions = await _layoutService.computeLayoutAsync(
          state.cards,
          state.connections,
          type,
          snapToGrid: state.settings.snapToGrid,
        );
      } finally {
        _isAutoLayouting = false;
      }
    } else {
      positions = _layoutService.computeLayout(
        state.cards,
        state.connections,
        type,
        snapToGrid: state.settings.snapToGrid,
      );
    }
    _mutateAndDebounce(() {
      final newCards = state.cards.map((card) {
        final pos = positions[card.id];
        if (pos != null) {
          return card.copyWith(x: pos.dx, y: pos.dy);
        }
        return card;
      }).toList();
      return state.copyWith(cards: newCards);
    });
  }

  void toggleAutoConnections() {
    final newSettings = state.settings.copyWith(
      autoConnectionsEnabled: !state.settings.autoConnectionsEnabled,
    );
    state = state.copyWith(settings: newSettings);
    _debouncedSave();
  }

  void toggleSnapToGrid() {
    final newSettings = state.settings.copyWith(
      snapToGrid: !state.settings.snapToGrid,
    );
    state = state.copyWith(settings: newSettings);
    _debouncedSave();
  }

  void toggleGridVisible() {
    final newSettings = state.settings.copyWith(
      gridVisible: !state.settings.gridVisible,
    );
    state = state.copyWith(settings: newSettings);
    _debouncedSave();
  }

  void toggleRulers() {
    state = state.copyWith(
      settings: state.settings.copyWith(
        rulersVisible: !state.settings.rulersVisible,
      ),
    );
    _debouncedSave();
  }
}

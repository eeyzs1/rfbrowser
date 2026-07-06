import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../scenes/connect/connect_scene.dart';

/// UI layout state that is shared across multiple scenes (panel expansion,
/// connect view mode). Extracted from `MainLayout` so child widgets can
/// read it directly via Riverpod instead of receiving it through
/// constructor prop-drilling.
///
/// Note: per-tree visibility flags (`showCommandBar`, `showSettings`) stay
/// in `MainLayout`'s `State` because they gate widget-tree composition
/// (Offstage / conditional children) and must trigger `setState` there.
class LayoutState {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final ConnectViewMode connectViewMode;

  const LayoutState({
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.connectViewMode = ConnectViewMode.canvas,
  });

  LayoutState copyWith({
    bool? leftPanelExpanded,
    bool? rightPanelExpanded,
    ConnectViewMode? connectViewMode,
  }) {
    return LayoutState(
      leftPanelExpanded: leftPanelExpanded ?? this.leftPanelExpanded,
      rightPanelExpanded: rightPanelExpanded ?? this.rightPanelExpanded,
      connectViewMode: connectViewMode ?? this.connectViewMode,
    );
  }
}

class LayoutStateManager extends Notifier<LayoutState> {
  @override
  LayoutState build() => const LayoutState();

  void toggleLeftPanel() {
    state = state.copyWith(leftPanelExpanded: !state.leftPanelExpanded);
  }

  void toggleRightPanel() {
    state = state.copyWith(rightPanelExpanded: !state.rightPanelExpanded);
  }

  void setConnectViewMode(ConnectViewMode mode) {
    if (state.connectViewMode == mode) return;
    state = state.copyWith(connectViewMode: mode);
  }
}

final layoutStateManagerProvider =
    NotifierProvider<LayoutStateManager, LayoutState>(LayoutStateManager.new);

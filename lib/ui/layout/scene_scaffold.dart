import 'package:flutter/material.dart';
import 'scene_switcher.dart';

enum SceneType { capture, think, connect }

class SceneScaffold extends StatefulWidget {
  final SceneType initialScene;
  final WidgetBuilder captureView;
  final WidgetBuilder thinkView;
  final WidgetBuilder connectView;
  final Widget? statusBar;
  final ValueChanged<SceneType>? onSceneChanged;

  const SceneScaffold({
    super.key,
    required this.initialScene,
    required this.captureView,
    required this.thinkView,
    required this.connectView,
    this.statusBar,
    this.onSceneChanged,
  });

  @override
  State<SceneScaffold> createState() => _SceneScaffoldState();
}

class _SceneScaffoldState extends State<SceneScaffold> {
  late SceneType _currentScene;

  @override
  void initState() {
    super.initState();
    _currentScene = widget.initialScene;
  }

  void _switchScene(SceneType scene) {
    if (scene == _currentScene) return;
    setState(() => _currentScene = scene);
    widget.onSceneChanged?.call(scene);
  }

  Widget _buildSceneContent() {
    final child = switch (_currentScene) {
      SceneType.capture => widget.captureView(context),
      SceneType.think => widget.thinkView(context),
      SceneType.connect => widget.connectView(context),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_currentScene),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SceneSwitcher(
          currentScene: _currentScene,
          onSceneChanged: _switchScene,
        ),
        Expanded(
          child: _buildSceneContent(),
        ),
        if (widget.statusBar != null) widget.statusBar!,
      ],
    );
  }
}

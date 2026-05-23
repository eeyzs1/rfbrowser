import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
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
      duration: DesignDuration.sceneTransition,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final isNew =
            child.key is ValueKey<SceneType> &&
            (child.key as ValueKey<SceneType>).value == _currentScene;

        if (isNew) {
          final slideOffset = _currentScene == SceneType.connect
              ? const Offset(0, 0.15)
              : const Offset(0.15, 0);
          return SlideTransition(
            position: Tween<Offset>(begin: slideOffset, end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        } else {
          final slideOffset = _currentScene == SceneType.connect
              ? const Offset(0, -0.1)
              : const Offset(-0.1, 0);
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: slideOffset,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeIn)),
            child: FadeTransition(opacity: animation, child: child),
          );
        }
      },
      child: KeyedSubtree(key: ValueKey(_currentScene), child: child),
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
        Expanded(child: _buildSceneContent()),
        if (widget.statusBar != null) widget.statusBar!,
      ],
    );
  }
}

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
  final VoidCallback? onSettings;

  const SceneScaffold({
    super.key,
    required this.initialScene,
    required this.captureView,
    required this.thinkView,
    required this.connectView,
    this.statusBar,
    this.onSceneChanged,
    this.onSettings,
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
    // 移除 AnimatedSwitcher + KeyedSubtree(ValueKey) 反模式。
    //
    // 根因（2026-07-03 诊断）：AnimatedSwitcher + KeyedSubtree(ValueKey)
    // 会导致子节点 unmount+remount，触发 SemanticsNode 重新创建/销毁。
    // 这些瞬态节点在 native accessibility_bridge 的 AXTree Unserialize
    // 过程中成为 orphan（"NNN will not be in the tree"）。
    //
    // 用条件渲染（switch）替代：只挂载当前场景，切换场景时旧场景 dispose、
    // 新场景 build。无过渡动画，但消除 unmount+remount 反模式。
    return switch (_currentScene) {
      SceneType.capture => widget.captureView(context),
      SceneType.think => widget.thinkView(context),
      SceneType.connect => widget.connectView(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    // 移除 _contentReady 分阶段渲染。
    //
    // 根因（2026-07-03 诊断）：_contentReady 切换触发 rebuild，rebuild 过程中
    // ExcludeSemantics 占位符被 dispose、_buildSceneContent() 被创建。这个
    // diff 过程产生瞬态 SemanticsNode（在 Flutter 层最终状态不存在，但被
    // native AXTree 引用）→ orphan → "error: 64 will not be in the tree"。
    //
    // 诊断证据：节点 64 在所有时序点（MainLayout#1/#2/SceneContent）都 NOT
    // in tree（Flutter 层从未存在过），但 native 报 error 64。说明节点 64
    // 是 rebuild 过程的瞬态节点，最终被销毁，但 native AXTree 仍引用它。
    //
    // 移除 _contentReady 后，场景内容在首帧直接渲染，不会有 rebuild，不会
    // 产生瞬态节点。之前 _contentReady 是为了解决启动崩溃（LoadingScreen →
    // MainLayout 的大 diff），但启动崩溃已用 await loadAllNotes/loadBookmarks
    // 缓解（app.dart），现在移除应该安全。
    return Column(
      children: [
        SceneSwitcher(
          currentScene: _currentScene,
          onSceneChanged: _switchScene,
          onSettings: widget.onSettings,
        ),
        Expanded(child: _buildSceneContent()),
        if (widget.statusBar != null) widget.statusBar!,
      ],
    );
  }
}

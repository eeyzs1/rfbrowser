import 'package:flutter/material.dart';
import '../pages/ai_chat_panel.dart';
import '../theme/design_tokens.dart';
import '../layout/scene_scaffold.dart';

class AIFloat extends StatefulWidget {
  final SceneType? currentScene;

  const AIFloat({super.key, this.currentScene});

  @override
  State<AIFloat> createState() => _AIFloatState();
}

class _AIFloatState extends State<AIFloat> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: DesignDuration.aiFloatExpand,
    )..value = _isExpanded ? 1.0 : 0.0;
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.duration = DesignDuration.aiFloatExpand;
        _animationController.forward();
      } else {
        _animationController.duration = DesignDuration.aiFloatCollapse;
        _animationController.reverse();
      }
    });
  }

  void _collapse() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _animationController.duration = DesignDuration.aiFloatCollapse;
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _collapse,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.black38),
            ),
          ),
        if (_isExpanded)
          Positioned(
            right: DesignSpacing.lg,
            bottom: 72,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                  shadowColor: DesignShadow.lg.color,
                  child: Container(
                    width: 360,
                    height: 480,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      child: Stack(
                        children: [
                          const AIChatPanel(),
                          Positioned(
                            top: DesignSpacing.xs,
                            right: DesignSpacing.xs,
                            // 直接 IconButton（不用 Semantics 包裹）：
                            // 之前 Semantics(button: true) + IconButton 创造两个 button
                            // 节点（外层显式 + 内层 InkWell 自动），且动态 label
                            // ('Open AI Chat'/'Close AI Chat') 翻转时结构不一致
                            // → AXTree diff 失败。直接 IconButton 自带 button 语义且稳定。
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _collapse,
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonLabel,
                              constraints: const BoxConstraints(
                                minWidth: DesignTouchTarget.iconButtonSize,
                                minHeight: DesignTouchTarget.iconButtonSize,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black26,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: DesignSpacing.lg,
          bottom: DesignSpacing.lg,
          // 关键修复：FAB 直接用 onPressed 回调，去掉 GestureDetector/AnimatedScale/Semantics 三层包裹。
          // 之前 FloatingActionButton(onPressed: null) + GestureDetector + AnimatedScale + 动态 label
          // → 每按一次 6 帧 AnimatedScale + 切换 _isExpanded 时 label 从 'Open' 变 'Close'
          //   → SemanticsNode 结构翻转 → AXTree diff 失败。
          // 改用 onPressed: _toggle 让 FAB 自己处理 tap，去掉所有包裹层。
          child: FloatingActionButton(
            heroTag: 'ai_float',
            onPressed: _toggle,
            mini: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            // 静态 Icon，无 AnimatedSwitcher。
            // 之前 AnimatedSwitcher + ValueKey(_isExpanded) 每次切换会 unmount + remount Icon
            // → SemanticsNode 节点重新创建/销毁 → AXTree diff 失败。
            // 改用条件渲染 + 简单 Icon，不产生节点替换。
            child: Icon(
              _isExpanded ? Icons.close : Icons.psychology,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

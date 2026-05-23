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
  bool _isPressed = false;
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
  void didUpdateWidget(covariant AIFloat oldWidget) {
    super.didUpdateWidget(oldWidget);
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
                            child: Semantics(
                              button: true,
                              label: MaterialLocalizations.of(
                                context,
                              ).closeButtonLabel,
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
          child: Semantics(
            button: true,
            label: _isExpanded ? 'Close AI Chat' : 'Open AI Chat',
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _toggle();
              },
              onTapCancel: () => setState(() => _isPressed = false),
              child: AnimatedScale(
                scale: _isPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeInOut,
                child: FloatingActionButton(
                  heroTag: 'ai_float',
                  onPressed: null,
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.psychology,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

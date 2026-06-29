import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/agent_service.dart';
import '../../data/models/agent_task.dart';
import '../pages/ai_chat_panel.dart';
import '../theme/design_tokens.dart';

part 'speed_dial_agent.dart';
part 'speed_dial_task_card.dart';

enum _PanelType { none, ai, agent }

class SpeedDialFAB extends ConsumerStatefulWidget {
  const SpeedDialFAB({super.key});

  @override
  ConsumerState<SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends ConsumerState<SpeedDialFAB>
    with SingleTickerProviderStateMixin {
  bool _speedDialOpen = false;
  _PanelType _activePanel = _PanelType.none;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: DesignDuration.aiFloatExpand,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isAnythingOpen => _speedDialOpen || _activePanel != _PanelType.none;

  void _toggleSpeedDial() {
    setState(() {
      if (_speedDialOpen) {
        _speedDialOpen = false;
        _animController.reverse();
      } else {
        _speedDialOpen = true;
        _activePanel = _PanelType.none;
        _animController.forward();
      }
    });
  }

  void _openPanel(_PanelType type) {
    setState(() {
      _speedDialOpen = false;
      _activePanel = type;
      _animController.reset();
      _animController.forward();
    });
  }

  void _closeAll() {
    setState(() {
      _speedDialOpen = false;
      _activePanel = _PanelType.none;
    });
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        if (_isAnythingOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeAll,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.black38),
            ),
          ),

        if (_activePanel == _PanelType.ai)
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
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      border: Border.all(color: theme.dividerColor),
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
                            // 之前 Semantics(button: true) + IconButton 创造两个 button 节点
                            // （外层显式 + 内层 InkWell 自动），切换 _activePanel
                            // 时结构翻转 → AXTree diff 失败。
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _closeAll,
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

        if (_activePanel == _PanelType.agent)
          Positioned(
            right: DesignSpacing.lg + 56,
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
                    width: 400,
                    height: 520,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DesignRadius.lg),
                      child: Stack(
                        children: [
                          const _AgentPanelContent(),
                          Positioned(
                            top: DesignSpacing.xs,
                            right: DesignSpacing.xs,
                            // 直接 IconButton（不用 Semantics 包裹）：同上一个 panel。
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _closeAll,
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

        if (_speedDialOpen) ...[
          _buildSpeedDialItem(
            theme,
            label: l10n.aiAssistant,
            icon: Icons.psychology,
            color: theme.colorScheme.secondary,
            onColor: theme.colorScheme.onSecondary,
            bottomOffset: DesignSpacing.lg + 72,
            onTap: () => _openPanel(_PanelType.ai),
          ),
          _buildSpeedDialItem(
            theme,
            label: l10n.agent,
            icon: Icons.smart_toy,
            color: theme.colorScheme.tertiary,
            onColor: theme.colorScheme.onTertiary,
            bottomOffset: DesignSpacing.lg + 128,
            onTap: () => _openPanel(_PanelType.agent),
          ),
        ],

        Positioned(
          right: 20,
          bottom: 20,
          child: SizedBox(
            width: 60,
            height: 60,
            // 关键修复：FAB 静态 Icon，无 AnimatedSwitcher。
            // 之前 AnimatedSwitcher + ValueKey(_isAnythingOpen) 每次切换会 unmount + remount
            // Icon → SemanticsNode 节点重新创建/销毁 → AXTree diff 失败。
            // 改用条件渲染 + 简单 Icon，不产生节点替换。
            child: FloatingActionButton(
              heroTag: 'speed_dial_fab',
              onPressed: _toggleSpeedDial,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                _isAnythingOpen ? Icons.close : Icons.auto_awesome,
                size: 28,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialItem(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required Color color,
    required Color onColor,
    required double bottomOffset,
    required VoidCallback onTap,
  }) {
    return Positioned(
      right: DesignSpacing.lg + 4,
      bottom: bottomOffset,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                  boxShadow: const [DesignShadow.sm],
                ),
                child: Text(label, style: theme.textTheme.labelMedium),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: onTap,
                backgroundColor: color,
                child: Icon(icon, color: onColor, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

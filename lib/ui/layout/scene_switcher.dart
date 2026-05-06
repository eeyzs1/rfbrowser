import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'scene_scaffold.dart';

class SceneSwitcher extends StatelessWidget {
  final SceneType currentScene;
  final ValueChanged<SceneType> onSceneChanged;

  const SceneSwitcher({
    super.key,
    required this.currentScene,
    required this.onSceneChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.lg),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.explore,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'RFBrowser',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          _SceneButton(
            scene: SceneType.capture,
            icon: Icons.explore,
            label: '捕捉',
            shortcut: 'Ctrl+1',
            isActive: currentScene == SceneType.capture,
            onTap: () => onSceneChanged(SceneType.capture),
          ),
          const SizedBox(width: DesignSpacing.xs),
          _SceneButton(
            scene: SceneType.think,
            icon: Icons.edit_note,
            label: '思考',
            shortcut: 'Ctrl+2',
            isActive: currentScene == SceneType.think,
            onTap: () => onSceneChanged(SceneType.think),
          ),
          const SizedBox(width: DesignSpacing.xs),
          _SceneButton(
            scene: SceneType.connect,
            icon: Icons.hub,
            label: '连接',
            shortcut: 'Ctrl+3',
            isActive: currentScene == SceneType.connect,
            onTap: () => onSceneChanged(SceneType.connect),
          ),
        ],
      ),
    );
  }
}

class _SceneButton extends StatefulWidget {
  final SceneType scene;
  final IconData icon;
  final String label;
  final String shortcut;
  final bool isActive;
  final VoidCallback onTap;

  const _SceneButton({
    required this.scene,
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SceneButton> createState() => _SceneButtonState();
}

class _SceneButtonState extends State<_SceneButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.isActive;
    final primary = theme.colorScheme.primary;

    return Material(
      color: active
          ? primary.withValues(alpha: 0.15)
          : (_isHovered ? primary.withValues(alpha: 0.05) : Colors.transparent),
      borderRadius: BorderRadius.circular(DesignRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignRadius.sm),
        onTap: active ? null : widget.onTap,
        onHover: (hovered) => setState(() => _isHovered = hovered),
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.sm,
            vertical: 2,
          ),
          decoration: active
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: primary, width: 2),
                  ),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: active ? primary : DesignColors.textMuted,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? primary : DesignColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.shortcut,
                    style: TextStyle(
                      fontSize: 9,
                      color: active
                          ? primary.withValues(alpha: 0.6)
                          : DesignColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

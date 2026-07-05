import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/design_tokens.dart';
import '../../data/stores/vault_store.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/shortcut_service.dart';
import 'scene_scaffold.dart';
import '../../../l10n/app_localizations.dart';

part 'scene_switcher_vault.dart';

class SceneSwitcher extends ConsumerStatefulWidget {
  final SceneType currentScene;
  final ValueChanged<SceneType> onSceneChanged;
  final VoidCallback? onSettings;

  const SceneSwitcher({
    super.key,
    required this.currentScene,
    required this.onSceneChanged,
    this.onSettings,
  });

  @override
  ConsumerState<SceneSwitcher> createState() => _SceneSwitcherState();
}

class _SceneSwitcherState extends ConsumerState<SceneSwitcher> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final vaultState = ref.watch(vaultProvider);
    final vaultName = vaultState.currentVault?.name ?? 'No Vault';
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.lg),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.explore, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: DesignSpacing.sm),
          Text(
            'RFBrowser',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: DesignSpacing.sm),
          Flexible(child: _VaultSwitcher(vaultName: vaultName)),
          const Spacer(),
          Flexible(
            child: _SceneButton(
              scene: SceneType.capture,
              icon: Icons.explore,
              label: l.capture,
              shortcut:
                  ref
                      .read(shortcutServiceProvider)
                      .getShortcut('switch_capture') ??
                  'Ctrl+1',
              tooltip: l.captureTooltip,
              isActive: widget.currentScene == SceneType.capture,
              onTap: () => widget.onSceneChanged(SceneType.capture),
            ),
          ),
          const SizedBox(width: DesignSpacing.xs),
          Flexible(
            child: _SceneButton(
              scene: SceneType.think,
              icon: Icons.edit_note,
              label: l.think,
              shortcut:
                  ref
                      .read(shortcutServiceProvider)
                      .getShortcut('switch_think') ??
                  'Ctrl+2',
              tooltip: l.thinkTooltip,
              isActive: widget.currentScene == SceneType.think,
              onTap: () => widget.onSceneChanged(SceneType.think),
            ),
          ),
          const SizedBox(width: DesignSpacing.xs),
          Flexible(
            child: _SceneButton(
              scene: SceneType.connect,
              icon: Icons.hub,
              label: l.connect,
              shortcut:
                  ref
                      .read(shortcutServiceProvider)
                      .getShortcut('switch_connect') ??
                  'Ctrl+3',
              tooltip: l.connectTooltip,
              isActive: widget.currentScene == SceneType.connect,
              onTap: () => widget.onSceneChanged(SceneType.connect),
            ),
          ),
          const SizedBox(width: DesignSpacing.xs),
          _SettingsButton(onSettings: widget.onSettings),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatefulWidget {
  final VoidCallback? onSettings;
  const _SettingsButton({this.onSettings});

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 不声明 button: true —— InkWell 自身通过 Material 隐式提供 button
    // semantics（onTap != null 时）。外层 Semantics 只补充 label，与 InkWell
    // 的 button semantics 合并形成单个语义节点（button=true + label='Settings'）。
    return Semantics(
      label: 'Settings',
      child: Material(
        color: _isHovered ? DesignColors.primaryHover : Colors.transparent,
        borderRadius: BorderRadius.circular(DesignRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignRadius.sm),
          onTap: widget.onSettings,
          onHover: (hovered) => setState(() => _isHovered = hovered),
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: Container(
            padding: const EdgeInsets.all(DesignSpacing.sm),
            constraints: const BoxConstraints(
              minWidth: DesignTouchTarget.minSize,
              minHeight: DesignTouchTarget.minSize,
            ),
            decoration: _isFocused
                ? BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(DesignRadius.sm),
                  )
                : null,
            child: const Icon(Icons.settings, size: 18),
          ),
        ),
      ),
    );
  }
}

class _SceneButton extends StatefulWidget {
  final SceneType scene;
  final IconData icon;
  final String label;
  final String shortcut;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _SceneButton({
    required this.scene,
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SceneButton> createState() => _SceneButtonState();
}

class _SceneButtonState extends State<_SceneButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.isActive;
    final primary = theme.colorScheme.primary;

    // 关键修复：onTap 始终为 widget.onTap（不再用 active ? null : widget.onTap）。
    // 之前 active 时 InkWell.onTap=null → InkWell 不贡献 button semantics；
    // 非 active 时 InkWell.onTap=callback → InkWell 贡献 button semantics。
    // 这导致 3 个兄弟 _SceneButton 的语义节点结构不一致（一个无 button 角色，
    // 两个有 button 角色），切换场景时结构翻转，触发 Windows accessibility_bridge
    // AXTree diff 失败（"Failed to update ui::AXTree, error: NNN"）。
    // 统一为始终提供 onTap（widget.onSceneChanged 对相同 scene 是幂等的），
    // 让所有 _SceneButton 的 InkWell 都贡献 button semantics，结构一致。
    // 不声明外层 button: true —— 让 InkWell 通过合并提供 button 角色，
    // 外层 Semantics 只补充 selected/label。
    return Semantics(
      selected: active,
      label: widget.label,
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: active
              ? DesignColors.primaryMuted
              : (_isHovered ? DesignColors.primaryHover : Colors.transparent),
          borderRadius: BorderRadius.circular(DesignRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(DesignRadius.sm),
            onTap: widget.onTap,
            onHover: (hovered) => setState(() => _isHovered = hovered),
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignSpacing.md,
                vertical: DesignSpacing.sm,
              ),
              constraints: const BoxConstraints(
                minHeight: DesignTouchTarget.minSize,
              ),
              decoration: BoxDecoration(
                border: _isFocused && !active
                    ? Border.all(color: primary, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(DesignRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: active
                        ? primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: DesignSpacing.xs),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active
                            ? primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: DesignSpacing.xs),
                  Flexible(
                    child: Text(
                      widget.shortcut,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: active
                            ? primary.withValues(alpha: 0.6)
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

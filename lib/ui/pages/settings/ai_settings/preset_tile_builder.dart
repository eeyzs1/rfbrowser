// ignore_for_file: unused_element, unused_element_parameter

part of '../ai_settings_section.dart';

mixin _PresetTileBuilderMixin on _AISettingsSectionStateBase {
  Future<void> _onPresetTap(
    LocalServiceInfo preset,
    bool? isOnline, {
    BuildContext? sheetCtx,
  }) async {
    if (isOnline == false) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.serviceNotRunning),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await _addPresetProvider(preset);

    if (sheetCtx != null && sheetCtx.mounted && mounted) {
      Navigator.pop(sheetCtx);
    }
  }

  Widget _buildPresetTile(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l,
    LocalServiceInfo preset, {
    BuildContext? sheetCtx,
    bool compact = false,
  }) {
    final isOnline = _presetOnlineStatus[preset.name];
    final isAddingThis = _isAddingPreset;
    final iconSize = compact ? 22.0 : 18.0;
    final spacing = compact ? 12.0 : 10.0;
    final dotSize = compact ? 8.0 : 7.0;
    final trailingSize = compact ? 20.0 : 18.0;
    final spinnerSize = compact ? 18.0 : 16.0;
    final hPadding = compact ? 14.0 : 12.0;
    final vPadding = compact ? 12.0 : 10.0;
    final bottomPadding = compact ? 8.0 : 6.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: InkWell(
        // 始终非空 callback：消除 onTap null↔callback 的 button 角色翻转。
        // 之前 isAddingThis 期间 onTap=null（InkWell 丢失 button 角色），
        // 完成后恢复 callback（button 角色重现）→ AXTree diff 失败。
        // 与 scene_switcher.dart _SceneButton.onTap 统一模式。
        onTap: () async {
          if (isAddingThis) return;
          await _onPresetTap(preset, isOnline, sheetCtx: sheetCtx);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: hPadding,
            vertical: vPadding,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isOnline == true
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(10),
            color: isOnline == true
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                : null,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(
                    preset.icon,
                    size: iconSize,
                    color: isOnline == true
                        ? theme.colorScheme.primary
                        : theme.hintColor,
                  ),
                  if (isOnline != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.green
                              : theme.colorScheme.outlineVariant,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      isOnline == true
                          ? l.serviceRunning
                          : isOnline == false
                          ? l.serviceNotRunning
                          : preset.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOnline == true
                            ? Colors.green.shade700
                            : theme.hintColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isAddingPreset)
                SizedBox(
                  width: spinnerSize,
                  height: spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(
                  isOnline == true
                      ? Icons.add_circle
                      : isOnline == false
                      ? Icons.warning_amber_rounded
                      : Icons.add_circle_outline,
                  size: trailingSize,
                  color: isOnline == true
                      ? theme.colorScheme.primary
                      : isOnline == false
                      ? theme.colorScheme.error
                      : theme.hintColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

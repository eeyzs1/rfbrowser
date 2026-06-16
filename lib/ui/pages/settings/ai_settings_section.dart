import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../../services/ai_service.dart';
import '../../../services/local_service_scanner.dart';
import '../../../data/models/ai_provider.dart';
import '../../../core/domain/model_discovery.dart';
import '../../widgets/settings_section.dart';

class AISettingsSection extends ConsumerStatefulWidget {
  const AISettingsSection({super.key});

  @override
  ConsumerState<AISettingsSection> createState() => _AISettingsSectionState();
}

class _AISettingsSectionState extends ConsumerState<AISettingsSection> {
  bool _hasScanned = false;
  bool _isScanning = false;
  bool _isAddingPreset = false;
  Map<String, bool> _presetOnlineStatus = {};
  List<LocalServiceInfo> _detectedServices = [];
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasScanned) {
        _hasScanned = true;
        _checkPresetStatus();
        _autoScanAndPrompt();
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPresetStatus() async {
    final scanner = ref.read(localServiceScannerProvider);
    final results = <String, bool>{};
    for (final preset in LocalServiceScanner.presets) {
      results[preset.name] = await scanner.isServiceRunning(preset.baseUrl);
    }
    if (mounted) {
      setState(() => _presetOnlineStatus = results);
    }
  }

  Future<void> _autoScanAndPrompt() async {
    final aiConfig = ref.read(aiConfigProvider);
    if (aiConfig.providers.isNotEmpty) return;

    final scanner = ref.read(localServiceScannerProvider);
    final detected = await scanner.scan();
    if (detected.isEmpty || !mounted) return;

    setState(() => _detectedServices = detected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final aiConfig = ref.watch(aiConfigProvider);
    final providers = aiConfig.providers;
    final activeProvider = aiConfig.activeProvider;
    final activeModel = aiConfig.activeModel;

    final children = <Widget>[];

    children.add(
      ListTile(
        title: Text(l.activeModel),
        subtitle: Text(
          activeModel != null && activeProvider != null
              ? '${activeModel.displayName} via ${activeProvider.name}'
              : l.notSet,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showActiveModelDialog(context, l),
      ),
    );

    children.add(const Divider(height: 1));

    if (_detectedServices.isNotEmpty && providers.isEmpty) {
      children.add(_buildDetectedBanner(theme, l));
    }

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Text(
              l.providers,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  _showProviderFormDialog(context: context, ref: ref, l: l),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l.addProvider),
            ),
          ],
        ),
      ),
    );

    if (providers.isEmpty) {
      children.add(_buildQuickStartCard(context, theme, l));
    } else {
      for (final provider in providers) {
        children.add(
          _buildProviderTile(
            context,
            ref,
            theme,
            l,
            provider,
            activeProvider,
            activeModel,
          ),
        );
      }
      children.add(_buildAddLocalModelButton(theme, l));
    }

    return SettingsSection(title: l.aiModels, children: children);
  }

  Widget _buildDetectedBanner(ThemeData theme, AppLocalizations l) {
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () {
          _showDetectedServicesDialog(_detectedServices);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.sensors, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${l.localServiceDetected}: ${_detectedServices.map((s) => s.name).join(', ')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddLocalModelButton(ThemeData theme, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: OutlinedButton.icon(
        onPressed: () => _showLocalModelPresetsSheet(theme, l),
        icon: const Icon(Icons.computer, size: 16),
        label: Text(l.addLocalModel),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }

  void _showLocalModelPresetsSheet(ThemeData theme, AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.computer,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.localModelPresets,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.quickStartDesc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...LocalServiceScanner.presets.map(
                    (preset) => _buildPresetTile(
                      context,
                      theme,
                      l,
                      preset,
                      sheetCtx: ctx,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isScanning
                        ? null
                        : () async {
                            await _scanForLocalServices(
                              context,
                              l,
                              sheetCtx: ctx,
                            );
                          },
                    icon: _isScanning
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.search, size: 14),
                    label: Text(l.scanLocalServices),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.rocket_launch,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.quickStart,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l.quickStartDesc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 16),
                ...LocalServiceScanner.presets.map(
                  (preset) => _buildPresetTile(context, theme, l, preset),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isScanning
                        ? null
                        : () => _scanForLocalServices(context, l),
                    icon: _isScanning
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.search, size: 14),
                    label: Text(l.scanLocalServices),
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showProviderFormDialog(
                      context: context,
                      ref: ref,
                      l: l,
                    ),
                    icon: const Icon(Icons.cloud, size: 14),
                    label: Text(l.addCloudProvider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.localModelSetupGuide,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        onTap: isAddingThis
            ? null
            : () async {
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

  Future<void> _addPresetProvider(LocalServiceInfo preset) async {
    setState(() => _isAddingPreset = true);

    try {
      final provider = preset.toProvider();
      await ref.read(aiConfigProvider.notifier).addProvider(provider);

      final discovery = ref.read(modelDiscoveryProvider);
      final models = await discovery.fetchModels(provider);

      if (models.isNotEmpty) {
        await ref
            .read(aiConfigProvider.notifier)
            .setModelsForProvider(provider.id, models);
        ref.read(aiProvider.notifier).setActiveModel(provider, models.first);

        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l.providerAdded}: ${preset.name} (${models.length} ${l.modelsLabel})',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              content: Text(l.providerAddedNoModels(preset.name)),
              action: SnackBarAction(
                label: l.retry,
                onPressed: () => _refreshModelsAfterAdd(provider, l),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingPreset = false);
      }
    }
  }

  Future<void> _refreshModelsAfterAdd(
    AIProvider provider,
    AppLocalizations l,
  ) async {
    final discovery = ref.read(modelDiscoveryProvider);
    final models = await discovery.fetchModels(provider);
    if (models.isNotEmpty) {
      await ref
          .read(aiConfigProvider.notifier)
          .setModelsForProvider(provider.id, models);
      ref.read(aiProvider.notifier).setActiveModel(provider, models.first);
    }
  }

  Future<void> _scanForLocalServices(
    BuildContext context,
    AppLocalizations l, {
    BuildContext? sheetCtx,
  }) async {
    setState(() => _isScanning = true);
    final scanner = ref.read(localServiceScannerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final detected = await scanner.scan();

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _detectedServices = detected;
    });

    await _checkPresetStatus();

    if (detected.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.noLocalServiceFound),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (sheetCtx != null && sheetCtx.mounted) {
      Navigator.pop(sheetCtx);
    }
    _showDetectedServicesDialog(detected);
  }

  void _showDetectedServicesDialog(List<LocalServiceInfo> detected) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sensors, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l.detectedLocalServices),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.detectedLocalServicesDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 12),
              ...detected.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      _addPresetProvider(service);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Icon(
                                service.icon,
                                color: theme.colorScheme.primary,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  l.serviceRunning,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              _addPresetProvider(service);
                              Navigator.pop(ctx);
                            },
                            child: Text(l.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations l,
    AIProvider provider,
    AIProvider? activeProvider,
    AIModel? activeModel,
  ) {
    final isActive = activeProvider?.id == provider.id;
    final models = ref.watch(aiConfigProvider).modelsForProvider(provider.id);
    final enabled = provider.isEnabled;
    final dimColor = theme.disabledColor;
    final iconColor = !enabled
        ? dimColor
        : (isActive ? theme.colorScheme.primary : theme.hintColor);
    final nameColor = !enabled
        ? dimColor
        : (isActive ? theme.colorScheme.primary : null);
    final nameWeight = isActive ? FontWeight.w600 : FontWeight.w400;
    final disabledBg = theme.colorScheme.onSurface.withValues(alpha: 0.04);

    return ExpansionTile(
      initiallyExpanded: isActive,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      collapsedBackgroundColor: enabled ? null : disabledBg,
      backgroundColor: enabled ? null : disabledBg,
      title: Row(
        children: [
          Stack(
            children: [
              Icon(provider.displayIcon, size: 16, color: iconColor),
              if (provider.isLocal)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: enabled ? Colors.green : dimColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.name,
              style: TextStyle(
                fontWeight: nameWeight,
                color: nameColor,
                decoration: enabled ? null : TextDecoration.lineThrough,
                decorationColor: dimColor,
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (val) => ref
                .read(aiConfigProvider.notifier)
                .setProviderEnabled(provider.id, val),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            tooltip: l.refreshModels,
            onPressed: () => _refreshModels(context, ref, provider, l),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 16),
            onSelected: (action) =>
                _handleProviderAction(context, ref, action, provider, l),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'edit', child: Text(l.edit)),
              PopupMenuItem(
                value: 'toggle',
                child: Text(enabled ? l.disabled : l.enable),
              ),
              PopupMenuItem(value: 'addModel', child: Text(l.addCustomModel)),
              PopupMenuItem(value: 'delete', child: Text(l.delete)),
            ],
          ),
        ],
      ),
      children: [
        AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${provider.protocol.label} · ${provider.baseUrl}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (models.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildNoModelsHint(context, ref, theme, l, provider),
                )
              else
                ...models.map(
                  (model) => _buildModelTile(
                    context,
                    ref,
                    theme,
                    l,
                    model,
                    provider,
                    isActive && activeModel?.id == model.id,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoModelsHint(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations l,
    AIProvider provider,
  ) {
    final isLocal = provider.isLocal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                size: 14,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                l.noModelsFound,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isLocal ? l.noModelsLocalHint : l.noModelsCloudHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: () => _refreshModels(context, ref, provider, l),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: theme.textTheme.labelSmall,
                ),
                child: Text(l.retry),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations l,
    AIModel model,
    AIProvider provider,
    bool isActive,
  ) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 8),
      leading: Icon(
        isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 16,
        color: isActive ? theme.colorScheme.primary : theme.hintColor,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(model.displayName, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          ...model.capabilities.map(
            (cap) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Tooltip(
                message: cap.label,
                child: Icon(
                  cap == ModelCapability.vision
                      ? Icons.visibility
                      : Icons.text_fields,
                  size: 12,
                  color: theme.hintColor,
                ),
              ),
            ),
          ),
          if (model.isCustom)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  l.custom,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        model.id,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        ref.read(aiProvider.notifier).setActiveModel(provider, model);
      },
      trailing: model.isCustom
          ? IconButton(
              icon: const Icon(Icons.close, size: 14),
              onPressed: () => ref
                  .read(aiConfigProvider.notifier)
                  .removeModel(model.id, model.providerId),
            )
          : null,
    );
  }

  Future<void> _refreshModels(
    BuildContext context,
    WidgetRef ref,
    AIProvider provider,
    AppLocalizations l,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final discovery = ref.read(modelDiscoveryProvider);
    final apiKey = await ref
        .read(aiConfigProvider.notifier)
        .getApiKeyForProvider(provider.id);
    final models = await discovery.fetchModels(provider, apiKey: apiKey);
    if (models.isNotEmpty) {
      await ref
          .read(aiConfigProvider.notifier)
          .setModelsForProvider(provider.id, models);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${l.modelsRefreshed} ${models.length}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.isLocal ? l.noModelsLocalHint : l.noModelsCloudHint,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleProviderAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    AIProvider provider,
    AppLocalizations l,
  ) {
    switch (action) {
      case 'edit':
        _showProviderFormDialog(
          context: context,
          ref: ref,
          l: l,
          provider: provider,
        );
        break;
      case 'toggle':
        ref
            .read(aiConfigProvider.notifier)
            .setProviderEnabled(provider.id, !provider.isEnabled);
        break;
      case 'addModel':
        _showAddCustomModelDialog(context, ref, provider, l);
        break;
      case 'delete':
        _showDeleteProviderConfirmDialog(context, ref, provider, l);
        break;
    }
  }

  void _showProviderFormDialog({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l,
    AIProvider? provider,
  }) {
    final isEditing = provider != null;
    final nameController = TextEditingController(text: provider?.name ?? '');
    final baseUrlController = TextEditingController(
      text: provider?.baseUrl ?? ApiProtocol.openaiCompatible.defaultBaseUrl,
    );
    final apiKeyController = TextEditingController();
    ApiProtocol selectedProtocol =
        provider?.protocol ?? ApiProtocol.openaiCompatible;
    bool requiresApiKey = provider?.requiresApiKey ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void onProtocolChanged(ApiProtocol? p) {
            if (p != null) {
              setState(() {
                selectedProtocol = p;
                if (baseUrlController.text.isEmpty ||
                    ApiProtocol.values.any(
                      (proto) => baseUrlController.text == proto.defaultBaseUrl,
                    )) {
                  baseUrlController.text = p.defaultBaseUrl;
                }
                requiresApiKey = true;
              });
            }
          }

          return AlertDialog(
            title: Text(isEditing ? l.editProvider : l.addProvider),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l.providerName,
                        hintText: isEditing ? null : l.providerNameHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ApiProtocol>(
                      key: ValueKey(selectedProtocol),
                      initialValue: selectedProtocol,
                      decoration: InputDecoration(labelText: l.protocol),
                      items: ApiProtocol.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.label),
                            ),
                          )
                          .toList(),
                      onChanged: isEditing
                          ? (p) {
                              if (p != null) {
                                setState(() => selectedProtocol = p);
                              }
                            }
                          : onProtocolChanged,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlController,
                      decoration: InputDecoration(
                        labelText: l.baseUrl,
                        hintText: isEditing ? null : 'https://api.example.com',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.requireApiKey),
                      value: requiresApiKey,
                      onChanged: (val) {
                        setState(() => requiresApiKey = val);
                      },
                    ),
                    if (requiresApiKey) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: isEditing
                              ? '${l.apiKey} (${l.leaveEmptyToKeep})'
                              : l.apiKey,
                          hintText: isEditing
                              ? null
                              : selectedProtocol == ApiProtocol.openaiCompatible
                              ? 'sk-...'
                              : '',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final baseUrl = baseUrlController.text.trim().replaceAll(
                    RegExp(r'/$'),
                    '',
                  );
                  final apiKey =
                      requiresApiKey && apiKeyController.text.trim().isNotEmpty
                      ? apiKeyController.text.trim()
                      : null;

                  if (isEditing) {
                    final updated = provider.copyWith(
                      name: name,
                      protocol: selectedProtocol,
                      baseUrl: baseUrl,
                      apiKey: apiKey,
                      requiresApiKey: requiresApiKey,
                    );
                    await ref
                        .read(aiConfigProvider.notifier)
                        .updateProvider(updated);
                  } else {
                    final newProvider = AIProvider(
                      id: 'provider_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      protocol: selectedProtocol,
                      baseUrl: baseUrl,
                      apiKey: apiKey,
                      requiresApiKey: requiresApiKey,
                    );
                    ref
                        .read(aiConfigProvider.notifier)
                        .addProvider(newProvider);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l.save),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteProviderConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    AIProvider provider,
    AppLocalizations l,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteProvider),
        content: Text('${l.deleteProviderConfirm} ${provider.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              ref.read(aiConfigProvider.notifier).removeProvider(provider.id);
              Navigator.pop(ctx);
            },
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }

  void _showAddCustomModelDialog(
    BuildContext context,
    WidgetRef ref,
    AIProvider provider,
    AppLocalizations l,
  ) {
    final modelIdController = TextEditingController();
    final displayNameController = TextEditingController();
    final selectedCapabilities = <ModelCapability>{ModelCapability.text};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(l.addCustomModel),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: modelIdController,
                    decoration: InputDecoration(
                      labelText: l.modelId,
                      hintText: 'my-model-v1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: displayNameController,
                    decoration: InputDecoration(
                      labelText: l.displayName,
                      hintText: l.displayNameHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ModelCapability.values.map((cap) {
                      final isSelected = selectedCapabilities.contains(cap);
                      return FilterChip(
                        label: Text(cap.label),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedCapabilities.add(cap);
                            } else if (cap != ModelCapability.text) {
                              selectedCapabilities.remove(cap);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final modelId = modelIdController.text.trim();
                  if (modelId.isEmpty) return;
                  final model = AIModel(
                    id: modelId,
                    providerId: provider.id,
                    displayName: displayNameController.text.trim().isNotEmpty
                        ? displayNameController.text.trim()
                        : modelId,
                    capabilities: Set.from(selectedCapabilities),
                    isCustom: true,
                  );
                  ref.read(aiConfigProvider.notifier).addCustomModel(model);
                  Navigator.pop(ctx);
                },
                child: Text(l.save),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showActiveModelDialog(BuildContext context, AppLocalizations l) {
    final aiConfig = ref.read(aiConfigProvider);
    final providers = aiConfig.providers.where((p) => p.isEnabled).toList();
    final activeConfig = aiConfig.activeConfig;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.selectModel),
        content: SizedBox(
          width: 400,
          child: providers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.noProvidersHint),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: providers.length,
                  itemBuilder: (ctx, index) {
                    final provider = providers[index];
                    final models = aiConfig.modelsForProvider(provider.id);
                    return ExpansionTile(
                      initiallyExpanded:
                          activeConfig?.providerId == provider.id,
                      title: Row(
                        children: [
                          Icon(provider.displayIcon, size: 16),
                          const SizedBox(width: 8),
                          Text(provider.name),
                        ],
                      ),
                      children: models.map((model) {
                        final isActive =
                            activeConfig?.providerId == provider.id &&
                            activeConfig?.modelId == model.id;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isActive
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          title: Text(model.displayName),
                          subtitle: Text(
                            model.capabilityLabel,
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          onTap: () {
                            ref
                                .read(aiProvider.notifier)
                                .setActiveModel(provider, model);
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
  }
}

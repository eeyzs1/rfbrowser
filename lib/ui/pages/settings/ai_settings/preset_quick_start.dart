// ignore_for_file: unused_element, unused_element_parameter

part of '../ai_settings_section.dart';

mixin _PresetQuickStartMixin
    on _AISettingsSectionStateBase, _PresetTileBuilderMixin {
  @override
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

  @override
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

  @override
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
}

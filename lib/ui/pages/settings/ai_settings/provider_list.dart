// ignore_for_file: unused_element, unused_element_parameter

part of '../ai_settings_section.dart';

mixin _ProviderListMixin on _AISettingsSectionStateBase {
  @override
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
}

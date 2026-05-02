import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../../services/ai_service.dart';
import '../../../core/model/ai_provider.dart';
import '../../../core/model/model_discovery.dart';
import '../../widgets/settings_section.dart';

class AISettingsSection extends ConsumerWidget {
  const AISettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final providers = settingsNotifier.providers;
    final activeProvider = settingsNotifier.activeProvider;
    final activeModel = settingsNotifier.activeModel;

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
        onTap: () => _showActiveModelDialog(context, ref, l),
      ),
    );

    children.add(const Divider(height: 1));

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
              onPressed: () => _showAddProviderDialog(context, ref, l),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l.addProvider),
            ),
          ],
        ),
      ),
    );

    if (providers.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l.noProvidersHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      );
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
    }

    return SettingsSection(title: l.aiModels, children: children);
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
    final models = ref
        .read(settingsProvider.notifier)
        .modelsForProvider(provider.id);

    return ExpansionTile(
      initiallyExpanded: isActive,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      title: Row(
        children: [
          Icon(
            provider.protocol.icon,
            size: 16,
            color: isActive ? theme.colorScheme.primary : theme.hintColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.name,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? theme.colorScheme.primary : null,
              ),
            ),
          ),
          if (!provider.isEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l.disabled,
                style: TextStyle(fontSize: 10, color: theme.colorScheme.error),
              ),
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
                child: Text(provider.isEnabled ? l.disabled : l.enable),
              ),
              PopupMenuItem(value: 'addModel', child: Text(l.addCustomModel)),
              PopupMenuItem(value: 'delete', child: Text(l.delete)),
            ],
          ),
        ],
      ),
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
            child: Row(
              children: [
                Text(
                  l.noModelsFound,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _refreshModels(context, ref, provider, l),
                  child: Text(l.refresh),
                ),
              ],
            ),
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
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        model.id,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11,
          color: theme.hintColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        ref.read(aiProvider.notifier).setActiveModel(provider, model);
      },
      trailing: model.isCustom
          ? IconButton(
              icon: const Icon(Icons.close, size: 14),
              onPressed: () => ref
                  .read(settingsProvider.notifier)
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
        .read(settingsProvider.notifier)
        .getApiKeyForProvider(provider.id);
    final models = await discovery.fetchModels(provider, apiKey: apiKey);
    if (models.isNotEmpty) {
      await ref
          .read(settingsProvider.notifier)
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
          content: Text(l.noModelsFound),
          duration: const Duration(seconds: 2),
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
        _showEditProviderDialog(context, ref, provider, l);
        break;
      case 'toggle':
        ref
            .read(settingsProvider.notifier)
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

  void _showAddProviderDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) {
    final nameController = TextEditingController();
    final baseUrlController = TextEditingController(
      text: ApiProtocol.openaiCompatible.defaultBaseUrl,
    );
    final apiKeyController = TextEditingController();
    ApiProtocol selectedProtocol = ApiProtocol.openaiCompatible;

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
              });
            }
          }

          return AlertDialog(
            title: Text(l.addProvider),
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
                        hintText: l.providerNameHint,
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
                      onChanged: onProtocolChanged,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlController,
                      decoration: InputDecoration(
                        labelText: l.baseUrl,
                        hintText: 'https://api.example.com',
                      ),
                    ),
                    if (selectedProtocol.requiresApiKey) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l.apiKey,
                          hintText:
                              selectedProtocol == ApiProtocol.openaiCompatible
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
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final provider = AIProvider(
                    id: 'provider_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    protocol: selectedProtocol,
                    baseUrl: baseUrlController.text.trim().replaceAll(
                      RegExp(r'/$'),
                      '',
                    ),
                    apiKey: selectedProtocol.requiresApiKey
                        ? apiKeyController.text.trim()
                        : null,
                  );
                  ref.read(settingsProvider.notifier).addProvider(provider);
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

  void _showEditProviderDialog(
    BuildContext context,
    WidgetRef ref,
    AIProvider provider,
    AppLocalizations l,
  ) {
    final nameController = TextEditingController(text: provider.name);
    final baseUrlController = TextEditingController(text: provider.baseUrl);
    final apiKeyController = TextEditingController();
    ApiProtocol selectedProtocol = provider.protocol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(l.editProvider),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: l.providerName),
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
                      onChanged: (p) {
                        if (p != null) setState(() => selectedProtocol = p);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlController,
                      decoration: InputDecoration(labelText: l.baseUrl),
                    ),
                    if (selectedProtocol.requiresApiKey) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '${l.apiKey} (${l.leaveEmptyToKeep})',
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
                  final updated = provider.copyWith(
                    name: nameController.text.trim(),
                    protocol: selectedProtocol,
                    baseUrl: baseUrlController.text.trim().replaceAll(
                      RegExp(r'/$'),
                      '',
                    ),
                    apiKey:
                        selectedProtocol.requiresApiKey &&
                            apiKeyController.text.trim().isNotEmpty
                        ? apiKeyController.text.trim()
                        : null,
                  );
                  await ref
                      .read(settingsProvider.notifier)
                      .updateProvider(updated);
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
              ref.read(settingsProvider.notifier).removeProvider(provider.id);
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
                  ref.read(settingsProvider.notifier).addCustomModel(model);
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

  void _showActiveModelDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final providers = settingsNotifier.providers
        .where((p) => p.isEnabled)
        .toList();
    final activeConfig = settingsNotifier.activeConfig;

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
                    final models = settingsNotifier.modelsForProvider(
                      provider.id,
                    );
                    return ExpansionTile(
                      initiallyExpanded:
                          activeConfig?.providerId == provider.id,
                      title: Row(
                        children: [
                          Icon(provider.protocol.icon, size: 16),
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
                            style: const TextStyle(fontSize: 11),
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

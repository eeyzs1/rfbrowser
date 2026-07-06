// ignore_for_file: unused_element, unused_element_parameter

part of '../ai_settings_section.dart';

mixin _ProviderDialogsMixin on _AISettingsSectionStateBase {
  @override
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

  @override
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

  @override
  void _showAddCustomModelDialog(
    BuildContext context,
    WidgetRef ref,
    AIProvider provider,
    AppLocalizations l, {
    AIModel? existingModel,
  }) {
    final isEditing = existingModel != null;
    final modelIdController = TextEditingController(
      text: existingModel?.id ?? '',
    );
    // 编辑模式下 model id 不可改(它是主键),展示但禁用。
    final displayNameController = TextEditingController(
      text: existingModel?.displayName ?? '',
    );
    final contextWindowController = TextEditingController(
      text: existingModel?.contextWindow?.toString() ?? '',
    );
    final selectedCapabilities = <ModelCapability>{
      ...(existingModel?.capabilities ?? {ModelCapability.text}),
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(isEditing ? l.editCustomModel : l.addCustomModel),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: modelIdController,
                      enabled: !isEditing,
                      decoration: InputDecoration(
                        labelText: l.modelId,
                        hintText: isEditing ? null : 'my-model-v1',
                        helperText: isEditing ? (l.modelIdReadOnlyHint) : null,
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
                    TextField(
                      controller: contextWindowController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.contextWindow,
                        hintText: l.contextWindowHint,
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final modelId = modelIdController.text.trim();
                  // 编辑模式下 modelId 不可改,但仍然校验非空(防御性)
                  if (modelId.isEmpty) return;

                  // 解析 contextWindow(可选字段,留空为 null)
                  int? contextWindow;
                  final cwText = contextWindowController.text.trim();
                  if (cwText.isNotEmpty) {
                    final parsed = int.tryParse(cwText);
                    if (parsed == null || parsed <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.contextWindowInvalid)),
                      );
                      return;
                    }
                    contextWindow = parsed;
                  }

                  final model = AIModel(
                    id: modelId,
                    providerId: provider.id,
                    displayName: displayNameController.text.trim().isNotEmpty
                        ? displayNameController.text.trim()
                        : modelId,
                    capabilities: Set.from(selectedCapabilities),
                    contextWindow: contextWindow,
                    isCustom: true,
                  );
                  // addCustomModel 是 upsert 语义(先 removeWhere 同 id 再 add),
                  // 所以编辑模式直接调用即可覆盖原模型。
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

  @override
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

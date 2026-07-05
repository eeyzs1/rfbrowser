part of '../ai_chat_panel.dart';

mixin _AIChatModelSelectorMixin on _AIChatPanelStateBase {
  @override
  Widget _buildModelSelector(ThemeData theme, AIState aiState) {
    final aiConfig = ref.read(aiConfigProvider);
    final providers = aiConfig.providers.where((p) => p.isEnabled).toList();
    final activeModel = aiState.activeModel ?? aiConfig.activeModel;
    final activeProvider = aiState.activeProvider ?? aiConfig.activeProvider;

    if (providers.isEmpty) {
      return TextButton.icon(
        onPressed: () => _showAddProviderDialog(theme),
        icon: const Icon(Icons.add, size: 14),
        label: Text('Add Provider'),
      );
    }

    final selectWidget = activeModel != null && activeProvider != null
        ? _buildActiveModelChip(theme, activeProvider, activeModel)
        : _buildSelectModelButton(theme);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        selectWidget,
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            icon: const Icon(Icons.add, size: 12),
            onPressed: () => _showAddProviderDialog(theme),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Add Provider',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              side: BorderSide(color: theme.dividerColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveModelChip(
    ThemeData theme,
    AIProvider provider,
    AIModel model,
  ) {
    return InkWell(
      onTap: () => _showModelPicker(theme),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(provider.displayIcon, size: 12, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              model.displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (model.supportsVision) ...[
              const SizedBox(width: 2),
              Icon(Icons.visibility, size: 10, color: theme.hintColor),
            ],
            const SizedBox(width: 2),
            Icon(Icons.unfold_more, size: 12, color: theme.hintColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectModelButton(ThemeData theme) {
    return InkWell(
      onTap: () => _showModelPicker(theme),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select', style: theme.textTheme.bodySmall),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 12, color: theme.hintColor),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(ThemeData theme) {
    final aiConfig = ref.read(aiConfigProvider);
    final providers = aiConfig.providers.where((p) => p.isEnabled).toList();
    final activeConfig = aiConfig.activeConfig;
    final l = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.selectModel),
        contentPadding: const EdgeInsets.only(top: 16),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: providers.map((provider) {
              final models = aiConfig.modelsForProvider(provider.id);
              final isActiveProvider = activeConfig?.providerId == provider.id;
              return ExpansionTile(
                initiallyExpanded: isActiveProvider,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: 4,
                ),
                leading: Icon(
                  provider.displayIcon,
                  size: 16,
                  color: theme.hintColor,
                ),
                title: Text(
                  provider.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActiveProvider
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                trailing: models.isEmpty
                    ? Text(
                        '0 models',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      )
                    : null,
                children: models.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'No models. Refresh in Settings.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ]
                    : models.map((model) {
                        final isActive =
                            isActiveProvider &&
                            activeConfig?.modelId == model.id;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isActive
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.hintColor,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  model.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              ...model.capabilities.map(
                                (cap) => Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    cap == ModelCapability.vision
                                        ? Icons.visibility
                                        : Icons.text_fields,
                                    size: 12,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                            ],
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
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddProviderDialog(ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final baseUrlController = TextEditingController(
      text: ApiProtocol.openaiCompatible.defaultBaseUrl,
    );
    final apiKeyController = TextEditingController();
    ApiProtocol selectedProtocol = ApiProtocol.openaiCompatible;
    bool requiresApiKey = true;
    // 测试连接状态：0=空闲, 1=测试中, 2=成功, 3=失败
    int testStatus = 0;
    String testError = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          // 测试连接：向 models 端点发送 GET 请求
          Future<void> testConnection() async {
            setState(() {
              testStatus = 1;
              testError = '';
            });
            try {
              final baseUrl = baseUrlController.text.trim().replaceAll(
                RegExp(r'/$'),
                '',
              );
              if (baseUrl.isEmpty) {
                throw Exception('Base URL is empty');
              }
              final apiKey = requiresApiKey
                  ? apiKeyController.text.trim()
                  : null;
              final provider = AIProvider(
                id: 'test_provider',
                name: 'test',
                protocol: selectedProtocol,
                baseUrl: baseUrl,
                apiKey: apiKey,
                requiresApiKey: requiresApiKey,
              );

              final dio = Dio(
                BaseOptions(
                  connectTimeout: const Duration(seconds: 10),
                  receiveTimeout: const Duration(seconds: 15),
                ),
              );
              final headers = <String, String>{
                'Content-Type': 'application/json',
                ...provider.authHeaders(),
              };
              await dio.get(
                provider.modelsEndpoint,
                options: Options(headers: headers),
              );
              setState(() => testStatus = 2);
            } on DioException catch (e) {
              String msg;
              final data = e.response?.data;
              if (data is Map && data['error'] != null) {
                final err = data['error'];
                msg = err is Map
                    ? (err['message'] as String? ??
                          e.message ??
                          'Unknown error')
                    : err.toString();
              } else {
                msg = e.message ?? 'Connection failed';
              }
              setState(() {
                testStatus = 3;
                testError = msg;
              });
            } catch (e) {
              setState(() {
                testStatus = 3;
                testError = e.toString();
              });
            }
          }

          return AlertDialog(
            title: const Text('Add Provider'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Provider Name',
                        hintText: 'My OpenAI, Work Azure, etc.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ApiProtocol>(
                      key: ValueKey(selectedProtocol),
                      initialValue: selectedProtocol,
                      decoration: const InputDecoration(labelText: 'Protocol'),
                      items: ApiProtocol.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.label),
                            ),
                          )
                          .toList(),
                      onChanged: (p) {
                        if (p != null) {
                          setState(() {
                            selectedProtocol = p;
                            if (baseUrlController.text.isEmpty ||
                                ApiProtocol.values.any(
                                  (proto) =>
                                      baseUrlController.text ==
                                      proto.defaultBaseUrl,
                                )) {
                              baseUrlController.text = p.defaultBaseUrl;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.example.com',
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText:
                              selectedProtocol == ApiProtocol.openaiCompatible
                              ? 'sk-...'
                              : '',
                        ),
                      ),
                    ],
                    // 测试连接结果显示
                    if (testStatus == 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l.testConnectionSuccess,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (testStatus == 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.cancel,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l.testConnectionFailed(testError),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              // 测试连接按钮
              TextButton.icon(
                onPressed: testStatus == 1 ? null : testConnection,
                icon: testStatus == 1
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        testStatus == 2
                            ? Icons.check_circle
                            : testStatus == 3
                            ? Icons.error_outline
                            : Icons.wifi_find,
                        size: 14,
                      ),
                label: Text(
                  testStatus == 1 ? l.testing : l.testConnection,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
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
                    apiKey: requiresApiKey
                        ? apiKeyController.text.trim()
                        : null,
                    requiresApiKey: requiresApiKey,
                  );
                  ref.read(aiConfigProvider.notifier).addProvider(provider);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ignore_for_file: unused_element, unused_element_parameter

part of '../ai_settings_section.dart';

mixin _LocalServiceScanMixin on _AISettingsSectionStateBase {
  @override
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

  @override
  Future<void> _autoScanAndPrompt() async {
    final aiConfig = ref.read(aiConfigProvider);
    if (aiConfig.providers.isNotEmpty) return;

    final scanner = ref.read(localServiceScannerProvider);
    final detected = await scanner.scan();
    if (detected.isEmpty || !mounted) return;

    setState(() => _detectedServices = detected);
  }

  @override
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

  @override
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
}

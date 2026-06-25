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

part 'ai_settings/local_service_scan.dart';
part 'ai_settings/preset_tile_builder.dart';
part 'ai_settings/preset_quick_start.dart';
part 'ai_settings/provider_list.dart';
part 'ai_settings/provider_dialogs.dart';

class AISettingsSection extends ConsumerStatefulWidget {
  const AISettingsSection({super.key});

  @override
  ConsumerState<AISettingsSection> createState() => _AISettingsSectionState();
}

abstract class _AISettingsSectionStateBase
    extends ConsumerState<AISettingsSection> {
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

  // Abstract declarations for cross-mixin method calls.
  Future<void> _checkPresetStatus();
  Future<void> _autoScanAndPrompt();
  Widget _buildDetectedBanner(ThemeData theme, AppLocalizations l);
  Widget _buildAddLocalModelButton(ThemeData theme, AppLocalizations l);
  Widget _buildQuickStartCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l,
  );
  Widget _buildProviderTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations l,
    AIProvider provider,
    AIProvider? activeProvider,
    AIModel? activeModel,
  );
  void _showActiveModelDialog(BuildContext context, AppLocalizations l);
  void _showProviderFormDialog({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l,
    AIProvider? provider,
  });
  Future<void> _addPresetProvider(LocalServiceInfo preset);
  Future<void> _scanForLocalServices(
    BuildContext context,
    AppLocalizations l, {
    BuildContext? sheetCtx,
  });
  void _showAddCustomModelDialog(
    BuildContext context,
    WidgetRef ref,
    AIProvider provider,
    AppLocalizations l,
  );
  void _showDeleteProviderConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    AIProvider provider,
    AppLocalizations l,
  );

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
}

class _AISettingsSectionState extends _AISettingsSectionStateBase
    with
        _LocalServiceScanMixin,
        _PresetTileBuilderMixin,
        _PresetQuickStartMixin,
        _ProviderListMixin,
        _ProviderDialogsMixin {}
